# Experiment 014 — camera: the kernel panic does not reproduce

**Date:** 2026-09-05 · **Status:** 🟡 hazard retired; HAL proven working; app crashes in the UT media layer
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

## The app: one fix, then a crash localised to the UT media layer

### Fixed — the app could not load its own plugin

Opening Camera showed a spinner forever. The reason was not the camera:

```
plugin cannot be loaded for module "CameraApp": Cannot load library
.../CameraApp/libcamera-qml.so: (libexiv2.so.27: cannot open shared object
file: No such file or directory)
```

26.04 ships `libexiv2.so.28`; `camera.ubports` 4.1.1 was built against `.so.27`.
Fixed with **`libexiv2-27-compat`** — a real UBports 26.04 package that provides
the old SONAME alongside the new one, rather than copying a `.so` out of the
24.04 rootfs image. Same class as the OpenStore SONAME problem in
`docs/device-provisioning.md`. Installed by
`scripts/apply-device-workarounds.sh`; afterwards `ldd` reports **0** unresolved
libraries for both `libcamera-qml.so` and `libaalcamera.so`.

### The whole camera stack below the app is proven working

Each layer was checked separately rather than inferred:

| layer | evidence |
|---|---|
| kernel sensor drivers | `cis_2x5_probe done`; `/sys/kernel/debug/devices_deferred` empty |
| Samsung HAL | `ExynosCameraInterface: Number of cameras(3)` |
| Android CameraService | `Camera provider legacy/0 ready with 3 camera devices` |
| libhybris, **from Ubuntu Touch** | `android_camera_get_number_of_devices() = 3` |
| **HAL query, from Ubuntu Touch** | camera 0 connects; **16 preview sizes**, 33 picture sizes (to 5760×4320); camera 1: 12 preview, 16 picture |

That last one matters most: `android_camera_connect_by_id()` succeeds and
`android_camera_enumerate_supported_preview_sizes()` returns a full list. **The
viewfinder resolutions the app claims not to have are available one layer
below it.**

### Where it actually breaks

The app now reaches the camera — it logs the real sensor picture sizes and
renders a frame ("Last frame took 32 ms") — then dies:

```
lomiri-app-launch--...camera.ubports_camera_4.1.1--.service:
    Main process exited, code=killed, status=11/SEGV
```

Preceded, every run, by:

```
qml: updateViewfinderResolution: viewfinder resolutions is not known yet.   (repeatedly)
QObject::connect: No such slot AalImageCaptureControl::onPreviewReady()
(AalImageEncoderControl::setSize) Size QSize(-1, -1) is not supported by the camera
virtual QSGVideoNode* ShaderVideoNodePlugin::createNode(const QVideoSurfaceFormat&)
```

A core dump was captured (`systemd-coredump` + `gdb` installed for this). The
faulting PC is in **unmapped memory** — not a plain null dereference but a jump
through a stale or corrupted pointer, consistent with a video node built from
the invalid `QSize(-1, -1)`.

And the missing slot is real, not a stale message:

```
$ nm -DC .../mediaservice/libaalcamera.so | grep -i previewReady
  T StorageManager::previewReady(int, QImage)
  T AalVideoRendererControl::previewReady()
```

`AalImageCaptureControl::onPreviewReady()` **does not exist** in the installed
plugin. So something connects to a slot this build does not have.

Installed versions: `camera.ubports` 4.1.1, `cameraplugin-aal` 0.5.1,
`qtubuntu-media` 0.8.4, `qtvideonode-plugin` 0.2.3.

### Conclusion

The camera hardware, kernel drivers, Samsung HAL and libhybris compat layer all
work on this device. The remaining fault is **above** them, in Ubuntu Touch's
own camera stack (`qtubuntu-media` / `cameraplugin-aal` / `camera.ubports`):
the AAL viewfinder control never picks up the preview resolutions that the HAL
plainly offers, and the app then segfaults building a video node from an
invalid size.

That looks like an upstream UBports 26.04 mismatch rather than anything
device-specific — the missing `onPreviewReady` slot points the same way. Worth
checking against another 26.04 device before spending more effort here.

**Not attempted:** patching or rebuilding `qtubuntu-media`.

## Why Waydroid's camera works but Ubuntu Touch's does not

Waydroid's camera works. That is decisive: the sensor, kernel driver, Samsung
HAL and the whole hardware path are fine. Waydroid uses Android's own Camera2
stack inside the container and never touches Qt.

The Ubuntu Touch app fails in Qt, and the mismatch is exact:

```
$ nm -DC .../mediaservice/libaalcamera.so | grep -c ViewfinderSettingsControl2
0
$ strings .../libaalcamera.so | grep cameraviewfindersettingscontrol
org.qt-project.qt.cameraviewfindersettingscontrol/5.0      <- legacy interface

$ nm -DC .../mediaservice/libgstcamerabin.so | grep -c ViewfinderSettingsControl2
6
```

`qtubuntu-camera` 0.5.1 implements only the **legacy**
`QCameraViewfinderSettingsControl`. Qt 5.15 routes
`camera.supportedViewfinderResolutions()` — which the app calls in
`updateViewfinderResolution()` — through **`QCameraViewfinderSettingsControl2`**,
which the plugin does not implement. So Qt returns an empty list:

```
supportedViewfinderResolutions.length === 0
  -> "updateViewfinderResolution: viewfinder resolutions is not known yet."
  -> AalImageEncoderControl::setSize: QSize(-1, -1) is not supported
  -> SIGSEGV
```

even though the HAL plainly offers 16 preview sizes for camera 0, verified
directly from Ubuntu Touch via libhybris.

The dangling `QObject::connect: No such slot
AalImageCaptureControl::onPreviewReady()` is the same story: that slot does not
exist in the shipped build.

**So this is an upstream qtubuntu-camera bug, not a device problem.** Fixing it
means implementing `ViewfinderSettingsControl2` in qtubuntu-camera and
rebuilding it — nothing on the device can work around a missing Qt interface.

Not attempted: forcing Qt to the `gstcamerabin` backend instead. It does
implement Control2, but it drives V4L2 directly, and on this device the sensor
is only usable through the Android HAL, so it is unlikely to produce frames.
