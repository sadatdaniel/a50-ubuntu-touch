# Experiment 012 — fingerprint reader

**Date:** 2026-09-05 · **Status:** 🟠 permission wall fixed; capture blocked by optical-sensor HBM · **Device needed:** yes

## Hardware

Under-display optical sensor, **EGISTEC ET713**, read straight from the kernel:

```
/sys/devices/virtual/fingerprint/fingerprint/name    -> ET713
/sys/devices/virtual/fingerprint/fingerprint/vendor  -> EGISTEC
/sys/devices/virtual/fingerprint/fingerprint/position-> 13.77,0.00,7.29,7.29,...
```

So the kernel driver is present. `position` is the on-screen sensor rectangle
the UI uses to draw the target.

## The stack is all present

Nothing needed installing — every layer already ships:

| layer | state |
|---|---|
| kernel driver | ET713 sysfs present |
| Android HAL | `vendor.samsung.hardware.biometrics.fingerprint@3.0-service` running; registers `android.hardware.biometrics.fingerprint@2.1::IBiometricsFingerprint/default` and `vendor.samsung…@3.0::ISehBiometricsFingerprint/default` (`lshal`) |
| biometryd | `biometryd.service` active; `list-devices` shows the `android` device; the process has mapped `android.hardware.biometrics.fingerprint@2.1.so` and `android.hardware.gatekeeper@1.0.so`, i.e. it is wired to the HAL through hybris |
| Settings UI | `qml-module-lomiri-settings-fingerprint` installed |

## The blocker — biometryd `NotPermitted`, and it crashes Settings

Opening **Security & Privacy → Fingerprint** in System Settings crashes the
whole app. The journal:

```
lomiri-system-settings: terminate called after throwing an instance of 'std::runtime_error'
lomiri-system-settings:   what():  com.ubports.biometryd.Error.NotPermitted:
lomiri-app-launch-…-lomiri-system-settings-…: Main process exited, code=killed, status=6/ABRT
```

`biometryd test --device=android` from the command line fails the same way:

```
terminate called … what(): com.ubports.biometryd.Error.NotPermitted:
```

**Cause — the same AppArmor gate as GPS.** biometryd resolves every D-Bus
caller's AppArmor profile before allowing an operation
(`biometry::dbus::skeleton::DaemonCredentialsResolver`, using `libapparmor` via
`GetConnectionCredentials`). This kernel has no AppArmor, so the resolution
fails and every call is refused with `NotPermitted`. System Settings does not
catch the exception, so the page crash is a direct consequence. It is the exact
counterpart of the location-service permission wall in
[experiment 009](009-gps-permissions.md).

**Fix — the matching bypass.** biometryd reads
`BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING`; when set, the skeleton's
request verifier permits the call before it tries to resolve a profile — the
twin of `TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING`. Shipped as a
systemd drop-in on `biometryd.service`
(`overlay/etc/systemd/system/biometryd.service.d/50-a50-testing.conf`, and
installed on an existing device by `scripts/apply-device-workarounds.sh`).

Same trade-off, same reasoning: on a port with no AppArmor nothing is confined,
so no isolation is lost; the alternative is that fingerprint works for nobody
and Settings crashes. Remove it once an AppArmor kernel boots.

## After the bypass — the HAL enrolls

With the env set, `biometryd test --device=android` gets past `NotPermitted`
and proceeds:

```
Clearing template store: [ ] 0.00 %
Enrolling new template:  [ ] 0.00 %
```

and the Samsung auth service arms and waits for a finger:

```
bauth_FPBAuthService: thread id : 0, preenroll_flag : 1, nd cnt : 0, cso : 0, et : 0
```

`preenroll_flag : 1` = the HAL accepted the enroll and is waiting; `nd cnt : 0`
= no finger sensed yet (the CLI run had nobody touching the screen). So the
authentication-token path works — no gatekeeper HAT problem, which was the
next-most-likely blocker.

## The real wall — it is an optical sensor and nothing lights the finger

After the permission bypass, enrollment still captures nothing. Traced end to
end, the sensor never sees a finger:

* biometryd arms the HAL and the Samsung auth service polls once a second, but
  the finger-down count never moves:

  ```
  bauth_FPBAuthService: preenroll_flag : 1, nd cnt : 0, cso : 0, et : 0
  ```

* The kernel driver is alive and does power the sensor on each poll:

  ```
  etspi_ioctl FP_POWER_CONTROL, status = 1
  etspi_ioctl FP_SET_SPI_CLOCK, clock = 20000000 ; ENABLE_SPI_CLOCK
  etspi_work_func_debug ldo: 1, sleep: 1, tz: 1, spi_value: 0x0, type: et7xx
  ```

  `tz: 1` — the real image transfer is owned by TrustZone (tzdaemon and its
  `tz_worker` threads are running, so the TEE itself is up). `spi_value: 0x0`
  and `nd cnt : 0` together mean the sensor captured no usable image.

**Why: the ET713 is optical, and an optical under-display sensor can only image
a finger when the screen shines a bright spot through it (High Brightness Mode).
Nothing on this port turns that on.** The panel exposes the Samsung mask-layer
HBM control:

```
/sys/devices/platform/148e0000.dsim/lcd/panel/mask_brightness         (target)
/sys/devices/platform/148e0000.dsim/lcd/panel/actual_mask_brightness  (applied)
```

`mask_brightness` reads 255 but `actual_mask_brightness` reads **0** — the mask
is configured but never applied. Writing 255/300/319 to it is accepted by the
kernel (`lcd panel: mask_brightness_store: 255, 319`) yet `actual_mask_brightness`
stays 0, and `nd cnt` stays 0 with a finger held on the sensor.

