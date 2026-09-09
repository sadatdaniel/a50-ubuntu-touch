# Experiment 017 — suspend panics in the camera driver

**Date:** 2026-09-09 · **Status:** 🔴 panic real and UNFIXED; trigger is a V4L2 open, not suspend — see the CORRECTION below
· **Device needed:** yes
· **Device needed:** yes

## Symptom

The device never sleeps. `dmesg` has zero `PM: suspend entry` lines across an
entire boot, and idle drain with the screen off measures ~38 mA.

Suspend is not merely unconfigured — **entering it kills the phone.**
`echo mem > /sys/power/state` takes the device down about five seconds later,
the journal stops mid-line, and it either resets or hangs until the power
button is held.

## What was ruled out first

The userspace side is all correct, which is why this looked like a
configuration problem for longer than it should have:

| checked | result |
|---|---|
| `android.system.suspend@1.0-service` | running (pid 72) and `Registered … ISystemSuspend/default` |
| repowerd | bound to it — holds a HIDL wakelock, `Inactive` |
| blocking wakelocks | none; every entry in `dumpsys suspend_control` is `Inactive` |
| systemd inhibitors | 4 × `sleep`, all `delay` mode; Lomiri's `block` covers only power-key handling |
| `/sys/power/state` | `freeze mem`, `-rw-rw---- system system` |

An early guess that `CONFIG_PM_AUTOSLEEP` was missing was **wrong** — it is the
wrong layer. Halium 11 suspends through Android's `ISystemSuspend`, not
autosleep, and that service is present and working.

Two sysfs paths the Android 11 service wants are genuinely absent on a 4.14
kernel, but neither is fatal — it registers anyway:

```
E SystemSuspend: Error opening /sys/class/wakeup: No such file or directory
E SystemSuspend: Error opening /sys/power/suspend_stats: No such file or directory
```

`/sys/class/wakeup` arrived in 4.16. `/sys/power/suspend_stats` needs
`CONFIG_PM_DEBUG`, which was off; on 4.14 it lives in **debugfs**, not
`/sys/power`, so the service would not have found it in either case.

## Narrowing it

`CONFIG_PM_DEBUG` + `PM_SLEEP_DEBUG` + `PM_ADVANCED_DEBUG` were built in, which
provides `/sys/power/pm_test` — suspend that stops at a chosen phase and
resumes:

| phase | result |
|---|---|
| `freezer` | **passes**: `PM: suspend entry` → 5 s wait → `PM: suspend exit`, device alive |
| `devices` | **crashes**, every time |

So a device driver's suspend/resume path, not the PM core and not userspace.

`pm_async=0` did not help, and unbinding ABOX audio and the Wi-Fi driver did
not either. Two of those unbind attempts hung the SSH session, and one
apparent "survived" result was a **measurement error** — the reconnect loop
succeeded instantly because the device was still up *before* the test fired.
Uptime continuity, not reachability, is the only reliable signal here.

## The evidence that settled it

Neither persistent-log route works on this device. `ramoops` is configured and
its platform device binds, but the region does not survive Samsung's reset
path, so `/sys/fs/pstore` is always empty. `/proc/sec_log` holds only the
current boot, and boot-time SELinux spam wraps its 2 MB ring within ~25 s.

`/proc/reset_reason_extra_info` does survive, and names the site outright:

```
"PC":"fimc_is_devicemgr_open+0x1e8/0x3a0"
"LR":"fimc_is_devicemgr_open+0x178/0x3a0"
"FAULT":"0xffffff800c01b3b0"
"RR":"KP"   "PANIC":"Fatal exception"
```

Read it **after a self-reboot**. A manual power-button reset overwrites the
record with its own (`"RR":"RP"`, empty `PC`/`LR`).

Disassembling that offset in the built `vmlinux` (symbol at
`ffffff80080a52e0`, so PC = `+0x1e8` = `ffffff80080a54c8`):

```
+0x1e4:  ldr x8, [x19, #272]     ; x8 = sensor->vctx
+0x1e8:  str x22, [x8, #9136]    ; sensor->vctx->next_device = ischain   <-- faults
```

