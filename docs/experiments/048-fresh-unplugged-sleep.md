# Fresh aa13 unplugged automatic sleep test

4 October 2026. Ubuntu Touch 26.04, AppArmor Y, read-only root. The fresh
installation had zero suspend attempts after the documented native Android
activation and repowerd restart test. Earlier aa12 had 35 successful cycles;
those results do not establish this installation's first-boot behavior.

## Reused procedure

The public aa13-auto-test.sh and aa13-auto-stop.sh adapt the existing
aa12 auto7/auto9 procedure. Changes are the exact aa13 boot hash/length and
private evidence directory, handling an absent awake inhibitor, the installed
Wi-Fi helper, and proof appropriate to that helper. They use the same native
Android SDK 30 enableAutosuspend transaction, namespace-matched worker check,
timed kernel wake lock and standard OnCalendar WakeSystem timer. No forced
/sys/power/state write, security relaxation or new suspend implementation.

The packaged direct DeviceInfo Wi-Fi helper does not create the old experimental
/run mode marker. The test therefore requires screen brightness zero and the
latest driver SETSUSPENDMODE command to request mode 1 before releasing its
hold. This proves command ordering, not full Wi-Fi recovery; actual cycle and
recovery diagnostics plus user screen/touch verification are still required.

Boot guard: first 55,851,008 boot-partition bytes have SHA256
8ae7ab85c08c13b0a7f454882dda3c52162a004a718de2be657d3cd75218fca6.
AppArmor Y, pm_test none, repowerd and the existing bounded kernel collector
are required. Capture uses the published capture-kmsg.py in a runtime unit;
logs remain private and bounded to four 8 MiB files.

To reproduce on this exact boot image, stage scripts under
/userdata/a50-session30-aa13 and record the verified boot ID in
expected-boot-id. Keep USB attached through guard/collector checks. Launch
aa13-auto-test.sh with systemd-run --no-block --unit=a50-fresh-auto-test
--property=Type=oneshot --property=TimeoutStartSec=360 /bin/sh SCRIPT.
Confirm before.stats and the running collector before asking for an unplug.
The test waits at most three minutes for removal and 45 seconds for display
timeout. The separate calendar timer reacquires a hold after 90 seconds; the
worker EXIT also runs cleanup. The user leaves the phone untouched for three
minutes, reconnects USB and checks display/touch.

Cleanup deliberately keeps the phone awake through a temporary inhibitor while
reading after.stats, dmesg and wake sources. Once USB and health are confirmed,
stop the test timer/worker and collector, release a50-auto-test-hold and stop
a50-test-awake.service. Do not remove the awake protections while diagnostics
or a hardware recovery problem still needs them.

## Result

The exact guarded aa13 image completed two real deep-suspend/resume cycles:

- suspend success 0 to 2; failures and all resume-failure counters stayed zero.
- Kernel Timekeeping suspended durations: 11.531 and 78.234 seconds, total
  89.765 seconds. Both cycles show SCSC/WLBT suspend/resume and Exynos MIF down.
- Activation returned already active, with the matching Android namespace
  worker waiting in pm_get_wakeup_count under the test hold.
- Calendar deadline 03:16:17 UTC; first cleanup timestamp 03:16:18 UTC,
  kernel final suspend exit 03:16:19 UTC. The independent timer bounded sleep.
- The user confirms screen and touch work. Kernel boot ID is unchanged,
  swlan0 is connected, AppArmor remains Y, root remains read-only and no system
  units are failed. This checks Wi-Fi association, not complete internet routing.

USB debugging returned offline on cable reconnect. Host adb reconnect offline
did not recover it. Toggling normal Developer Mode restored authorized USB,
without reboot. The pre-toggle daemon had no new FunctionFS enable event after
removal; the toggle restarted adbd. usb-moded also logged a charging-mode UDC
write returning No such device before the developer-mode rebind succeeded.
The read-only stale-config warning is separate and not established as its cause.
This is a USB/debugging recovery defect to investigate against upstream sources,
not a full suspend failure or a proven kernel root cause.

Completed transient units had already unloaded, so cleanup was made idempotent
by stopping only active units. The temporary logger, awake inhibitor and kernel
hold are now removed, with USB still connected. No suspend force or reboot occurred.

## Image startup integration

The overlay now includes the exact tested bounded SDK-30 helper and native unit
ordered after, required by and part of repowerd, enabled through its ordinary
repowerd.service.wants symlink. The installed phone still uses the runtime unit;
the new files need inclusion in a rebuilt image and a clean normal-boot test.
The unit does not force sleep or replace Android wake-lock arbitration.
Container/SystemSuspend restart recovery, screen-on inhibition, repeated cycles
and battery drain remain release checks. Camera PR 84 mounts are also temporary.

Packaging verification: the staged Git archive contains the exact tested helper
(SHA256 6dc44a3feddbbcedb5fe9775b598bbaf8b83a8c5f64ee5c04defe45792fba6a4),
its executable mode and the real relative startup link. The existing public
test-startup-links.py regression now checks all port-owned wants links resolve
and requires the automatic-suspend dependency. It can check the committed tree
or a generated device tarball; this does not substitute for clean-boot testing.

## aa17 follow-up

