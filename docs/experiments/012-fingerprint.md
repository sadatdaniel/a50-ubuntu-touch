# Experiment 012 — fingerprint reader

**Date:** 2026-09-05 · **Status:** 🟡 unblocked — HAL enrolls, needs on-screen
enrollment confirmed · **Device needed:** yes

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

## What is left

Actual enrollment needs real touches on the under-display sensor, which the
Settings UI drives with visual feedback (the `position` rectangle). The CLI
`test` clears the template store and enrolls blind, which is fine for proving
the HAL but poor for a real finger. Next:

1. Open Security & Privacy → Fingerprint (it no longer crashes) and enroll a
   finger with the on-screen target.
2. Confirm the HAL logs `nd cnt` rising and the enroll progressing past 0 %.
3. Confirm unlock from the greeter uses it.

One observed flake: an early CLI run aborted at 0 % ("Failed to enroll
template") once, then a later run armed correctly. If enrollment aborts
instantly, retry — it is not the permission wall (that is fixed) and not a
missing token (preenroll succeeds).

## Not done

* Whether the greeter actually offers fingerprint unlock end to end.
* No `strace`/HAT-token forensics were needed — preEnroll succeeding rules that
  class of bug out.
