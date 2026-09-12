# Session handoff 14 - Samsung socket security compatibility

2026-09-12 07:30 CEST. Handoffs 07-13 preserved.

Corrections to handoff 13: aa4 was published as development prerelease
`a50-ubports-halium-2026-09-12-aa4`, with exact source commit 2b1c523567b271bd6da09c0e528f67535bef5741,
checksums, resolved configuration, firmware hashes and rebuild instructions.
AppArmor build integration was committed/pushed as a50-halium 9b89e37.
aa5 FAILED; no new image flashed. Full log: a50-ut-out/session-13/aa5-build.log.

The user confirmed the display cutout works (not the camera). DeviceInfo values
were derived from vendor overlay geometry, applied, and read back. Shell refresh
at 02:32 coincided with Lomiri SIGABRT and camera SIGSEGV; distinguish these from
spontaneous crashes. Port cutout source and docs still need commit/push.

## Current phone

Same aa4 boot ID 208560ab-091a-4e69-ac9e-0f6ed52fd980, uptime 5h17m.
AppArmor, Android and lightdm active. Available memory 1325 MiB, swap used 422
of 2815 MiB. New independent Samsung thermal-service SIGABRT at 03:28:31.
Next health sample due 08:00 CEST. Suspend/resume remains unverified; test only
after AppArmor and permission handling are reliable. Camera still fails.

## Exact aa5 failure

Upstream AppArmor socket code expects `sock.sk_security` to be an allocated LSM
pointer. Samsung changed it to inline `struct sk_security_struct sk_security[1]`
in include/net/sock.h; AppArmor SK_CTX assignments fail compilation.
Samsung also changed SELinux allocation/free to use inline storage, and
net/core/sock.c sock_copy saves/restores that struct around memcpy.
Do not fix only the type or cast the array: allocation/free/clone must agree.
Inspect and compare existing Samsung port fixes and upstream 4.14 first.
Failed source volume a50-ksrc-aa5 remains available; aa4 baseline intact.

Previous automatic approval review blocked source inspection at the usage limit.
User resumed; read-only Docker and phone access now work. No bypass was used.

Priority: full AppArmor and camera authorization; suspend/resume; documented
unified recovery/local OTA; reliable Waydroid using mature port guidance.
Cutout is user-confirmed working. Preserve TWRP, aa1 fallback and aa4 artifacts.

## Compatibility correction prepared

Compared Linux v4.14 include/net/sock.h, net/core/sock.c and SELinux hooks.
No directly reusable Samsung fix found in web/commit searches. Added
socket-security-lsm-pointer.patch: restore generic pointer, preserve destination
pointer through sock_copy, restore upstream SELinux kzalloc/error/free routines.
All three paths must change together. Samsung structure definition stays put;
other security hooks untouched. Patch applies cleanly to aa5; shell syntax passes.
Generator and reference source preserved in a50-ut-out/session-14.
Next: fresh aa6 build, then guarded boot and SO_PEERSEC/permission tests.

Correction committed/pushed as a50-halium ac4c288. aa6 build is RUNNING in
a50-kbuild-aa6 (43608897d5b79728da0540403aaa67b12e9040accfe89e2e05b188cde8e7ff42),
fresh source volume a50-ksrc-aa6, output out-aa6, full/ubports, -j4.
Port cutout and handoffs committed/pushed as 8fbab3b.

Read-only baseline probe now in scripts/experiments/check-apparmor-peer.py:
aa4 reports enabled=Y, caller=unconfined, missing network/af_unix feature and
SO_PEERSEC errno 92 (Protocol not available). Initial manual 4096-byte probe
exceeded Python's getsockopt limit; corrected to 256 before drawing conclusions.
Use the same probe after aa6, then actual app permissions/camera tests.

At 07:39 the aa1 fallback file and on-disk image-sized boot prefix both matched
c57250fa... . No test guards remain installed. Important: aa6 selects AppArmor
by Kconfig, so the next restore guard must NOT require security=apparmor in
/proc/cmdline; check the enabled module parameter and exact test-image hash.

Official OTA migration audit is in docs/ota-finalization.md. No partitions or
recovery configuration were changed. Current work remains AppArmor first.
