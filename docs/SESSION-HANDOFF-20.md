# Session 20 — suspend source investigation

2026-09-12. Prior handoffs preserved. Work in progress.

Read handoffs 19, 18, 16, 17, changelog, experiment 018 and OTA finalization.
Local port HEAD b932c3153bf582c3d202315aa22c2f4f592988f6, clean.
Local kernel HEAD ac4c288bfb60e862d5d52ca52a8b5d301b75dbb5;
only existing out-aa1/2/3/4/6 directories untracked. Remote freshness not yet checked.

At 17:04 CEST USB SSH verified boot f8a80a98-56ab-477d-bd96-207cf49b6cdb,
uptime 4h18m and AppArmor N: still the previously identified aa1 fallback.
No flash or PM test performed.

Read exact aa6 Documentation/power/basic-pm-debugging.txt and abox.c from
preserved a50-ksrc-aa6 mounted read-only in a temporary Docker container.
Found a definite diagnostic defect in abox_change_cpu_gear: local s32 freq is
assigned only when data->cpu_gear != gear, but logged unconditionally.
Thus req=1636958208kHz does not establish an actual excessive QoS request;
on the unchanged-gear path the log reads an uninitialized local. The actual
pm_qos_update_request occurs only inside the branch where freq is assigned.
This is not yet a demonstrated cause of the suspend failure.

PM notifier explicitly clears gear requests, flushes gear and IPC work, and
runtime-suspends ABOX during PREPARE. OFF_ON_SUSPEND path restores via
pm_runtime_get_sync on POST when suspend_state==1. Further source and upstream
comparison is required before selecting a suspend behavior change.

Sandbox initially denied SSH and Docker; approved escalated executions worked.
No security settings changed. Health timer not yet resumed. Waydroid and video
status unchanged. No new build, fix, test or publication yet.

## Diagnostic source and build started

Remote main heads verified equal to the supplied local commits.
Actual preserved aa6 .config confirms AppArmor default=y and hardened usercopy=y.
The recovered final sequence was read directly; Wi-Fi scan starts at
1889.389283 during ABOX reload, and capture jumps to the next boot after
1889.423627. No captured panic and no ABOX suspend timeout.

The power-domain callback in drivers/soc/samsung/exynos-pd.c calls abox_poweroff
before pd-dispaud powers off. ABOX runtime_suspend itself only clears enabled;
do not mistake that stub for absence of DSP shutdown.

Read official Repowerd guide. Upstream comparison found Google Exynos commit
5e0f4b78db1043d1eff0a4f45ae8912fe9c4e793 (runtime reference balance on suspend
failure). Retrieved its exact diff. It does not explain aa6's successful
PREPARE path, so it is not bundled into this experiment. The old experimental
abox-runtime-pm-get-sync.patch remains DISPROVED per its README; do not use it.

Kernel diagnostic commit f1b8e4c adds opt-in --abox-freezer-isolation, recorded
in manifest and source sentinel. It skips ABOX PREPARE/POST only with the
root-only freezer_skip_pm option enabled and pm_test=freezer. Other levels
are rejected while the option is enabled; default behavior is unchanged.
It does NOT block independent runtime PM, so logs must prove isolation worked.
The separate QoS logging fix is parked and NOT included in the aa7 build.

Patch application and build-shell syntax pass. Isolated C tests using extracted
functions pass: unchanged/changed/idle/empty QoS paths; notifier refusal of
deeper levels, paired skipped callbacks despite parameter change, original
default PM path. These mock tests do not establish hardware stability.
The first notifier harness run failed because its mock variable shadowed a
local; corrected harness passes. Test scripts are in this Codex task's work/.
Git diff --check flags patch-file context whitespace (required by unified diff)
and an extra README EOF blank; no kernel source whitespace failure established.

At 17:16:46 CEST started Docker container a50-kbuild-aa7-isolation,
id b27927e3b0d7e2e1463d59f465cd989de25fb8c6df4c791b7ded7c1d5394752b.
New volume a50-ksrc-aa7-isolation. Preserved aa6 mounted read-only for local
clean clone and pinned toolchain copy. Output out-aa7-isolation.
Command: ./build/build-kernel.sh --profile full --firmware /fw --apparmor ubports
--abox-freezer-isolation --out /src/out-aa7-isolation.
Poll docker logs/inspect; do not start a duplicate. Build completion pending.

At 17:08 CEST resumed existing health script: initial capture succeeded,
transient a50-health-sample.timer every 30min, next 17:38:09, WakeSystem=no.
48 rotating slots; raw logs remain private. This is automated collection,
not continuous review. Timer ends on reboot.

User is available to force restart or use TWRP if needed. Told user no restart
needed while build runs. No new PM test or flash has occurred.

