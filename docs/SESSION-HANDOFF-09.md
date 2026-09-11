# Session handoff 09 - service-manager AppArmor prerequisite

Started 2026-09-11 20:41 CEST. Handoff 08 is preserved.

Previous turn made progress: a failed-boot coredump identified
`Check failed: selinux_status_open(true ) >= 0`, and upstream Halium already
supplies the needed compatibility library. Suspend remains unresolved.

## Current evidence

- Port HEAD initially 7abed99; worktree initially clean.
- Phone: step-1 AppArmor disabled, uptime 13h21m, available memory 1639 MiB,
  swap 438 MiB; no new coredumps since 20:38. Next sample due 21:11 CEST.
- Live mount.sh has the earlier hand-written equivalent of repository hooks;
  a50-container-prepare.sh and a50-mount-hooks.sh are not installed yet.
- Android linker64 supports --list, allowing dependency validation without
  starting a second service manager or touching binder state.
- Read Android 11 init documentation: setenv is a per-service environment
  option. `shutdown critical` is NOT `critical`: it affects shutdown ordering,
  not the repeated-crash reboot rule. Do not use that line alone to claim the
  service-manager abort explains the reset.
  https://android.googlesource.com/platform/system/core/+/android11-release/init/README.md

## Change in progress

Generate a vendor service RC with `setenv LD_PRELOAD libselinux_stubs.so`,
then bind it using the established container mount-hook convention. Preserve
the vendor source; refuse an unexpected existing preload definition.
Live deployment, syntax checks, and AppArmor boot testing are pending.

## Verified and staged at 20:49

- Linker-only probe successfully resolves libselinux_stubs.so for the vendor
  service. No service launched by this probe.
- Isolated checks pass: sh syntax, all vendor options preserved, repeated
  generation unchanged, existing conflicting LD_PRELOAD rejected.
- Live override generated and hook appended. Backup originals under
  /userdata/a50-session09; vendor RC hash remains
  8dda986d89a2ab17268872e823eaa5d3899466c6a81693eddbeebb2070cd12a8.
- Initial installation failed because / is read-only. Used documented
  temporary remount for local testing and restored ro; production change
  remains in repository overlay. No container restart yet.
- Preparing host-only boot of staged aa3 hash
  a2fc8bbabd813603bfe0053441328987308e74e5315fb82c220c856c415d0dd3.
  lxc-android-config.service masked for NEXT boot; currently still active.
  sysinit wants systemd-udev-trigger-real.service (UBports fallback) so host
  coldplug can proceed without Android.
- Temporary a50-test-restore-boot.service before sysinit restores aa1 to
  /dev/sda14 only on security=apparmor boots and only after matching the
  known aa3/aa1 hashes and exact 55,785,472-byte image size. It verifies
  read-back and writes /userdata/a50-session09/boot-restored.txt.
  This preserves a working image for the FOLLOWING reboot; it cannot
  protect against a failure before the service starts.
- Existing kmsg capture now starts before sysinit/lxc; original unit saved
  as /userdata/a50-session09/a50-kmsg-capture.service.before. Drop-in alone
  did not clear After=multi-user.target: verified and removed that original
  line with backup before testing. No ordering errors in systemd verification.

Cleanup after experiment: unmask lxc, remove the temporary sysinit wants
for restore/capture/real-udev, remove restore unit and capture drop-in,
restore original capture unit, daemon-reload. Preserve evidence and backups.
Do not leave Android masked on the daily-use phone.

## Host-only boot test failed (recovery in progress)

Flashed aa3, read-back matched a2fc8bba... before reboot. USB SSH did not
return and the owner reports bootlooping. Owner is entering TWRP; no more
kernel experiments until logs are preserved and normal operation restored.
Do not assume the early restore service ran. Check the partition and its
marker from recovery. The Android-container-only reset hypothesis is not
supported by this test: Android was persistently masked.

Recovery: read reset records before further reboot, mount /data, preserve
current/previous kernel logs and recent capture, verify saved aa1 hash,
restore /dev/block/by-name/boot and verify its image-sized prefix. Remove
the lxc mask and temporary units/wants from
/data/system-data/etc/systemd/system; restore capture unit from
/data/a50-session09/a50-kmsg-capture.service.before. Normal reboot only
after these checks. The preload override is staged but has not run yet.