The existing scripts now accept --aa17; default aa13 behavior is preserved.
Stage under /userdata/a50-aa17-test, with the exact new boot/expected ID guard,
and invoke the same detached test with --aa17. Cleanup receives that flag too,
and its timer is a50-aa17-auto-stop. Native USB configuration must be retained
through sleep; its independent ten-minute rollback was renewed before the test,
then the awake USB hold was released only after suspend preflight passed.

aa17 completed four actual deep cycles totaling 87.409 seconds, zero failures.
Unlike the earlier aa13 test, USB returned automatically after reconnect,
without Developer Mode intervention. Screen/touch are user-confirmed and Wi-Fi
association returned. Actual AppArmor enforcement passed afterward. See
[the USB/kernel evidence](049-usb-native-cable-detection.md). Test timers,
logger and holds were cleaned; native worker activation remains runtime until
the already packaged startup unit is included in a clean rebuilt image.

## Normal installed startup, 10 October

Inspection found the running development image had no permanent activation
helper/unit/wants link; its earlier runtime experiment had ended on reboot.
The existing tested overlay files, with the hashes recorded above, are now
installed through install-autosuspend-startup.sh. The guarded script requires
USB online, AppArmor enabled, active repowerd, SDK 30 and absent target files.
It installs the existing files and a real relative wants link, verifies the
native unit and starts it. No new suspend logic or forced sleep is introduced.

A full system reboot proves ordinary startup: the unit is active with
Result=success and ExecMainStatus=0. The boot journal reports Android automatic
suspend activated, and SystemSuspend has four threads including its worker.
The link resolves to ../a50-enable-autosuspend.service. Root is read-only,
AppArmor is Y and no system units fail. USB-connected counters are zero; this
is startup proof, not an additional unplugged sleep pass. Repeat the bounded
unplugged test, screen-on inhibition and container-restart checks. A rebuilt
clean image and signed OTA must retain this same overlay.

Native verification still warns about the old installed malformed GNSS link
and upstream bluebinder's StartLimitIntervalSec section. Those separate known
warnings are not hidden or established as suspend errors.

### Observation of installed activation

The existing bounded aa13-auto-test.sh and cleanup now accept --aa17-startup.
This isolates evidence under /userdata/a50-aa17-startup-test, retaining earlier
aa17 records. It uses the same verified aa17 boot image guard, normal Wi-Fi
preparation, private bounded kernel collector and independent calendar wake
timer. Unlike --aa17, it does not call enableAutosuspend: it requires the
installed activation unit to be active/successful and proves the matching
Android-namespace worker waits in pm_get_wakeup_count while the test hold is
held. Thus a pass establishes sleep from normal boot activation. Shell syntax
and the existing five startup-link/audio checks pass. Hardware test is armed
after the two successful menu reboots; the result is recorded below.

After staging the three public scripts and expected-boot-id under that path,
start capture-kmsg.py in a50-kmsg-capture and invoke the existing worker with
systemd-run --no-block --unit=a50-fresh-startup-test --property=Type=oneshot
--property=TimeoutStartSec=360 /bin/sh SCRIPT --aa17-startup. Verify before.stats
and active capture before unplugging. Cleanup uses a50-aa17-startup-stop and
the same existing temporary awake hold/inhibitor; remove those after evidence
and connection health are collected. No forced sleep or permanent power
configuration change is introduced by this test mode.

### Normal-startup unplugged result, 10 October

PASS on the unchanged aa17 boot after the two real menu reboots. The test
observed the installed unit active/successful and its Android-namespace worker
in pm_get_wakeup_count; it did not issue enableAutosuspend. Counters increase
from 0 to 9 successful deep cycles, with failures and every resume-failure
counter remaining zero. Kernel Timekeeping reports 76.719 seconds asleep in
those nine cycles. The independent calendar deadline wakes cleanup at
17:23:48 CEST (15:23:48 UTC), with final kernel resume at 15:23:49 UTC.

The user confirms screen and touch work. Kernel boot ID is unchanged,
authorized USB returns automatically without a Developer Mode toggle, Wi-Fi
association/default route recover, and an HTTPS request to the official image
service returns 200. The documentation server returned HTTP 403 after a
successful TLS exchange; curl is not installed. Those first probe outcomes
are not interpreted as failed network recovery. Root remains read-only,
AppArmor Y, package audit clean and Lomiri has zero automatic restarts.

The existing lifecycle checker now accepts --installed to observe the normal
unit without a runtime replacement. It bounds its wait for the dependent
oneshot, since a Type=dbus restart can finish first. Installed activation
restarts successfully with a changed InvocationID when repowerd restarts,
reporting already active; the existing Android worker remains present.
The hardware run of that public checker passes. SystemSuspend/container death
recovery is a separate, still unvalidated case.

The test timers, private kernel collector, repowerd-cli inhibitor and kernel
test holds are removed. Stopping the old temporary inhibitor after repowerd
replacement returns ServiceUnknown for its obsolete unique D-Bus owner and
exit 255; the evidence was inspected before resetting only that observer's
failed state. Final system failed-unit count is zero and no test hold remains.
Optional HBM/performance-booster configuration warnings and a g_object_unref
warning at repowerd exit are retained in private evidence; they did not fail
the activation restart. This bounded check does not establish battery drain,
long idle, screen-on inhibition or clean-image/OTA success.