## Resumed after usage reset — aa7 boot and failed connectivity test

At 22:30 CEST tools worked again. Docker build had completed 17:37:47 CEST,
exit 0 (about 21 minutes). Image SHA256:
f96e37acdd2c444b428986bd5eb7eafa0961f4d047f62345fd6877a7a45bcbad.
Packaged with verified 90c281f8 donor, unchanged ramdisk e78e8cb8... .
boot-aa7.img 55,851,008 bytes, SHA256:
2cdeb6352c757a83583379dde3a6e0df11c2a4b02072f001e3b25c782f4bea4b.
Actual aa7 configuration matches preserved aa6 byte-for-byte.

Normal boot succeeded, boot ID 70e806c5-3b4e-445b-8873-80e7a087d4c7,
AppArmor Y, Android boot_completed=1, lightdm and persistent capture active.
User confirmed screen and touch work. At 22:32:39 guard restored aa1; exact
55,785,472-byte partition prefix c57250fa... verified. Guard cleanup completed,
root returned RO. On-disk boot is aa1, running kernel was aa7.

Stopped Waydroid session/container normally and resumed 30min health timer,
WakeSystem=no. Initial stats success=0/fail=0. Pretest ABOX runtime active,
/sys/module/abox/parameters/freezer_skip_pm=N. No kernel fault or blocked
camera-close task found; D-state samples were vendor TZ and governor workers.
Wi-Fi address after this reboot 192.168.179.86; USB 10.15.19.82.

Ran ONE systemd a50-freezer-isolation-test.service invoking the prepared
/userdata/a50-session20/freezer-isolation-test.sh. It verifies fallback and
boot ID, captures baseline, enables diagnostic mode, writes freezer then mem,
and restores settings with an EXIT trap. No deeper test attempted.
First post-test USB SSH failed with Software caused connection abort.
Wi-Fi SSH then timed out. No successful post-test response obtained; whether
the cycle returned and whether ABOX isolation actually occurred is pending
recovery of logs. Asked user to check screen/touch without restarting yet;
physical state confirmation pending. Do not claim ABOX exonerated or fixed.
No repeated test. Next: user-assisted restart into verified aa1 if frozen,
recover fixed-size persistent log tail and session20 result files before
further PM work. TWRP only if normal fallback boot cannot recover.

## Recovered failure and watchdog candidate, 2026-09-13

User confirmed aa7 rebooted automatically. USB recovered on aa1; no manual
restart or TWRP was needed. /proc/last_kmsg yielded a full prior panic; private
copy is a50-ut-out/session-20/last_kmsg-aa7.bin. after-isolation.dmesg confirms
ABOX PREPARE/POST skipped and no ABOX power-cycle in the test window. Freezer
returned after5s but stability failed. No deep suspend validated.

