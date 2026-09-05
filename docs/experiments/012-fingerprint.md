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

## Result — HBM solved, capture still blocked in the trustlet

The kernel patch works. Boot-tested in two stages because the flag defaults off:

**Stage 1 (flag off)** — the patched kernel is indistinguishable from the old
one: boots, `/sys/module/decon/parameters/force_mask_layer` exists reading `N`,
`actual_mask_brightness` still 0, and lightdm, the Android container, GPS
(`@GNSSND` bound) and Bluetooth all unaffected.

**Stage 2 (flag on)** — HBM engages for the first time on this port:

```
actual_mask_brightness: 0 -> 255
decon: mask_te_0 / mask_te_1
lcd panel: dsim_panel_mask_brightness: current(0) to mask(255)
lcd panel: dsim_panel_set_brightness: brightness: 0 -> 255 mask_layer: 1
decon: mask_brightness / mask_te_2 / mask_te_3
lcd panel: panel_set_brightness: skip! MASK LAYER
```

Writing 0 puts it back. The vendor's own TE-synchronised sequence runs exactly
as on stock — only the trigger is ours.

**The earlier claim in this file that HBM needed compositor work is therefore
wrong, and is corrected: a 13-line kernel patch was enough.**

### But the sensor still reports no finger

With HBM on and enrollment armed, pressing the sensor produces nothing:
`bauth_FPBAuthService: ... nd cnt : 0` for every sample, across many presses.

Tracing the HAL's init explains why. `preEnroll()` succeeds in the TEE:

```
TLC_BAUTH: Call FP cmd 0xc (22)
TLC_BAUTH: set_enroll_session : gSession_Flag = 1
check_opcode status = 5, func_ret_val = 0, function_status = 0
```

and the kernel is asked to power the sensor:

```
etspi_ioctl FP_SET_SPI_CLOCK, clock = 20000000
etspi_ioctl ENABLE_SPI_CLOCK
etspi_ioctl FP_POWER_CONTROL, status = 1
        (150 ms later)
etspi_ioctl FP_DISABLE_SPI_CLOCK
etspi_ioctl DISABLE_SPI_CLOCK
```

Then nothing. The HAL polls for 60 s and gives up with `adlg 76 failed 21`.

**The decisive detail: the DRDY interrupt is never armed.** `/proc/interrupts`
has no `etspi_irq` entry at all. Reading `drivers/fingerprint/et7xx-spi.c`, the
IRQ is registered only inside `etspi_Interrupt_Init()`, which is reached only
from the `INT_TRIGGER_INIT` (0xa4) ioctl — and the HAL never issues it. Without
that interrupt the sensor has no way to signal a finger, so `nd cnt` can never
leave 0 regardless of illumination.

So the HAL opens a ~150 ms SPI window for the trustlet to bring the sensor up,
that evidently fails, and it therefore never proceeds to arm interrupt-driven
detection. Consistent with `etspi_work_func_debug ... tz: 1, spi_value: 0x0`.

Possibly related, not proven: there is **no fingerprint calibration data
anywhere** — nothing matching fp/finger/bauth under `/mnt/vendor/efs`, and
`/data/vendor/fingerprint` is empty. Samsung keeps per-unit optical sensor
calibration in EFS, and a trustlet that cannot find it would be expected to
refuse to initialise the sensor.

### Honest status

| layer | state |
|---|---|
| kernel driver (`etspi`, ET713) | works — responds to ioctls, powers the sensor |
| TrustZone / trustlet | works — `tzdaemon` up, `TLC_BAUTH` commands return success |
| biometryd permission wall | fixed (`BIOMETRYD_..._UNDER_TESTING`) |
| Settings fingerprint page | fixed, no longer crashes |
| **HBM / mask layer** | **fixed by `decon-force-mask-layer.patch`** |
| sensor initialisation in the TEE | **fails** — SPI window closes after 150 ms |
| DRDY interrupt | never armed, so no finger detection is possible |

What remains is inside Samsung's closed HAL and trustlet. The next thing worth
checking, and the cheapest, is whether EFS fingerprint calibration exists on a
stock A50 and is simply missing here — if so, restoring it may let the trustlet
bring the sensor up, after which the interrupt would be armed and HBM (already
solved) would matter.

Not worth retrying: illumination. That is done and proven.

## Ruled out: illumination, including the white flash Android draws

A fair objection to the first HBM test: on Android, touching the sensor draws a
**white flashing circle** as well as raising HBM. The earlier test forced the
panel to mask brightness but never checked what was being *displayed* over the
sensor — at maximum backlight, black pixels are still black to an optical
sensor. So the test was repeated properly.

**And a white overlay is entirely possible under Lomiri.** `qmlscene` with
`QT_QPA_PLATFORM=ubuntumirclient` displays a full-screen QML surface fine
(`wayland` is not among this build's Qt platform plugins; `ubuntumirclient`
is). The sensor rectangle is known from the kernel —
`/sys/devices/virtual/fingerprint/fingerprint/position` = `13.77, 0.00, 7.29,
7.29` mm — so the circle can be placed correctly. A custom flash animation is
straightforward; that was never the hard part.

Two traps found while setting the test up, both of which had invalidated the
first attempt:

* **The screen had gone to sleep.** `backlight=0`, so the "white screen" was
  dark and `actual_mask_brightness` stayed 0. The idle timeouts set earlier
  that day did it. Disabled for the test, restored after.
* **A static window never triggers HBM.** decon only evaluates the mask layer
  when the compositor submits a frame (`decon_get_mask_layer()` runs from
  `decon_set_win_config`). A completely static white window submits none, so
  the flag has no effect. The QML needs a continuous animation. This also
  means the mask does not *clear* until another frame arrives.

With all of that right — white pixels over the sensor, `actual_mask_brightness
= 255` confirmed with the full TE sequence in the kernel log, enrollment armed
(`preenroll_flag : 1`), and the user pressing repeatedly:

```
     62 nd cnt : 0
bauth_FPBAuthService: FPBAuthService::enrollTimerHandler call cancel functions
```

**Every sample still zero.** Illumination is not the missing piece.

This strengthens the existing conclusion rather than changing it: with no DRDY
interrupt registered (`/proc/interrupts` has no `etspi_irq`, because the HAL
never issues `INT_TRIGGER_INIT`), the sensor has no mechanism to report a
finger at all — so no amount of light can produce a detection. The blocker is
sensor bring-up inside Samsung's trustlet, not the screen.

**Do not re-test illumination.** It is settled.
