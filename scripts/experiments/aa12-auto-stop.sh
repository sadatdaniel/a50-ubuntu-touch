#!/bin/sh
# Retain a temporary kernel wake lock after the experiment; cleared by reboot.
set -eu
B=/userdata/a50-session20-aa12/auto-1
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/boot-id")"
echo a50-auto-test-hold > /sys/power/wake_lock
date -Is > "$B/stopped"
cat /sys/kernel/debug/suspend_stats > "$B/after.stats"
dmesg > "$B/after.dmesg"
cat /sys/kernel/debug/wakeup_sources > "$B/after.wakeup-sources"
sync
