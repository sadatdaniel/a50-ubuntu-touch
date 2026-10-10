#!/bin/sh
# Keep the phone awake through a runtime power-manager inhibitor after the test.
set -eu
B=/userdata/a50-session30-aa13/auto-1
case "${1:-}" in
    "") ;;
    --aa17) B=/userdata/a50-aa17-test/auto-1 ;;
    --aa17-startup) B=/userdata/a50-aa17-startup-test/auto-1 ;;
    *) exit 2 ;;
esac
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/boot-id")"
echo "a50-auto-test-hold 3600000000000" > /sys/power/wake_lock
if ! systemctl is-active --quiet a50-test-awake.service; then
    systemd-run --unit=a50-test-awake --property=Restart=on-failure /usr/sbin/repowerd-cli active
fi
timeout 8 python3 /usr/local/bin/a50-wifi-power.py 0 > "$B/wifi-restored"
# The calendar timer and worker EXIT may both run this idempotent cleanup.
if [ ! -e "$B/stopped" ]; then date -Is > "$B/stopped"; fi
cat /sys/kernel/debug/suspend_stats > "$B/after.stats"
dmesg > "$B/after.dmesg"
cat /sys/kernel/debug/wakeup_sources > "$B/after.wakeup-sources"
sync
