#!/bin/sh
# Reversible startup/restart check; Android retains normal suspend arbitration.
set -eu
[ "$(id -u)" = 0 ]
expected_boot=${1:?Pass the observed kernel boot ID}
[ "$(cat /proc/sys/kernel/random/boot_id)" = "$expected_boot" ]
[ "$(cat /sys/class/power_supply/usb/online)" = 1 ]
[ "$(cat /sys/module/apparmor/parameters/enabled)" = Y ]
systemctl is-active --quiet repowerd.service
unit=a50-enable-autosuspend.service
stage=/run/a50-autosuspend-test
[ ! -e /run/systemd/system/$unit ]
[ ! -e "$stage" ]
source=${2:?Directory containing the published activation script and unit}
install -d -m 0700 "$stage"
install -m 0644 "$source/a50-enable-autosuspend.sh" "$stage/"
sed "s|^ExecStart=.*|ExecStart=/bin/sh $stage/a50-enable-autosuspend.sh|" "$source/a50-enable-autosuspend.service" > /run/systemd/system/$unit
printf 'a50-startup-check 120000000000\n' > /sys/power/wake_lock
trap 'printf "a50-startup-check\n" > /sys/power/wake_unlock' EXIT
systemd-analyze verify /run/systemd/system/$unit
systemctl daemon-reload
systemctl enable --runtime "$unit"
systemctl start "$unit"
first=$(systemctl show -p InvocationID --value "$unit")
[ -n "$first" ]
systemctl restart repowerd.service
systemctl is-active --quiet repowerd.service "$unit"
second=$(systemctl show -p InvocationID --value "$unit")
[ -n "$second" ]; [ "$first" != "$second" ]
journalctl -u "$unit" --since '-2 minutes' --no-pager
printf 'REPOWERD_ACTIVATION_LIFECYCLE=PASS\nRuntime only; reboot removes this startup experiment.\n'
