# Session handoff 08 - A50 stability investigation

Started 2026-09-11. Previous handoffs are preserved. This document records
verified observations separately from hypotheses; investigation is ongoing.

## Scope and order

1. Suspend/resume and its AppArmor/kernel prerequisites.
2. Check logs and memory every 30 minutes during active work; investigate
   remaining crashes, including Waydroid, one problem at a time.
3. After stability is verified, pursue UBports daily builds and OTA support.
   Display cutouts remain deferred.

Use upstream documentation and existing fixes first. Preserve working boot
images, verify partition read-back before reboot, and record failed tests.

## Initial observations

- Read handoff 07 and experiment 019, plus the initial suspend evidence in 018.
- Port HEAD: e65c685; kernel/build HEAD: 808a8ae. Build repository has untracked
  out-aa1/, out-aa2/, out-aa3/ artifacts; preserve them.
- Rung 3 already built: out-aa3/build-manifest.txt says apparmor=step3,
  built 2026-09-11T05:09:36Z. Whether it is running is not yet established.
- Existing watcher state is dated 03:10 CEST; it is not current evidence.
- Phone reached using PuTTY with the host fingerprint recorded in handoff 02.
  OpenSSH failed host verification; no host verification was bypassed.
- 15:53 CEST baseline: uptime 8h33m; available memory 1652 MiB; swap used
  439 MiB; load averages 16.08/16.19/16.37. Failed units: ssh.service and
  usb-tethering.service. High load requires thread-state inspection before
  attributing it to CPU usage or a kernel fault.
- No phone configuration or boot partition changed in this session so far.

## Documentation checked

- https://docs.ubports.com/en/latest/porting/configure_test_fix/Apparmor.html
  prescribes version-matched patches and AppArmor as the default security
  module. Compiling AppArmor alone is insufficient.
- Finalizing, UBports recovery, and display-cutout documentation located;
  detailed implementation work remains deferred to the relevant task.

## Next

Identify the running boot image and AppArmor state, inspect blocked threads,
recent crash/kernel logs and existing capture tools. Compare rung 3 artifacts
and upstream kernel solutions before choosing a further boot experiment.
## Follow-up evidence

- Read-back of the 55,785,472-byte boot partition prefix equals
  `c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703`,
  matching `/userdata/boot-aa1.img`. Step 3 is staged, not installed now.
- `/sys/module/apparmor/parameters/enabled` is `N`; apparmorfs absent.
- **Do not trust `/proc/config.gz` in these builds.** Vendor
  `kernel/Makefile:120` generates config_data.gz from KCONFIG_BUILTINCONFIG,
  not the resolved .config. The preserved step-3 source .config enables
  AppArmor and disables UH, while its embedded config says the opposite.
  This is a build-system behavior, not evidence of a different running kernel.
- Kernel source confirms console_init at init/main.c:811 precedes
  security_init at :866. However, absence of console text was insufficient
  to locate the prior boot failure.
- **Earlier pre-console diagnosis must be reconsidered:** journals for
  boots -7 through -1 (07:16-07:18 CEST) reached systemd and successfully
  ran apparmor.service. These are after the staged step-3 image timestamp.
  Exact image attribution still needs verification; do not repeat a flash
  solely to pursue the old layout hypothesis.
- Preserved failed journals in `a50-ut-out/session-08/failed-boots.txt`.
  Existing a50-seclog-snap.service overwrites /userdata/sec_log-prev.txt at
  sysinit; copied it to `a50-ut-out/session-08/sec_log-prev.txt`. It mixes
  recovery and current boot records, so it is not a clean failed-boot trace.
- Baseline D-state tasks were TrustZone and simpleinteractive kernel
  threads; no gst-plugin scanner appeared. Load alone is not proof of
  new corruption.
- 20:33 CEST sample: same boot ID, uptime 13h13m, available memory 1642 MiB,
  swap 438 MiB, load about 16. No coredumps since the 15:53 baseline.
  There was a sampling gap; do not claim continuous 30-minute coverage.

Next: identify the post-AppArmor userspace boot-loop trigger using preserved
journals and kernel captures; compare with Halium's existing init/SELinux
integration. No kernel or device configuration changes made yet.

## Concrete userspace failure found

Copied `core.vndservicemanag.1000.1eb3f72765414629b72566945f50e296.3723.1789103782000000.zst`
from the phone to session-08 evidence. Offline libzstd decompression (6,139,904
bytes) exposes the abort message twice:

`Check failed: selinux_status_open(true ) >= 0`

This is direct evidence of a vendor service-manager userspace abort during
the 07:16 boot. It does not by itself prove which component resets the phone.
The dump maps `/system/lib64/libselinux.so`; linker configuration strings
also mention libselinux_stubs.so. Next verify the Halium SELinux-stub
integration and service linker namespace against upstream before changing it.
419 vndservicemanager dump files exist: do not infer the first crash date
from the limited journal/coredumpctl index. No dumps were deleted.

## Existing solution located, not yet applied

- Upstream `Halium/android_external_selinux_stubs` master
  `c1467934ec5b4c3940ab41a015bae981824bf2cb`, cloned under session-08 evidence,
  implements `selinux_status_open()` as return 0 (stubs.c:287).
- Phone already has `/android/system/lib64/libselinux_stubs.so` exporting
  that symbol. Vendor vndservicemanager instead needs `libselinux.so`; its
  init service has no LD_PRELOAD. The service is `shutdown critical` and
  restarts main/hal/early_hal classes on restart.
- Prior porter report describes this exact Halium vndservicemanager fix:
  preload libselinux_stubs.so using the Android init service's setenv option.
  https://irclogs.sailfishos.org/logs/%23sailfishos-porters/2024/%23sailfishos-porters.2024-12-17.log.html
  Use the existing library and existing container mount-hook convention;
  do not invent replacement security stubs or change the kernel first.
- Next: read a50-container-prepare.sh and mount hooks completely, verify
  Android 11 init setenv behavior from source, prepare a scoped service
  override with backups, test linker visibility, then plan a controlled
  AppArmor boot with Android container held back until host access works.
  A service-manager abort alone still does not prove the phone reset cause.
- 20:38 CEST: uptime 13h18m, available memory 1640 MiB, swap 438 MiB.
  Phone remains on step 1; no device modifications in this session.
