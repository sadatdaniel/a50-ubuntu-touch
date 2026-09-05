# Experiment 014 — camera: the kernel panic does not reproduce

**Date:** 2026-09-05 · **Status:** 🟡 hazard retired, camera still not working
· **Device needed:** yes

## The claim being tested

`docs/status.md` and both handoffs carried this as a live hazard:

> **The camera driver panics the kernel.** `fimc_is_devicemgr_open` NULL-derefs
> when anything enumerates V4L2, and `gst-plugin-scan` does. It presents as a
> bootloop from the user session and is easy to misattribute.

recorded in [experiment 007](007-abox-firmware-too-early.md) §10 as:

```
gst-plugin-scan: Unable to handle kernel paging request at ffffff800c1613b0
pc : fimc_is_devicemgr_open+0x1e8/0x3a0
Kernel panic - not syncing: Fatal exception
```

That evidence is from a much older kernel. It was never re-tested, and it has
been shaping decisions since — so it was tested rather than trusted.

## Reading the driver first

`fimc_is_devicemgr_open()` (`drivers/media/platform/exynos/fimc-is2/
fimc-is-devicemgr.c:143`, the `CONFIG_USE_SENSOR_GROUP=y` variant, which is the
one built) guards `core`, `group`, `sensor->vctx` and the stream index with
`FIMC_BUG()`.

`FIMC_BUG` is **not** `BUG_ON` in this build. `USE_FIMC_BUG` is defined
(`include/fimc-is-common-config.h:91`), so it takes the graceful branch:

```c
#ifdef USE_FIMC_BUG
#define FIMC_BUG(condition)  { if (unlikely(condition)) { info(...); return -EINVAL; } }
#else
#define FIMC_BUG(condition)  BUG_ON(condition);
#endif
```

So a tripped guard returns `-EINVAL`; it cannot be the panic. The panic must
come from an **unguarded** dereference — and `sensor->groupmgr` is passed
straight into `fimc_is_group_open()` with no check, unlike everything around it.

## Testing it, carefully

Waydroid stopped, filesystems synced, `/userdata/boot-known-good-waydroid.img`
(`90c281f8…`) confirmed staged first.

**1. One sensor node.** `video101` = `exynos-fimc-is-ss0`, the node that takes
the `FIMC_IS_DEVICE_SENSOR` path:

```
OPENED ok, fd= 3
closed ok
```

No panic. The kernel logged the open and close cleanly:

```
[@][0][SEN:D] fimc_is_sensor_open():0
[@][0][ERR]fimc_is_sensor_g_module:199:sub module is NULL
[@][0][SEN:D] fimc_is_sensor_close():0
[@][0][SS0:V] fimc_is_ssx_video_close(0):0
```

**2. Every node.** All 50 `/dev/video*`, each `open()` + `VIDIOC_QUERYCAP` —
what `gst-plugin-scan` does — writing the node name to `/userdata/v4l2-probe.log`
with `fsync` before each attempt, so a panic would name the culprit:

```
completed 50 nodes
... ALL DONE
```

No panic.

**3. The original binary.** `gst-plugin-scan` **is not installed on this device
at all** (`find /` finds nothing). Whatever ran in experiment 007 came from a
different rootfs.

### Conclusion

**The documented panic does not reproduce on the current kernel.** V4L2
enumeration is safe. The hazard as written is stale.

Why it probably went away — a hypothesis, not a finding: the original crash
happened while `misc_list` corruption from the unguarded `conn_gadget`
double-`misc_register()` was live (experiment 006). Every misc-device open on
the system was affected then, and the camera open path is one. Both the
`misc-open-scope-and-tracing` patch and the USB-gadget stopgap landed since.

## Why the camera still does not work

Not panicking is not working. The drivers do probe at boot:

```
fimc_is_probe:start / fimc_is_probe:end
sensor_module_2x5_probe done          (S5K2X5)
cis_2x5_probe sensor id 1
  -> "sensor peri is not yet probed"
sensor_dw9808_actuator_probe done     (autofocus)
fimc_is_sensor_eeprom probed!         (x3)
```

but opening a sensor node gives `fimc_is_sensor_g_module: sub module is NULL`
and `bcm_err: BCM bin has not been loaded yet!!` — the sensor peripheral is
never bound to the module, so there is no image path. Driving that binding is
the Samsung camera HAL's job (`sec-camera-provider-4-0`, which does run, on a
stable pid). Making it actually deliver frames is the real project and is not
started.

## Also corrected here

* A load average of ~16 with no busy process is **normal on this device** and
  not a fault: `tz_worker_thread` TrustZone kernel threads sit permanently in
  D-state, which counts toward load. Nothing was above ~5 % CPU.
* Waydroid's own camera provider crash-loop is a separate thing and is fixed —
  see [experiment 013](013-waydroid.md).

## What not to redo

* Do not repeat "the camera panics on V4L2 enumeration" without re-testing; as
  of this kernel it does not.
* `gst-plugin-scan` is not present, so it cannot be the trigger for anything
  observed now.
