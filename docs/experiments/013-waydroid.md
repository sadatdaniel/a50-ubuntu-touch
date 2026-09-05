# Experiment 013 — Waydroid, and Android apps on this port

**Date:** 2026-09-05 · **Status:** ✅ working — F-Droid installed, running, and launchable from the drawer
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

## Tapping the icons did nothing — the launcher environment

Reported after the first install: launching F-Droid from the command line
worked and the app appeared, but **tapping either the Waydroid or F-Droid icon
in the app drawer did nothing at all** — no window, no error the user could see.

Lomiri did start the unit:

```
systemd[4276]: Started lomiri-app-launch--application-legacy--Waydroid--...service
```

so the launch reached systemd and then vanished silently.

**Cause.** Waydroid's generated entries run `waydroid app launch <pkg>`
directly. Started from the launcher they inherit no
`DBUS_SESSION_BUS_ADDRESS`, so waydroid cannot see the running session,
concludes there is none, and tries to start one — which fails. Reproduced
exactly by stripping the environment:

```
$ env -i PATH=/usr/bin:/bin HOME=/home/phablet waydroid app launch org.fdroid.fdroid
[20:15:26] Starting waydroid session
[20:15:26] ERROR: org.freedesktop.DBus.Error.NotSupported: Unable to autolaunch
                  a dbus-daemon without a $DISPLAY for X11
rc=1
```

versus `rc=0` with the variables set. Note the giveaway "Starting waydroid
session" — it never saw the session that was already running.

**Fix.** `overlay/usr/local/bin/a50-waydroid-launch.sh` supplies
`XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS` and `WAYLAND_DISPLAY`, defaulting
them from `id -u` rather than hardcoding a uid, and without overriding a caller
that already set them. Every generated entry is pointed at it:

```
Exec=/usr/local/bin/a50-waydroid-launch.sh org.fdroid.fdroid
Exec=/usr/local/bin/a50-waydroid-launch.sh --full-ui      (Waydroid.desktop)
```

Verified: the identical stripped-environment invocation that returned `rc=1`
now returns `rc=0` with F-Droid running in the container.

`scripts/apply-device-workarounds.sh` applies both this and the `NoDisplay`
fix. **Re-run it after installing new Android apps** — Waydroid regenerates the
entries and they come back hidden and pointing at the bare command.

## Separately: Samsung's camera provider crash-loops

While investigating, `dmesg` showed a process being killed every 5 seconds:

```
libprocessgroup: Successfully killed process cgroup uid 1047 pid 2402 in 0ms
libprocessgroup: ... pid 2405   (5s later)
```

uid 1047 is `cameraserver`. It is **not** Waydroid's — Waydroid's is `stopped`
with no processes. It is the **Halium** container running
`vendor.samsung.hardware.camera.provider@4.0-service`, i.e. the port's
long-known broken camera (see the camera entry in `docs/status.md`).

Whether it predates Waydroid could **not** be determined: the kernel ring
buffer had already rotated (79 entries ≈ 6 minutes), so the earliest visible
timestamp is not the real start. Not attributed to Waydroid without evidence.
It burns CPU and battery continuously and is worth fixing on its own.

## Waydroid's camera provider crash-loops — disabled

**Correction to an earlier note in this file.** The 5-second
`libprocessgroup: killed process cgroup uid 1047` loop was first attributed to
the Halium container's Samsung camera provider. That was wrong. Measured
directly:

| provider | pid over 12 s | verdict |
|---|---|---|
| Waydroid `vendor.camera-provider-2-4` | 3214 → 3217 → 3221 | **restarting every ~6 s** |
| Halium `sec-camera-provider-4-0` | 186, unchanged | fine |

Waydroid's vendor image ships its own
`android.hardware.camera.provider@2.4-service`. This device's camera does not
work under the port at all — the Exynos FIMC-IS driver NULL-derefs in
`fimc_is_devicemgr_open` and can panic the kernel — so that provider dies and
Android init restarts it forever.

Two reasons to stop it rather than tolerate it: it burns CPU and battery
continuously, and it repeatedly pokes a driver known to be able to panic the
kernel.

`overlay/usr/local/bin/a50-waydroid-nocamera.sh` waits for
`sys.boot_completed` inside the container and stops both
`vendor.camera-provider-2-4` and `cameraserver`. It runs as root from a
`waydroid-container.service` drop-in, because `waydroid shell` needs root while
the session unit is a *user* unit.

Verified: provider `stopped` with no pid across repeated checks, zero new
kernel kill messages over 15 s, and Waydroid plus F-Droid still running.

This costs nothing real — the camera was never usable in Waydroid, because it
is not usable on the host either.
