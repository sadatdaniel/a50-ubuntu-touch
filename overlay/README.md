# `overlay/` — files overlaid onto the running rootfs

With `deviceinfo_use_overlaystore="true"`, everything in this directory is
installed into `/system/opt/halium-overlay` and overlaid onto the rootfs rather
than replacing it. Required for Ubuntu Touch 20.04 and later. See the guide's
[Overlay page](https://docs.ubports.com/en/latest/porting/configure_test_fix/Overlay.html).

## What is here, confirmed on the device

Both landed in [experiment 006](../docs/experiments/006-what-we-missed.md),
after the device first reached the Ubuntu Touch wizard.

| File | Fix |
|---|---|
| `usr/lib/udev/rules.d/99-a50-binder.rules` | `/dev/hwbinder` and `/dev/vndbinder` came up `0600`, so the greeter (uid 108) could not reach the gralloc mapper HAL and lightdm restart-looped. Stock Android sets all three binder nodes `0666`. |
| `etc/ubuntu-touch-session.d/android.conf` | No device config existed, so the shell fell back to `generic.conf`'s `GRID_UNIT_PX=8` and rendered far too small. `ro.sf.lcd_density=420` → `GRID_UNIT_PX=21`. |
| `etc/resolv.conf` → `/run/NetworkManager/resolv.conf` | The rootfs image shipped a static `resolv.conf` naming `192.168.65.7` — Docker Desktop's internal DNS, captured while the image was prepared in a container. Nothing resolved, so no page loaded, while Wi-Fi and routing were fine. |

## What is expected to go here, from the Droidian port

Each is a *diagnosis* that transfers; the packaging does not. Nothing below is
yet confirmed against Ubuntu Touch.

| Fix | What it will look like here |
|---|---|
| **`/dev/ion` is `0600 root:root`** — this 4.14 kernel predates dma-buf heaps, so legacy ION is the only allocator Mali's gralloc has, and an unprivileged compositor cannot allocate a single buffer | a udev rule under `usr/lib/udev/rules.d/` |
| **Wi-Fi binds the wrong netdev** — the driver exposes three netdevs all typed `managed`, and the network manager picks `p2p0` (Wi-Fi Direct), which scans fine and can never associate | force `wlan0`; NetworkManager config or a udev rule |
| **The vendor audio HAL is 32-bit only** — `audio.primary.exynos9610.so` exists in `/vendor/lib/hw` but not `lib64`, so a 64-bit audio server falls back to the generic stub and gets a stream with a NULL op table | bridge through Android's own 64-bit `audio.hidl_compat` over `/dev/hwbinder` |
| **Frame pacing** — the default `energy_adaptive` governor starves the compositor to ~37 fps; `schedutil` measured a solid 60 | a unit, or a line in `device-hacks` |
| **Display cutout** — 1080x2340, waterdrop centred at the top | Lomiri's own cutout configuration, not Phosh's `halium.json` |

## Ordering: use `device-hacks`, not `runonce`

Anything that touches the Android container, or anything the container
provides, belongs in:

```
overlay/usr/libexec/lxc-android-config/device-hacks
```

which Ubuntu Touch runs with `/bin/sh` **on every boot, after the Android
container is up**.

This is not a style preference. On this device every `runonce` target fired
*before* the container existed, silently no-opped, and was then marked
permanently done — which is how it ran for days with no display cutout and
nothing looking broken. If something is simply *absent* rather than failing,
check `/var/lib/runonce/done/` timestamps before believing anything else.

## The debugging technique that found most of the above

```sh
lxc-attach -n android -- /system/bin/logcat -d -b all
```

Android HAL errors appear **nowhere** in the Linux journal or `dmesg`.
Processes running outside the container that load Android libraries through
libhybris log there too, under their own PID. This is what found the display
root cause after `strace` and binder debugfs had both been exhausted.
