# Experiment 019 — the AppArmor ladder, executed

**Date:** 2026-09-11 · **Status:** 🔴 step 2 does not boot (pre-console
death); step 1 verified booting · **Device needed:** yes

## Why

Three userspace bugs trace to the missing kernel AppArmor: media-hub-server
segfaults on every app `openUri` (symbolized in
[018](018-suspend-freezer-wifi-instability.md): `apparmor
Context::profile_name()` doing QString arithmetic on a garbage context),
trust-store and biometryd carry `*_IS_RUNNING_UNDER_TESTING` workarounds, and
the camera app's permission error is the same trust-store wall. The 2026-09-05
attempt (four config changes at once) died before USB enumeration — 008's
appendix prescribed splitting the variables.

## The ladder, and what each rung proved

| rung | config | Image/boot | result |
|---|---|---|---|
| step 1 | `CONFIG_SECURITY_APPARMOR=y` only, SELinux default | boot `c57250fa…` (55,785,472 B) | **boots**; Wi-Fi/container/services healthy; `/sys/module/apparmor` exists (the `BOOTPARAM_VALUE=1` line initializes the module even while SELinux is the default LSM) but apparmorfs is not mounted and `aa-status` reports "apparmor filesystem is not mounted" — inert, as designed |
| step 2 | + `CONFIG_DEFAULT_SECURITY_APPARMOR=y`, `CONFIG_DEFAULT_SECURITY="apparmor"` (SELinux still compiled, bootparam untouched) | boot `3bdf7e6d…` | **does not boot**: no USB/RNDIS at all; TWRP's `/proc/last_kmsg` shows the kernel's own early sec_debug init reached 1.157 s and then absolute silence — it dies before the console is up, long before LSM initcalls would print |

## What the pair of results means

- The AppArmor **code** compiles and boots on this kernel (step 1, 5-minute
  smoke + healthy services).
- The **default-LSM switch** (`CONFIG_DEFAULT_SECURITY="apparmor"`) is the
  killer, and it kills *early* — a pre-console death in `start_kernel()`,
  not a panic in `apparmor_init()` (which would print). The 2026-09-05
  failure is the same signature, so it was never the SELinux-bootparam part.
- A config-only change causing a pre-console death smells like an Image
  layout/link-time effect rather than LSM logic. The crash registers that
  would settle it were lost: the recovery's force-off registered as PIN
  RESET and Samsung's sec_debug cleared its buffers.

## Reproducibility notes

- Both rungs build with `./build/build-kernel.sh --profile full --firmware
  /fw --apparmor stepN`; the rung is recorded in `build-manifest.txt`
  (`apparmor=step1/step2`), each is a distinct Image hash, and the script
  refuses to switch rungs on a reused source volume (a stopped container
  holding the `a50-ksrc` volume also blocks `docker volume rm` — remove the
  container first).
- In TWRP the boot partition is `/dev/block/by-name/boot` (sda14); the
  running system's `/dev/disk/by-partlabel/boot` path does not exist there,
  and `/data` must be mounted before `dd` reads staged images from it.
- Read-back hashing must use the *image's* size — both rungs' images are
  55,785,472 B (the AppArmor code grew the kernel ~330 KB over the
  55,449,600 B fimc-fix image); hashing the old prefix length produces a
  false mismatch.

## Rung 3 options (next kernel session)

1. Re-run step 2 with early capture armed so the death is witnessed:
   `earlycon=` in CONFIG_CMDLINE, and read the reset-reason registers
   *before* any manual reset (a PIN RESET clears them — let a self-reboot
   land instead of force-off, or accept the loss and go straight to 2).
2. Bisect the config delta itself: `CONFIG_DEFAULT_SECURITY_APPARMOR=y`
   without the string (or vice versa) as step 2a/2b.
3. Read this tree's `security/` and Samsung's early-init diffs against a
   4.14 that boots with AppArmor default (e.g. a mainline-based Halium
   port) for anything layout- or link-order-sensitive.

## Where the device was left

Restored to the step-1 image `c57250fa…` (AppArmor compiled, inert) from
TWRP, read-back verified, booted healthy. Backups on /userdata:
`boot-aa1.img` (this), `boot-fimcfix.img` (`fe4e753a…`, 5 h stable),
`boot-racefix.img` (`2e5073f4…`). The released kernel remains
[a50-ubports-halium-2026-09-10](https://github.com/sadatdaniel/a50-halium/releases/tag/a50-ubports-halium-2026-09-10).