That is the crux: Samsung's decon applies the mask HBM only when the
**compositor composites a dedicated "mask layer"** frame — on stock Android,
SurfaceFlinger draws the white fingerprint circle with that layer flag and
decon lights it. This port's compositor is **Lomiri/Mir**, which knows nothing
about Samsung's mask layer, so decon never enters mask mode, the finger stays
dark, and the optical sensor returns an empty image. There is no sysfs toggle
for the mask layer (searched: no `mask_layer` / `self_mask` / decon control), so
it cannot be forced from userspace alone.

## Exactly what gates HBM — read from the kernel source, not inferred

An earlier draft of this file said optical under-display sensors "generally do
not work on Halium/UBports". **That was too strong and is wrong** — the
OnePlus 6T, Xiaomi Mi A3 and Volla Phone all have optical in-display sensors
with Ubuntu Touch support. Those are Qualcomm/Goodix designs where HBM is a
plain panel control the driver or HAL toggles directly, so nothing above the
kernel has to cooperate. Samsung's Exynos design is different, and that
difference is the whole problem here.

Read from the pinned kernel tree
(`FreshROMs/android_kernel_samsung_exynos9610_mint`, commit `bec0c2af`):

`drivers/video/fbdev/exynos/dpu20/panels/ea8076_a50_lcd_ctrl.c` — the panel
only substitutes the mask brightness when decon says the mask layer is active:

```c
#if defined(CONFIG_SUPPORT_MASK_LAYER)
    if (decon && decon->current_mask_layer) {
        lcd->brightness = lcd->mask_brightness;
    }
#endif
```

and `drivers/video/fbdev/exynos/dpu20/decon_core.c` — what sets
`current_mask_layer`:

```c
static bool decon_get_mask_layer(struct decon_device *decon,
        struct decon_win_config_data *win_data)
{
    for (i = 0; i < decon->dt.max_win; i++) {
        config = &win_config[i];
        if (config && (config->state == DECON_WIN_STATE_FINGERPRINT)) {
            config->state = DECON_WIN_STATE_BUFFER;
            mask = true;
        }
    }
    ...
}
```

**So HBM engages only when the compositor submits a window whose state is
`DECON_WIN_STATE_FINGERPRINT` through decon's win-config ioctl.** On stock
Android the Samsung HWC/SurfaceFlinger flags the fingerprint overlay that way.
Lomiri/Mir never sets it, so `decon->current_mask_layer` stays false,
`actual_mask_brightness` stays 0 no matter what is written to
`mask_brightness`, the finger is never lit, and the sensor's `nd cnt` never
leaves 0.

`CONFIG_SUPPORT_MASK_LAYER` **is** compiled into this kernel — both sysfs nodes
exist, and they only exist inside that `#if`. So the machinery is present and
simply never triggered.

## A concrete way forward

This is fixable, and it does not need the whole compositor to learn about
Samsung mask layers. Two workable options, cheapest first:

1. **Kernel patch exposing the mask layer to userspace.** Add a sysfs write
   (e.g. `force_mask_layer`) that sets `decon->current_mask_layer` and runs the
   same brightness update path `decon_set_mask_layer()` already performs, then
   have a small helper raise it while a fingerprint operation is in flight and
   drop it afterwards. This port already maintains a kernel patch series, so
   the mechanism is routine; the risk is that the panel expects the change to
   land in step with a frame/TE signal (note `wait_mask_layer_trigger` and the
   TE wait in `decon_set_mask_layer`), so it must be done on the vsync path
   rather than asynchronously.
2. **Set the window state from the compositor side** — have Lomiri/Mir mark its
   fingerprint overlay window `DECON_WIN_STATE_FINGERPRINT` when it reaches the
   Android HWC. Closer to how stock behaves, but it means touching the
   Mir/hwcomposer path, which is a much larger change.

Either way the missing piece is now identified precisely, with the exact
kernel symbols and the file/line that gate it — this is no longer "compositor
work, unknown scope".

## In flight — kernel patch exposing the mask layer (2026-09-05)

Option 1 above is being tried. `a50-halium` gains
`kernel/patches-experimental/decon-force-mask-layer.patch`, generated from a
real diff against the pinned tree (not hand-written), and added to `EXTRA` in
`build/build-a50-release-kernel.sh`.

It adds 13 lines to `decon_core.c`: a module parameter, and one OR into the
existing decision.

```c
bool decon_force_mask_layer = false;
module_param_named(force_mask_layer, decon_force_mask_layer, bool, 0644);
...
	if (decon_force_mask_layer)
		mask = true;
```

Everything downstream is untouched — the transition still runs through
`decon_set_mask_layer()` on the regs path, keeping its TE/vsync wait, its
`call_panel_ops(mask_brightness)` and the `wait_mask_layer_trigger` handshake.
Only the trigger is new, so the vendor's own tested sequence does the work.

**It defaults to false**, so the patched kernel with the parameter untouched
should behave exactly like the current one. That gives a two-stage test instead
of one:

1. Boot the patched kernel with the flag unset. Expect *no* change at all:
   boots, lightdm up, container `sys.boot_completed=1`, audio/Bluetooth/GPS
   unaffected, display normal. This proves the patch is inert.
2. Only then `echo 1 > /sys/module/decon/parameters/force_mask_layer` and check
   `actual_mask_brightness` becomes non-zero (it has never been anything but 0).
   With the screen lit, arm enrollment and watch whether `nd cnt` finally rises.

The known-good image is staged at `/userdata/boot-known-good.img`
(`53fe13b5…`, verified equal to the running boot partition) before any flash.

If stage 2 works, the remaining piece is raising the flag automatically while a
fingerprint operation is in flight — biometryd's D-Bus operations are the
natural trigger — and dropping it afterwards, since the mask brightness is very
bright and must not be left on.