## Correction and recovered result at 20:58

The owner corrected bootlooping to a logo stall. USB later returned: the
test had reached the early restore service (marker 20:50:52), then panicked
and automatically booted aa1. No TWRP or manual reset was needed.

Captured reset record proves a kernel failure with Android masked:
`BUG mm/usercopy.c:72`, KTIME=8, RSTCNT=1, stack
`__check_object_size -> put_cmsg -> unix_dgram_recvmsg -> sock_recvmsg -> recvmsg`.
Thus the vendor service-manager abort is real but does NOT explain this
kernel failure. Do not ship the preload change as a boot-loop fix yet.
Evidence: `a50-ut-out/session-09/aa3-failure.txt` (reset record, saved sec_log,
previous journal). The full kmsg capture remains on the phone.

Restored normal startup using saved originals: removed test mask, unit,
sysinit wants and early-capture drop-in; original capture unit and mount.sh
compare equal to backups. Removed the untested live preload hook and saved
generated RC in /userdata/a50-session09. Root restored ro.

Normal reboot verified over Wi-Fi 192.168.179.85: Android RUNNING,
sys.boot_completed=1, lightdm active, aa1 boot partition read-back c57250fa...
Available memory 1567 MiB, swap used 270 MiB. USB rndis0 is DOWN; Wi-Fi is
the working link. Next check at 21:28 CEST. Repository preload change remains
pending; do not confuse staged source with a device-verified fix.

Next: inspect exact usercopy rejection and compare the built Unix socket /
AppArmor source with upstream before another boot test. Preserve AppArmor
hardening; do not disable usercopy checks to hide the failure.

## Kernel defect reproduced offline

Precise panic: systemd-journal, at 8.700 seconds, attempted to copy 106 bytes
from `<null>` in put_cmsg. Samsung's call_int_hook macro initializes RC to
the caller's default, then overwrites it with security_integrity_current().
If that returns zero and the hook list is empty, the caller incorrectly sees
success. The built AppArmor lsm.c has no secid_to_secctx hook; the wrapper's
intended -EOPNOTSUPP is lost, leaving SCM_SECURITY output arguments unset.

Compared with Linux v4.14 security/security.c: upstream preserves the default
for empty hook lists. Searched Samsung prior art before changing the macro.
Minimal patch restores RC=IRC after a successful integrity check, retaining
integrity errors and all registered-hook behavior. Hardened usercopy stays on.

Regression extracts the actual macro from source and compiles a small list
adapter: original fails empty -EOPNOTSUPP and positive-default cases; patched
source passes those plus zero-default, integrity-denial and hook-return tests.
One command's shell result aggregation failed because PowerShell expanded a
shell variable; reran the fixed-source test directly, which passed.

Patch: a50-halium/kernel/patches-experimental/security-hook-default.patch.
Test: a50-halium/build/test-security-hook-default.py. Full build wiring added.
Device validation is still required; no claim that AppArmor or suspend is fixed.

## Build now running (21:03 CEST)

- Kernel fix committed/pushed as a50-halium `2b1c523`.
- Docker container `a50-kbuild-aa4`, ID
  `7c5c81b270344f6c160067714c141d73417353f695a2ad33aefc26456526e399`,
  independently verified RUNNING at 21:03. Started 19:03:20 UTC.
- New source volume `a50-ksrc-aa4`, output `a50-halium/out-aa4`.
  Full profile, same step3 cmdline configuration; sole intended kernel-source
  change from aa3 is security-hook-default.patch. Build uses -j4.
- Do not restart the build based on a quiet log. Inspect this exact container.
  Previous a50-ksrc volume and all old images remain untouched.
- 21:03 phone sample: uptime 8m, Android boot_completed=1, lightdm active,
  available memory 1606 MiB, swap 277 MiB; no coredumps since 20:58.
- Next sample due 21:28. Next work: verify build completion/config and hash,
  package using the existing donor, then repeat the guarded host-only AppArmor
  boot. Do not apply the vendor preload at the same time as the kernel fix;
  it is committed as pending preparation, not a boot-verified change.
