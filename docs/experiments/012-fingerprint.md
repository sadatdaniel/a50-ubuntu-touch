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

## Status and what it would take

* **Fixed and shipped:** the permission wall — biometryd no longer returns
  `NotPermitted`, System Settings no longer crashes opening the Fingerprint
  page, the HAL enrolls, and the kernel/TEE path is live. Survives reboot.
* **Blocked, and it is a real project:** actual capture needs the HBM mask
  layer lit during fingerprint operations. That requires driving Samsung's
  decon mask layer from the Lomiri/Mir side in step with the HAL's
  finger-down/HBM requests — compositor-level work, not a config file. This is
  the known reason optical under-display sensors generally do not work on
  Halium/UBports ports, whereas capacitive/rear sensors do. Until then the
  sensor cannot read a fingerprint no matter how the enrollment is driven.

The earlier "add fingerprint shows nothing / reader not working" is exactly
this: the UI arms enrollment, the sensor is powered, but with no illuminated
spot it detects no finger. It is not a permission, template-store, or
gatekeeper problem — all of those are working.
