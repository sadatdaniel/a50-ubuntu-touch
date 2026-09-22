#!/bin/sh
# Bounded activation of Android 11's normal wake-lock-aware suspend loop.
set -eu
umask 077
P=/userdata/a50-session20-aa12
B="$P/auto-1"
test ! -e "$B"
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
grep -q '\[none\]' /sys/power/pm_test
test "$(head -c 55785472 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
systemctl is-active --quiet repowerd
systemctl is-active --quiet a50-kmsg-capture
test -f "$P/aa12-auto-stop.sh"
mkdir "$B"
cat /proc/sys/kernel/random/boot_id > "$B/boot-id"
echo a50-auto-test-hold > /sys/power/wake_lock
trap 'sh "$P/aa12-auto-stop.sh"' EXIT HUP INT TERM
cat /sys/kernel/debug/suspend_stats > "$B/before.stats"
cat /sys/kernel/debug/wakeup_sources > "$B/before.wakeup-sources"
dmesg > "$B/before.dmesg"
# CLOCK_BOOTTIME_ALARM wakes the system even if the worker's sleep is paused.
systemd-run --unit=a50-aa12-auto-stop --on-active=90s --timer-property=WakeSystem=yes /bin/sh "$P/aa12-auto-stop.sh"
systemctl is-active --quiet a50-aa12-auto-stop.timer
systemctl show a50-aa12-auto-stop.timer -p WakeSystem -p NextElapseUSecMonotonic > "$B/timer"
grep -q '^WakeSystem=yes$' "$B/timer"
# Android 11 AIDL method 1 is enableAutosuspend(); method 3 would force sleep.
timeout 8 lxc-attach -n android -- /system/bin/service call suspend_control 1 > "$B/activation"
grep -Eq '00000000[[:space:]]+00000001' "$B/activation"
date -Is > "$B/started"
echo a50-auto-test-hold > /sys/power/wake_unlock
sleep 60
# EXIT re-acquires the hold; the independent timer also does so after 90 seconds.
