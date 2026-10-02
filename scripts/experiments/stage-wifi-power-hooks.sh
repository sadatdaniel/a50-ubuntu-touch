#!/bin/sh
# Runtime-only configuration: the bind mount disappears at reboot.
set -eu
P=/userdata/a50-session29-aa12
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
test "$(cat /sys/class/power_supply/usb/online)" = 1
test ! -e /run/a50-wifi-power-hooks
mkdir -m 700 /run/a50-wifi-power-hooks
cp /etc/deviceinfo/devices/a50.yaml /run/a50-wifi-power-hooks/original.yaml
cp /etc/deviceinfo/devices/a50.yaml /run/a50-wifi-power-hooks/a50.yaml
cat >> /run/a50-wifi-power-hooks/a50.yaml <<'EOF'
  RepowerdScriptPerfBoostLowPower: /bin/sh /userdata/a50-session29-aa12/a50-wifi-power-hook.sh 1
  RepowerdScriptPerfBoostSustained: /bin/sh /userdata/a50-session29-aa12/a50-wifi-power-hook.sh 0
  RepowerdScriptPerfBoostInteractive: /bin/sh /userdata/a50-session29-aa12/a50-wifi-power-hook.sh 0
EOF
echo 'a50-auto-test-hold 600000000000' > /sys/power/wake_lock
sh -n "$P/a50-wifi-power-hook.sh"
python3 "$P/a50-wifi-suspend-mode.py" 0
mount --bind /run/a50-wifi-power-hooks/a50.yaml /etc/deviceinfo/devices/a50.yaml
device-info get RepowerdScriptPerfBoostLowPower
systemctl restart repowerd
systemctl restart a50-test-awake.service
systemctl is-active repowerd a50-test-awake.service
