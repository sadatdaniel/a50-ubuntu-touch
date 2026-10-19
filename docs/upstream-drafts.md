# Upstream drafts (for the owner to post)

Each fix the A50 still carries as a package must reach upstream for the
official community-port route ([official-port-plan](official-port-plan.md)).
These are ready-to-post texts. Status column is updated when posted.

| # | Target | Status |
|---|---|---|
| 1 | rootfs-builder-debos: missing `qml-module-lomiri-action` (camera) | draft |
| 2 | rootfs-builder-debos: missing `libexiv2-27-compat` (camera) | draft |
| 3 | rootfs-builder-debos: console-setup cache mtimes on RO root | draft |
| 4 | lomiri-system-settings: lock-security page QtQuick import | draft |
| 5 | Launchpad #2166326: tar on kernels without openat2 | draft (comment) |
| 6 | UBports waydroid packaging: `X-Lomiri-Single-Instance` | draft |
| 7 | waydroid/waydroid#2357: close foreground_pipe descriptors | draft (PR) |

---

## 1. Camera app cannot start: Qt5 Lomiri.Action missing

On Ubuntu Touch 26.04 (daily rootfs, rootfs-builder-debos e117d0f4) the
preinstalled camera app (camera.ubports 4.1.1) exits:
`camera-app.qml:21:1: module "Lomiri.Action" is not installed`. The rootfs
ships only `qml6-module-lomiri-action`. Installing the existing signed
`qml-module-lomiri-action` + `liblomiri-action-qt1` (1.2.2+0~20260619091020.22)
fixes it. Suggest adding `qml-module-lomiri-action` to the 26.04 seed.
Tested on Samsung Galaxy A50 (Halium 11 community port).

## 2. Camera plugin needs libexiv2.so.27

The camera app's `libcamera-qml.so` links `libexiv2.so.27`, which 26.04's
exiv2 no longer provides. The archive already has `libexiv2-27-compat`
(0.27.6-1ubports1+0~20260529190549.1); adding it to the seed (or rebuilding
the plugin against the current exiv2) makes the camera load.

## 3. console-setup.service fails on read-only system-partition installs

In the 26.04 rootfs tarball, `/etc/console-setup/cached_setup_terminal.sh` and
`/etc/default/console-setup` have the same whole-second mtime. The
`console-setup.sh` test `cached_setup_terminal.sh -nt /etc/default/console-setup`
is therefore false, so it runs `setupcon --save`, which fails on the read-only
system partition ("Read-only file system"); the unit ends failed. Suggest
touching the cached files after generating them in the build (or running
`setupcon --save-only` last). A50 port workaround: set the cache 1 s newer.

## 4. lomiri-system-settings: lock security page fails to load

Commit 73e06e78 (Qt6 preparation) switched the security page to
`RegularExpressionValidator`/`regularExpression` but kept `import QtQuick 2.4`;
RegularExpressionValidator needs QtQuick ≥ 2.14 under Qt5, so the page errors
and the change-password dialog cannot open. Raising that page's import to
QtQuick 2.14 fixes it without other changes (A50 package `+a50qtquick.1`,
tested PIN/passphrase/swipe transitions).

## 5. Launchpad #2166326 (tar, comment)

Additional data point: on Halium devices with Linux 4.14 (no openat2), 26.04 tar
fails extracting nested paths (e.g. `dpkg-deb -x`, OTA and Libertine use). Building
the current source with `ac_cv_func_openat2=no` keeps gnulib's runtime ENOSYS
fallback; the rebuilt package passes the 222 upstream tests and an ENOSYS
seccomp reproducer. A runtime fallback in the shipped package would fix all
older-kernel Ubuntu Touch devices.

## 6. UBports waydroid packaging: single-instance launcher entries

Waydroid regenerates app `.desktop` files on every session start. Without
`X-Lomiri-Single-Instance=true`, Lomiri treats each launch as a new instance
and the shared Waydroid window flashes and vanishes. Proposed change in
`tools/services/user_manager.py` (makeWaydroidDesktopFile): write the key and
overwrite instead of remove/recreate (patch:
`scripts/experiments/waydroid-lomiri-single-instance.patch`). Tested across
reboots and repeated close/reopen on the A50.

## 7. waydroid/waydroid#2357 (PR)

Wrap the select loop of `tools/helpers/run_core.py` `foreground_pipe()` in
`with selectors.DefaultSelector() as sel, process.stdout:` so the epoll and the
pipe are closed on every exit. Regression: 200 calls with GC disabled leak
400 fds before, 0 after (`scripts/experiments/test-waydroid-foreground-pipe-fds.py`).
Patch: `scripts/experiments/waydroid-foreground-pipe-close.patch`.