which is the store immediately after `fimc_is_group_open()` returns. Offset
272 is confirmed to be `vctx` by the earlier guard at `+0x40`, which loads the
same offset and branches on zero — that is `FIMC_BUG(!sensor->vctx)`.

## Root cause

`sensor->vctx` passes the NULL guard and still faults, and the fault address is
a plausible kernel address rather than `0`. It is **dangling, not null**.

`device->vctx` is assigned in exactly one place — `fimc_is_sensor_open()` — and
is never cleared anywhere in the driver. `fimc_is_sensor_close()` tears down the
video context and leaves the pointer aimed at it. The vendor's own guards are
NULL checks, so a stale pointer walks straight past them.

`USE_FIMC_BUG` **is** defined for this tree, so `FIMC_BUG()` returns `-EINVAL`
rather than `BUG_ON()`ing — the guards are meant to fail softly and would have,
had the pointer been NULL.

## The fix

`kernel/patches-experimental/fimc-is-clear-vctx-on-close.patch` in a50-halium:
set `device->vctx = NULL` on every exit path of `fimc_is_sensor_close()`, which
restores the existing guards.

This keeps the camera driver loaded. Disabling the driver would also stop the
panic, but it trades suspend against the camera — when the Qt/AAL media-layer
problem in [experiment 014](014-camera.md) is fixed, the driver comes back and
the panic with it.


## CORRECTION, later on 2026-09-09 — the trigger is not suspend

Everything below about the *panic* is right; the attribution to suspend is
wrong, and so is the claim in an earlier revision of this file that the patch
was verified.

A pm_test=devices run after flashing the patched kernel did not panic, and that
was read as the fix working. It was not. That run aborted at
`PM_SUSPEND_PREPARE`, on an unrelated ABOX veto:

```
Abort: PM_SUSPEND_PREPARE failed: abox_pm_notifier (11)
```

`PM_SUSPEND_PREPARE` runs **before any device is suspended**, so the camera
never suspended and the patch was never exercised. "No panic" meant "we never
got that far".

A later crash record carries the full stack, and it is not a suspend path:

```
STACK: fimc_is_devicemgr_open <- fimc_is_sensor_open <- fimc_is_ssx_video_open
       <- v4l2_open <- chrdev_open <- vfs_open <- path_openat <- SyS_openat
KTIME: 23    RR: KP
```

That is **userspace opening a V4L2 node 23 seconds into boot** — the Android
camera HAL inside the container (`vendor.samsung.hardware.camera.provider@4.0`,
`vendor.samsung_slsi.hardware.ofi@1.0`, `camera_service`). It recurred twice
with the patched kernel installed, confirmed by reading the boot partition back
(`344ea513…`).

So: the panic is real and reproducible in the field, it is triggered by opening
the camera and not by suspend, and it remains **unfixed**. Suspend merely
happens to reach the same code because resume re-opens the pipeline — which is
still unproven, since full suspend has never completed here.

What experiment 014 got right, then, is more than this file first allowed: its
V4L2 enumeration test genuinely did not crash. The panic is state-dependent, and
what state makes it fire is still unknown. That is the open question.
## This corrects experiment 014

014 retired the "camera panics the kernel" hazard as "does not reproduce". The
panic is real. 014 tested V4L2 enumeration — opening all 50 nodes and issuing
`QUERYCAP` — which is not the path that triggers it. The trigger is a stale
`vctx` from a previous open/close cycle, which is what suspend/resume produces.
The hazard should be treated as live until this patch is boot-tested.

## Not upstream

`fimc-is2` is Samsung vendor code and is not in mainline (mainline carries
`exynos4-is`), so there is no upstream maintainer for this. The patch targets
the [FreshROMs Mint kernel](https://github.com/FreshROMs/android_kernel_samsung_exynos9610_mint)
this port builds from. No public report of this panic was found. It should
affect any Exynos 9610 device (A50/A50s/A30s) running a Linux userspace that
attempts suspend.

## What is not proven

The patch has not been boot-tested. Whether clearing `vctx` is sufficient, or
whether the camera also needs a matching fix on the open path, is open. Full
`mem` suspend has never completed on this device, so nothing downstream of the
`devices` phase — resume of the modem, Wi-Fi, or the Android container — has
been exercised at all.
