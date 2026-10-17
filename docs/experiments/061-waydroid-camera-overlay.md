# 061 — Waydroid camera provider: per-boot overlay instead of stop helper

16–17 October 2026, aa17, same boot as the 6-day soak.

## Problem

Log check: Waydroid's `vendor.camera-provider-2-4` restarted every 5 s for
days (`init: starting service ... exited with status 1`). The
[013](013-waydroid.md) helper ran once per `waydroid-container.service` start
and gave up after 3 minutes, so every later Waydroid session brought the
loop back.

## Attempts (kernel log shows Waydroid init's own parse messages)

1. Empty vendor overlay `.rc`: no effect. Waydroid's
   `/system/etc/init/init.waydroid.rc` defines the service with `override`.
2. Vendor `.rc` with `override` + `disabled`: rejected by Android 11 init,
   "overrides another service across the treble boundary".
3. **System overlay** `/system/etc/init/zz-a50-nocamera.rc` (`override`,
   `disabled`, no `interface`): accepted. init parses it after
   `init.waydroid.rc`, the vendor definition is "ignored duplicate", and
   **zero starts** follow over more than 2 minutes, with F-Droid, system_server
   and SurfaceFlinger running.

## Fix

`overlay/system/usr/lib/tmpfiles.d/a50-waydroid-nocamera.conf` writes that
file under `/var/lib/waydroid/overlay/system/etc/init/` on every boot.
`/var/lib/waydroid` is persistent userdata, so the rootfs cannot ship it
directly. The rule uses Waydroid's supported `mount_overlays`. It replaces the
013 drop-in and helper, which are removed from the overlay. On this phone the
old helper is still installed until the next image; it is harmless.

Rollback: delete the tmpfiles rule and
`/var/lib/waydroid/overlay/system/etc/init/zz-a50-nocamera.rc`, then restart
Waydroid.

## Separate finding: container daemon fd leak

`lxc-stop` failed with `[Errno 24] Too many open files` (also on 5 October).
After 6d16h, `waydroid container start` held 1021 of 1024 fds: 508 pipes and
502 epoll instances. Restarting the service clears it. Root cause untraced;
private evidence is in `/home/phablet/a50-waydroid-fd-20261017T083953.txt`.
