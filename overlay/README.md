# `overlay/` — the port's userspace

`overlay/system/` mirrors the rootfs root: `overlay/system/etc/foo` is
installed at `/etc/foo`. The adaptation tools copy `overlay/*` over the staging
tree and then pack `partitions/` and `system/` into the device tarball, which
`system-image-from-ota.sh` unpacks into the rootfs image — so the `system/`
level is load-bearing and not decoration. The reference community port
([oneplus-nord-n100](https://gitlab.com/uports/h10/oneplus-nord-n100/oneplus-nord-n100))
is laid out the same way.

**This deliberately does not use `deviceinfo_use_overlaystore`.** That option
moves the whole tarball to `/opt/halium-overlay`, which lxc-android-config's
`mount-halium-overlay` then bind-mounts file by file onto `/` — skipping, with
a warning nobody reads, anything the rootfs does not already have. Most of what
is here is *new* files, so under overlaystore none of it would be installed.
`deviceinfo` carries the quoted evidence.

Two things here are not plain rootfs files:

| | |
| --- | --- |
| `system/var/lib/lxc/android/a50-mount-hooks.sh` | bind mounts applied **inside the Android container's mount namespace**, by LXC's mount hook. The host cannot do them: `/system` and `/vendor` are mounted separately in there, so a host-side bind is invisible to the container |
| `system/usr/libexec/lxc-android-config/device-hacks` | Ubuntu Touch's own per-boot hook, run after the container is up. It calls `a50-device-setup.sh` |

Ordering, which is not a style preference: anything the Android container will
read has to exist **before** `lxc-android-config.service` starts, which is what
`a50-container-prepare.service` is for. Anything that needs the container
*running* goes in `device-hacks`. On this device every `runonce` target fired
before the container existed, silently no-opped, and was then marked
permanently done — which is how the port ran for days with no display cutout
and nothing looking broken. If something is simply *absent* rather than
failing, check `/var/lib/runonce/done/` timestamps before believing anything
else.

## Every file here, and what it fixes

| File | Fix |
|---|---|
| `usr/lib/udev/rules.d/99-a50-binder.rules` | `/dev/hwbinder` and `/dev/vndbinder` came up `0600`, so the greeter (uid 108) could not reach the gralloc mapper HAL and lightdm restart-looped. Stock Android sets all three binder nodes `0666`. [006](../docs/experiments/006-what-we-missed.md) |
| `usr/lib/udev/rules.d/99-a50-gnss.rules` | `/dev/gnss_ipc` comes up `0600 root:root`. The vendor's own `init.gps.rc` asks for `0660 system system`, and `gpsd` runs as user `gps`, group `system` — but that `post-fs-data` block never runs in a Halium container. [009](../docs/experiments/009-gps-permissions.md) |
| `etc/ubuntu-touch-session.d/android.conf` | No device config existed, so the shell fell back to `generic.conf`'s `GRID_UNIT_PX=8` and rendered far too small. `ro.sf.lcd_density=420` → `GRID_UNIT_PX=21`. |
| `etc/resolv.conf` → `/run/NetworkManager/resolv.conf` | An early rootfs shipped a static `resolv.conf` naming `192.168.65.7` — Docker Desktop's internal DNS, captured while the image was prepared in a container. Nothing resolved, while Wi-Fi and routing were fine. |
| `etc/deviceinfo/devices/a50.yaml` | Without it ofono falls back to the legacy RIL plugin and finds no modem. Sets `OfonoPlugin: binder`. |
| `etc/ofono/binder.conf` | Slot paths, `radioInterface = 1.4`, and `signalStrengthRange = -120,-75` — the plugin's `-100/-60` defaults suit RSSI, not the LTE **RSRP** this modem reports, so the indicator pinned to 1% while idle. |
| `usr/local/bin/a50-audio-hidl-compat.sh` + `a50-audio-hidl-compat.service` | PulseAudio otherwise loads a 12 KB **stub** audio HAL and silently discards every write. [007](../docs/experiments/007-abox-firmware-too-early.md) |
| `usr/local/bin/a50-audio-speaker-route.sh` + `a50-audio-route.service` | Pins the default sink off the unusable low-latency output. |
| `usr/local/bin/a50-gen-mixer-paths.py` | Generates the patched `mixer_paths.xml`: the vendor routes the speaker from RDMA7, a channel this ABOX DSP firmware NACKs. Run by `a50-container-prepare.sh`. |
| `usr/local/bin/a50-gnss-unblock.sh` + `a50-gnss-unblock.service` | **`gpsd` waits forever on `service.bootanim.exit`**, which a Halium container never sets because it runs no boot animation. This single property is why GPS produced nothing. [009](../docs/experiments/009-gps-permissions.md) |
| `etc/systemd/system/lomiri-location-service.service.d/50-a50-trust-store.conf` | AppArmor profile resolution cannot work with no AppArmor, so every location session was refused. |
| `etc/systemd/system/biometryd.service.d/50-a50-testing.conf` | Same wall: every biometryd op returned `NotPermitted`, which also crashed System Settings the instant the Fingerprint page opened. [012](../docs/experiments/012-fingerprint.md) |
| `usr/lib/systemd/user/waydroid-session.service` | Starting the Waydroid session as root, or through `su phablet -c`, leaves the bus address as root's. A **user** unit inherits the right environment. [013](../docs/experiments/013-waydroid.md) |
| `usr/local/bin/a50-waydroid-launch.sh` | Supplies `DBUS_SESSION_BUS_ADDRESS` and friends, and **stays alive** — `waydroid app launch` exits in about a second and Lomiri then tears the app down. |
| `usr/local/bin/a50-waydroid-fix-desktop.sh` | Waydroid rewrites its `.desktop` entries on **every session start**, so this sweeps until three clean passes. |
| `etc/systemd/system/waydroid-container.service.d/50-a50-nocamera.conf` + `a50-waydroid-nocamera.sh` | Waydroid's camera provider crash-looped every ~6 s. |
| `usr/local/bin/a50-container-prepare.sh` + `a50-container-prepare.service` | Generates the container overrides that are derived from vendor and GSI files, and wires the mount hooks in. Runs before the container starts. |
| `var/lib/lxc/android/a50-mount-hooks.sh` | The bind mounts themselves: watchdogd, the USB gadget rc, emservice/cass, the GSI's disabled audio HALs, the 64-bit audio wrapper, and `mixer_paths.xml`. |
| `var/lib/lxc/android/usb.rc.empty`, `rc.empty` | The empty rc files those binds point at. |
| `usr/libexec/lxc-android-config/device-hacks` + `a50-device-setup.sh` | Per boot, after the container: unmask `sensorfwd`, patch `touch.pa`, fix `/dev/gnss_ipc` on an already-created node, enable the Waydroid session unit. |
| `usr/local/bin/a50-dmesg-snap.sh` | Boot logs are otherwise evicted before you can read them. |

## Still not solved here

| Open | Where it stands |
|---|---|
| **Frame pacing** — the default `energy_adaptive` governor starved the compositor to ~37 fps on Droidian; `schedutil` measured a solid 60 | not measured on Ubuntu Touch, and no unit ships for it |
| **Display cutout** — 1080x2340 with a waterdrop centred at the top | Lomiri's own cutout configuration, not Phosh's `halium.json`. Unwritten |
| **AppArmor** | two files here (`50-a50-trust-store.conf`, `50-a50-testing.conf`) exist only because there is no AppArmor. **Delete both** when a kernel with it boots |
| **The `ld.config.txt` rewrite** in `a50-audio-hidl-compat.sh` | the one genuine hack left. `HYBRIS_USE_VENDOR_NAMESPACE` is supposed to make it unnecessary and demonstrably does not work here. [007 §26](../docs/experiments/007-abox-firmware-too-early.md) |

## The debugging technique that found most of the above

```sh
lxc-attach -n android -- /system/bin/logcat -d -b all
```

Android HAL errors appear **nowhere** in the Linux journal or `dmesg`.
Processes running outside the container that load Android libraries through
libhybris log there too, under their own PID. This is what found the display
root cause after `strace` and binder debugfs had both been exhausted.
