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
