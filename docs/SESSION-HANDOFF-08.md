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
