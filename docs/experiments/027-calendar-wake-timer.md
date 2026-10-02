# Calendar wake timer: upstream systemd solution

The October 2 auto7 Wi-Fi hook test proved real automatic deep sleep, but the
relative cleanup timer did not execute at its intended wall-clock deadline.
Research found the same behavior in upstream systemd issue
https://github.com/systemd/systemd/issues/29245 . A resume clock-change event
recalculates relative timer deadlines, effectively adding suspended time.

Upstream merged the fix in PR https://github.com/systemd/systemd/pull/36990 ,
commit bed9d2587c852c6dad5b2959a6313c8590e5d6a6, on June 27, 2025. The device runs
UBports systemd 255.4-1ubuntu8.15; upstream version 255 has the affected logic.
This is a strong match to the observed behavior, not a demonstrated Samsung RTC
failure. The exact UBports package's backport set has not yet been audited.

The upstream issue also reports the standard OnCalendar path works. The next
test therefore schedules a UTC calendar deadline 90 seconds ahead, with
WakeSystem=yes and AccuracySec=1s. The device clock was synchronized before
arming. No systemd replacement, kernel timer patch or private scheduler is used.
Clock adjustments remain relevant for calendar timers; retain manual recovery
until repeated hardware checks establish the intended bounds.

The maintained aa12-auto7-test.sh is updated to this scheduling method. For a
new evidence directory and unique unit names, this run was staged as auto8.
The helper, kernel, Wi-Fi hook configuration and normal wake-count handshake
are unchanged. The normal worker remains a secondary cleanup path.

Auto8's calendar cleanup ran at its requested 05:44:58 UTC deadline (completion
05:44:59), but the worker had aborted before releasing its safety hold: both
Halium and Waydroid run an identically named SystemSuspend process. A single-PID
lookup concatenated both PIDs and failed the existing-worker check. This is an
awake timer validation only, not proof of alarm wake from suspend.

The guard now matches the process PID namespace against `lxc-info -n android
-pH`, then checks only that container's blocked suspend worker. This exact check
passed live with both containers running. The repeat run uses auto9 evidence and
unit names. Across-suspend calendar validation is pending.