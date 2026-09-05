# Experiment 013 — Waydroid, and Android apps on this port

**Date:** 2026-09-05 · **Status:** ✅ working — F-Droid installed and running
· **Device needed:** yes

## What was actually missing

Waydroid was **already installed** (`waydroid` 1.6.3 + `waydroid-sensors`, the
UBports builds), so this was never a packaging job. It could not run for one
reason: **binder**.

Waydroid needs its own binder domain. Reading the installed source rather than
guessing — `/usr/lib/waydroid/tools/helpers/drivers.py`:

```python
BINDER_DRIVERS    = ["anbox-binder",    "puddlejumper",    "bonder",    "binder"]
VNDBINDER_DRIVERS = ["anbox-vndbinder", "vndpuddlejumper", "vndbonder", "vndbinder"]
HWBINDER_DRIVERS  = ["anbox-hwbinder",  "hwpuddlejumper",  "hwbonder",  "hwbinder"]
```

It prefers the `anbox-*` nodes and falls back to the plain ones — but those are
already owned by the Halium `android` container, so sharing them collides.

Its other route is binderfs (`isBinderfsLoaded()` checks `/proc/filesystems`
for `binder`, then allocates nodes through `/dev/binderfs/binder-control`).
**This 4.14 tree has no binderfs at all**: `drivers/android/` contains no
`binderfs.c`, and its Kconfig offers only `ANDROID_BINDER_DEVICES`. So the
extra nodes have to be compiled in statically.

The defconfig had:

```
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
```

### The fix

One config change, in a50-halium's `build/build-a50-release-kernel.sh` Kconfig
injection:

```
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder,anbox-binder,anbox-hwbinder,anbox-vndbinder"
```

Low risk by construction — it registers three more misc devices and changes
nothing existing. After flashing:

```
crw------- 1 root root 10, 62 /dev/anbox-binder
crw------- 1 root root 10, 61 /dev/anbox-hwbinder
crw------- 1 root root 10, 60 /dev/anbox-vndbinder
```

and Waydroid picked them on its own — `/var/lib/waydroid/waydroid.cfg`:

```
binder = anbox-binder
vndbinder = anbox-vndbinder
hwbinder = anbox-hwbinder
```

`waydroid-sensord` runs against `/dev/anbox-hwbinder`, confirming the split
domain is real and in use.

## Bringing it up

`waydroid init` selected the right images by itself: LineageOS 20 (Android 13)
`VANILLA` system, and — importantly — the **`HALIUM_11`** vendor image, matching
this port's Android 11 vendor base. `waydroid status` reports
`Vendor type: HALIUM_11`.

Images land in `/var/lib/waydroid/images` (1.9 GB system + 89 MB vendor).
Note `/var/lib/waydroid` is **already a mount from `/dev/sda32`** (userdata), so
they never touch the rootfs — the rootfs growth done the same day was for
general headroom, not for this.

### The one real trap: the session's D-Bus address

Starting the session as root, or with `su phablet -c`, fails:

```
ERROR: org.freedesktop.DBus.Error.AccessDenied:
       Failed to connect to socket /run/user/0/bus: Permission denied
```

The bus address is still root's. Setting all three variables explicitly works:

```sh
XDG_RUNTIME_DIR=/run/user/32011 \
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus \
WAYLAND_DISPLAY=wayland-0 waydroid session start
```

but the durable answer is a systemd **user** unit, which inherits the right
values from the user manager. Shipped as
`overlay/usr/lib/systemd/user/waydroid-session.service` and enabled by
`scripts/apply-device-workarounds.sh`. `waydroid-container.service` is `static`
and starts on demand, so only the session needs arranging.

## Result

```
Session:      RUNNING
Container:    RUNNING
Vendor type:  HALIUM_11
IP address:   192.168.240.112
Session user: phablet(32011)
```

Inside the container: Android **13**, `ro.product.model` = `SM-A505F`.

**F-Droid installed and running:**

```
waydroid app install /tmp/F-Droid.apk
pm list packages | grep fdroid   -> package:org.fdroid.fdroid
ps -A | grep fdroid              -> u0_a125 ... org.fdroid.fdroid
```

Confirmed on screen by the user.

### No regressions

With Waydroid running **alongside** the Halium `android` container — the thing
most likely to break — everything still works:

| check | result |
|---|---|
| lightdm | active |
| Halium android container | `sys.boot_completed=1`, RUNNING |
| GPS | `@GNSSND` bound |
| Bluetooth | `hci0` up |
| Telephony | ofono `registered` |
| Audio | PulseAudio running |
| Memory | 2.0 GB used of 3.5 GB |

## Gotchas worth knowing

* **Every generated app entry is `NoDisplay=true`.** Waydroid writes
  `~/.local/share/applications/waydroid.<pkg>.desktop` with `NoDisplay=true`, so
  installed Android apps are invisible in the Lomiri app drawer (13 of them
  here). The workarounds script now flips these to `false`.
* `waydroid shell` needs root; as `phablet` it fails with
  `Action "shell" needs root access`.
* The `anbox-*` nodes come up `0600 root:root`. Waydroid runs as root so this is
  fine, but it is the same permissions class that bit `/dev/gnss_ipc` and the
  binder nodes before — check here first if something unprivileged ever needs
  them.
* There is a stray `/dev/*binder -> /dev/binderfs/*binder` symlink (a literal
  glob, from something expanding with no matches on a kernel without binderfs).
  Harmless, but it is not a real device node.

## Not done

* Auto-starting the session is enabled but **not yet verified across a reboot**.
* Battery and thermal impact of running two Android containers is unmeasured.
* Google Play / Play Integrity is not attempted; this is the `VANILLA` image.
