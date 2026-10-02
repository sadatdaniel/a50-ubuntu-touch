#!/bin/sh
# Undo only the runtime bind mount created by stage-wifi-power-hooks.sh.
set -eu
P=/userdata/a50-session29-aa12
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test -f /run/a50-wifi-power-hooks/original.yaml
cmp /run/a50-wifi-power-hooks/a50.yaml /etc/deviceinfo/devices/a50.yaml
echo 'a50-auto-test-hold 600000000000' > /sys/power/wake_lock
timeout 8 python3 "$P/a50-wifi-suspend-mode.py" 0
umount /etc/deviceinfo/devices/a50.yaml
cmp /run/a50-wifi-power-hooks/original.yaml /etc/deviceinfo/devices/a50.yaml
systemctl restart repowerd
systemctl restart a50-test-awake.service
systemctl is-active repowerd a50-test-awake.service
