#!/bin/sh
set -eu
B=/userdata/a50-session29-aa12
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/expected-boot-id")"
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
test "$(cat /sys/class/power_supply/usb/online)" = 1
systemctl is-active --quiet repowerd a50-test-awake.service
timeout 8 lxc-attach -n android -- /system/bin/dumpsys suspend_control | grep -q repowerd
test ! -e /run/systemd/system/a50-enable-autosuspend.service
sh -n "$B/a50-enable-autosuspend.sh"
install -m 644 "$B/a50-enable-autosuspend.service" /run/systemd/system/a50-enable-autosuspend.service
systemctl daemon-reload
systemctl enable --runtime a50-enable-autosuspend.service
systemctl start a50-enable-autosuspend.service
first=$(systemctl show -p InvocationID --value a50-enable-autosuspend.service)
test -n "$first"
printf 'a50-startup-check 120000000000\n' > /sys/power/wake_lock
systemctl restart repowerd
systemctl restart a50-test-awake.service
systemctl is-active --quiet repowerd a50-test-awake.service a50-enable-autosuspend.service
second=$(systemctl show -p InvocationID --value a50-enable-autosuspend.service)
test -n "$second"
test "$first" != "$second"
printf 'a50-startup-check\n' > /sys/power/wake_unlock
journalctl -u a50-enable-autosuspend.service --since '-2 minutes' --no-pager
echo REPOWERD_ACTIVATION_LIFECYCLE=PASS