Full ring shows storage timeout before I2C/GPU/sensor-hub/Wi-Fi failures. The
final exception maps to the Wi-Fi confirmation-timeout WARN (BRK #0x800), not
an established NULL callback. Samsung's hardlockup hook replaces the recorded
PC before warning classification; do not treat the displayed PC0 as evidence
of random memory corruption.

Strong lead: freezer emergency watchdog stop/start unconditionally arms an
inactive secondary watchdog. Captured timer count/prescaler imply about21s,
matching onset of the wider failures. Candidate preserves hardware ENABLE
state across the paired calls; normal watchdog/panic/reset/security behavior
is unchanged. Cause remains pending hardware validation.

Kernel commit ba9b108 adds opt-in --watchdog-freezer-fix and mocked-helper
regression checks. Inactive/active repeated pairs, unmatched start, and
absent-device tests pass, as do patch application and build-shell syntax.
No new hardware test yet. Phone was responsive on aa1 at05:15 CEST.

New running build: a50-kbuild-aa8-watchdog; volume a50-ksrc-aa8-watchdog.
Output out-aa8-watchdog. Recipe full/ubports plus --watchdog-freezer-fix;
ABOX isolation is NOT included. aa6 source volume remains read-only baseline.
Poll existing container; do not duplicate. Next: verify build/config, package
with known donor, guarded boot and fallback verification, one controlled
freezer cycle then delayed observation. Health timer ended on reboot.

Approval review initially rejected publication for unverified destinations.
Read-only remote checks match both repositories explicitly named by the user,
who requests a numbered handoff and commit/push of completed work. Raw logs
remain local; this handoff records technical conclusions and build status only.

## aa8 phone validation, 2026-09-13 morning

Built ba9b1083db656b0f8f5f5961c0095a045d3e59eb successfully. Image SHA256
e197a4f9a02790fdf21278e33832720ff1cc42b3aab24cd62d0e4f173fbdbda6;
boot image 55,851,008 bytes SHA256
9f219dfa364fb5a0cf279ceaee7563f3371c930649ed528a7c457ce04ba02927.
Normal boot succeeded 08:02 CEST, boot ID
38ea8a8e-4874-4384-887b-2e1ba50607a7. AppArmor Y, Android completed,
lightdm/capture active. Guard restored and verified aa1 on disk at08:02:55;
temporary guard removed, root RO. No manual restart/TWRP needed.

Stopped Waydroid normally. First freezer cycle08:05:10–08:05:15:
both watchdog stops were initiallyinactive, both starts preservedoff.
Normal ABOX power-cycle and firmware-ready confirmed. Unchanged boot and
USB/Wi-Fi SSH survived ten minutes with no delayed timeout cascade.
Second cycle08:15:38–08:15:43 also returned, success2/fail0, identical
watchdog state preservation. Delayed checks clean through08:18:18.
User screen/touch confirmation for this boot remains unanswered.

Next staged script: /userdata/a50-session20-aa8/devices-watchdog-test.sh,
not yet run as of08:18. It checks fallback, boot ID and AppArmor before
one devices-stage test. Do not jump to full deep sleep or claim it works.
Health timer active with30min slots and WakeSystem=no. Private evidence
under a50-ut-out/session-20-aa8; remote /userdata/a50-session20-aa8.
Artifacts including configuration, symbols, reproduction instructions and
checksums prepared in a50-halium/out-aa8-watchdog; not yet published.

## Validation update, 2026-09-13 10:20 CEST

Two freezer-only cycles passed with normal ABOX behavior; the first was
observed for ten minutes before repetition. Both stages of both cycles
confirmed was_enabled=0 and kept the secondary watchdog stopped.

One devices-stage test ran08:19:30–08:19:36 and returned successfully
(success3/fail0 total). Windows then reported Device Descriptor Request
Failed, while the phone believed its USB gadget was configured. Wi-Fi
remained usable; the phone did not reboot. Unbinding/rebinding the existing
g1 UDC restored enumeration, but recreated rndis0 without its address.
Restoring its original10.15.19.82/24 address plus temporary169.254.68.82/16
allowed USB SSH using Windows' existing link-local subnet. Host address
change was denied by Windows administrator permissions; no host setting
was successfully changed. A gadget DCTL stop timeout occurred during the
manual reconnect, separate from the original watchdog failure cascade.

Same aa8 boot remained responsive over both Wi-Fi and recovered USB at
10:20 CEST, over two hours after the devices-stage test. No full deep sleep
attempted. Device-stage return does not establish complete driver resume:
USB still needs a fix. Watchdog correction stays opt-in pending broader
validation. Screen/touch response from user for aa8 remains pending.

## Published aa8 and continuation, 2026-09-13 10:24 CEST

Published and verified prerelease assets at:
https://github.com/sadatdaniel/a50-halium/releases/tag/a50-ubports-halium-2026-09-13-aa8
Target build revision ba9b1083db656b0f8f5f5961c0095a045d3e59eb. Nine assets
uploaded, server digests match kernel/boot/config values. Kernel documentation
commit dde0ed4 and port documentation062aa64 are pushed.

Current connections: Wi-Fi192.168.179.86; recovered USB169.254.68.82.
Original10.15.19.82 remains on phone but Windows interface47 (Ethernet8)
uses169.254.68.233/16. Temporary link-local phone address is not a persistent
fix. Windows host IP change failed with Access denied; no UAC workaround.
Running boot ID38ea8a8e-4874-4384-887b-2e1ba50607a7, AppArmorY, aa1 on disk.

USB source lead: actual DT dr_mode=otg, debugfs mode=device. In this pinned
core.c, OTG suspend only calls dwc3_event_buffers_cleanup; OTG resume omits
paired gadget suspend/resume. Those callbacks run in peripheral mode only.
Do not blindly copy them under the lock: this tree's gadget_suspend calls
synchronize_irq, and lock ownership/callback behavior needs review. No USB
kernel patch written yet. Full/deeper suspend testing remains paused.

## USB-detached comparison, 2026-09-13 10:25–10:27 CEST

One controlled devices-stage comparison detached the existing g1 gadget
before entering pm_test=devices, then reattached it and restored the same
phone USB addresses. Test ran10:25:28–10:25:36, service Result=success,
ExecMainStatus=0, total suspend statistics success4/fail0. Windows recreated
its RNDIS adapter successfully without Device Descriptor Request Failed;
USB SSH to169.254.68.82 worked at10:26:38. Same boot identity, AppArmorY,
Wi-Fi also remained usable. No timeout marker beyond the intentional5s
PM debug delay was present in the immediate post-test check.

This comparison supports active gadget state as the USB resume problem.
It is a diagnostic result, not a production reconnect hook or full sleep fix.
Raw evidence: local a50-ut-out/session-20-aa8/devices-usb-detached-after.dmesg;
remote /userdata/a50-session20-aa8/devices-usb-detached-1/.

Before writing an OTG callback patch, account for this exact tree's lock
hazard: core.c calls dwc3_gadget_suspend under dwc->lock; gadget_suspend calls
synchronize_irq; dwc3_interrupt acquires dwc->lock. Simply invoking the helper
in the OTG branch can deadlock. The IRQ wait must occur outside that lock.
Role-switch serialization, paired active-device state, unplug during sleep,
and propagation of resume failures also need explicit review/testing.
No USB kernel patch applied or new build started. No deeper PM test run.

## User confirmation and OTA readiness audit, 2026-09-13

User confirmed screen and touch remain normal after aa8 tests. Asked whether
suspend now works and requested the UBports finalization/recovery/local OTA/
installer path. Explained full sleep/wake remains unvalidated and active USB
resume still fails; watchdog correction alone is not complete suspend support.
Waydroid must be reliable but user explicitly defers it until later.

Reviewed the three linked official finalization pages and actual installer
schema/README. Installer guide is a placeholder; schema supports Heimdall and
systemimage recovery verification. Do not copy fastboot instructions to Samsung
without verifying transport. No upstream messages or registration requests sent.

Read-only audit10:35–10:36 confirms / is loop0 backed by /userdata/rootfs.img,
16GiB filesystem with about4GiB used. system=5300MiB, recovery=64.5MiB,
cache=400MiB, userdata=120280055808bytes. /cache->/android/cache currently uses
userdata. system-image-common/dbus/cli installed, but config.d is empty and
no top-level channel.ini/client.ini exists. No update check/apply invoked.
Repository remains6144M with recovery disabled and unpinned build-tool wrapper.

Updated docs/ota-finalization.md with a concrete staged plan: suspend/USB,
pinned correctly sized fresh build, unified recovery and mounts, local OTA,
upstream signed channel/CI integration, Samsung installer, later Waydroid soak.
Preserve TWRP and userdata. No storage or update-client configuration changed.
Current published aa8 remains running; no new kernel build started.

## aa9 USB system-sleep candidate building, 2026-09-13 10:44 CEST

User explicitly asks to continue fixing suspend/resume; phone connected.
Kernel commit9ee1c1af122e69b696435f859236d28e80b8e9c0 is pushed. New opt-in
--usb-otg-sleep-fix adds active B-peripheral gadget quiesce/restore, remembered
paired state, role/FSM and driver locking, IRQ wait outside both locks,
callback error propagation and runtime PM reference balancing. Existing
watchdog flag remains enabled. Host and inactive OTG behavior is preserved;
vendor PHY init is unchanged. Hardware validation remains pending.

Actual-helper compiled tests pass: repeated connected pairs; inactive/unbound/
host cases; unplug, role change, soft disconnect and unbind during sleep;
unmatched resume; runtime/get/stop/start errors; IRQ wait lock assertions;
PM reference accounting and peripheral/host paths. bash -n passed. git apply
--check --whitespace=error-all on the exact baseline passed. git diff --check
on the patch-as-a-new-file warns about normal unified-diff context indentation;
those are not added kernel source whitespace errors.

Running build a50-kbuild-aa9-usb-sleep, container
f2a4eaff53a4d7d5393a579a7cd0aa0856ac6fbf6c11958a0418afbbb9c074b6,
started08:44:04 UTC. New source volume a50-ksrc-aa9-usb-sleep; aa8 baseline
mounted read-only. Recipe full/ubports +watchdog-freezer-fix +usb-otg-sleep-fix,
output out-aa9-usb-sleep. No ABOX isolation. Poll this container; no duplicate.

Prepared host recovery guards in a50-ut-out/session-20-aa9 (not uploaded/armed).
Local task work/aa9-pm-test.sh accepts one freezer/devices cycle per invocation,
checks active bound/configured USB, boot identity, AppArmor and aa1 fallback.
No automatic gadget reconnect is performed by that script: next devices test
must establish automatic USB re-enumeration. New boot identity/hash must be
recorded after packaging/guarded flash. Current phone still runs aa8 boot
38ea8a8e-4874-4384-887b-2e1ba50607a7; Wi-Fi192.168.179.86, USB169.254.68.82.

Read-only wake audit: s2mpu09 RTC wake enabled, no alarm pending, repowerd
active, pm_test none, mem_sleep deep selected; no autosleep node. No wake
alarm or automatic suspend setting changed. Full sleep has not been tested.
