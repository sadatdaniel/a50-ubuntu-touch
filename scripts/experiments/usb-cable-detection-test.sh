#!/bin/sh
# Test usb-moded's existing power-supply tracking without always-connected mode.
set -eu
umask 077
P=/userdata/a50-usb-detection-20261004
E=/run/usb-moded/zz-a50-cable-test.conf
test "$(id -u)" = 0
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(cat /sys/class/power_supply/usb/online)" = 1
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
test ! -e "$E"
mode=$(gdbus call --system --dest com.meego.usb_moded --object-path /com/meego/usb_moded --method com.meego.usb_moded.get_config)
test "$mode" = "('rndis_adb',)"
printf '%s\n' "$mode" > "$P/saved-mode"
# Exclude deep sleep: this test isolates cable detection and daemon lifecycle.
echo 'a50-usb-detection-hold 420000000000' > /sys/power/wake_lock
deadline=$(date -u -d '+6 minutes' '+%Y-%m-%d %H:%M:%S UTC')
printf '%s\n' "$deadline" > "$P/rollback-deadline"
systemd-run --unit=a50-usb-detection-rollback --on-calendar="$deadline" --timer-property=AccuracySec=1s --timer-property=WakeSystem=yes /bin/sh "$P/usb-cable-detection-rollback.sh"
systemctl is-active --quiet a50-usb-detection-rollback.timer
# These EnvironmentFiles are an existing packaged USB service interface.
# Disable rescue mode and -f; preserve the saved mode and authorization.
printf '%s\n' 'USB_MODED_ARGS="-D"' 'USB_MODED_HW_ADAPTATION_ARGS=""' > "$E"
sha256sum "$E" | cut -d ' ' -f1 > "$P/expected-env-sha256"
date -Is > "$P/started"
systemctl restart usb-moded.service
systemctl is-active --quiet usb-moded.service
pid=$(systemctl show usb-moded -p MainPID --value)
tr '\0' ' ' < "/proc/$pid/cmdline" > "$P/candidate-cmdline"
