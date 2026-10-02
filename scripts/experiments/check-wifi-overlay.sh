#!/bin/sh
set -eu
B=/userdata/a50-session29-aa12
[ "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/expected-boot-id")" ]
[ "$(cat /sys/class/power_supply/usb/online)" = 1 ]
[ "$(cat /sys/module/apparmor/parameters/enabled)" = Y ]
systemctl is-active --quiet a50-test-awake.service
[ "$(nmcli radio wifi)" = enabled ]
restore() { nmcli radio wifi on; timeout 8 python3 /usr/local/bin/a50-wifi-power.py 0; }
trap restore EXIT HUP INT TERM
ping_gateway() {
    gateway=$(ip -4 route show default dev swlan0 | awk 'NR==1 {print $3}')
    [ -n "$gateway" ]
    runuser -u phablet -- ping -I swlan0 -c 2 -W 3 "$gateway" >/dev/null
}
ping_gateway
printf 'BASELINE_GATEWAY=PASS\n'
nmcli radio wifi off
sleep 2
timeout 8 python3 /usr/local/bin/a50-wifi-power.py 1
timeout 8 python3 /usr/local/bin/a50-wifi-power.py 0
[ "$(nmcli radio wifi)" = disabled ]
printf 'DISABLED_WIFI_HOOKS=PASS\n'
nmcli radio wifi on
n=0
until ping_gateway 2>/dev/null; do
    n=$((n+1)); [ "$n" -lt 20 ] || exit 1
    sleep 2
done
timeout 8 python3 /usr/local/bin/a50-wifi-power.py 0
printf 'WIFI_RECONNECT_GATEWAY=PASS\n'
printf 'a50-integration-check 120000000000\n' > /sys/power/wake_lock
systemctl restart repowerd
systemctl restart a50-test-awake.service
systemctl is-active --quiet repowerd a50-test-awake.service
timeout 8 python3 /usr/local/bin/a50-wifi-power.py 0
ping_gateway
printf 'REPOWERD_RESTART_AND_GATEWAY=PASS\n'
printf 'a50-integration-check\n' > /sys/power/wake_unlock