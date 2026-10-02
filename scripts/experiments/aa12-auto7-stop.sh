#!/bin/sh
# Keep the phone awake through a runtime power-manager inhibitor after the test.
set -eu
B=/userdata/a50-session29-aa12/auto-7
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/boot-id")"
echo "a50-auto-test-hold 3600000000000" > /sys/power/wake_lock
if ! systemctl is-active --quiet a50-test-awake.service; then
    systemd-run --unit=a50-test-awake --property=Restart=on-failure /usr/sbin/repowerd-cli active
fi
timeout 8 python3 /userdata/a50-session29-aa12/a50-wifi-suspend-mode.py 0 > "$B/wifi-restored"
date -Is > "$B/stopped"
cat /sys/kernel/debug/suspend_stats > "$B/after.stats"
dmesg > "$B/after.dmesg"
cat /sys/kernel/debug/wakeup_sources > "$B/after.wakeup-sources"
sync
