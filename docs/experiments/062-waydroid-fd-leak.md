# 062 — Waydroid container daemon descriptor leak

17 October 2026, aa17. Upstream bug [waydroid/waydroid#2357](https://github.com/waydroid/waydroid/issues/2357)
(open, no fix merged).

## Evidence

After 6d16h the daemon (`waydroid container start`) held 1021/1024 fds: 508
pipes and 502 epoll instances. `lxc-stop`/`lxc-info` then failed with
`[Errno 24] Too many open files`: Waydroid reported the container STOPPED while
Android kept running. The same error occurred on 5 October.

## Cause

`tools/helpers/run_core.py` `foreground_pipe()` never closes its
`selectors.DefaultSelector()` (epoll) or `process.stdout` (pipe). A selector
reference cycle keeps both alive until the cyclic GC runs, which rarely happens
in the idle GLib daemon. Each command leaks one pair.

## Fix

`scripts/experiments/waydroid-foreground-pipe-close.patch` wraps the loop in
`with selectors.DefaultSelector() as sel, process.stdout:`.
`test-waydroid-foreground-pipe-fds.py` runs the real function 200 times with GC
disabled: the original leaks +400 fds, the patched version none. The build
script guards source and result hashes and runs the test both ways. The
changelog date is pinned, so dpkg's SOURCE_DATE_EPOCH is fixed: CI runs
39029981210 and 39030052392 produced byte-identical
`…+a50singleinstance.2+fdclose.1_all.deb` (SHA256 `2817960d…ea737`).

## Phone validation

Installed with `install-waydroid-single-instance.sh`: APT, hash-checked, root
returned to RO, dpkg audit empty, container service restarted. The installed
`run_core.py` (`f008879a…`) passes the fd test on the phone. Waydroid and
F-Droid start; zero camera-provider starts ([061](061-waydroid-camera-overlay.md)).
Rollback: `install-waydroid-single-instance.sh --rollback` restores locked
`.2`.

## Remaining

- Soak: confirm `Too many open files` stays absent after multi-day uptime
  (currently 4 historical lines in `waydroid.log`), then move the lock from
  `.2` to `fdclose.1`.
- Submit the patch upstream on #2357 (needs owner; external write).
- The other four package scripts still use an unpinned `dch` date, so they
  are not byte-reproducible. Their locked archives are preserved in release
  `inputs-20261017`. Pin dates when they are next rebuilt.
