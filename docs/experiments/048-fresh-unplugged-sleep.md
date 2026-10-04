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
