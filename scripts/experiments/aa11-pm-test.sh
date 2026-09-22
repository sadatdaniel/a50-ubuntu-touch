#!/bin/sh
# One explicitly selected test per invocation; never enters full deep sleep.
set -eu
umask 077
B=/userdata/a50-session20-aa11
level=${1:?Specify freezer or devices}
cycle=${2:?Specify cycle 1, 2 or 3}
case "$level" in freezer|devices) ;; *) exit 2 ;; esac
case "$cycle" in 1|2|3) ;; *) exit 2 ;; esac
D="$B/$level-$cycle"
test ! -e "$D"
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/expected-boot-id")"
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
test ! -e /sys/module/abox/parameters/freezer_skip_pm
test "$(readlink -f /dev/disk/by-partlabel/boot)" = /dev/sda14
test "$(head -c 55785472 /dev/sda14 | sha256sum | cut -d ' ' -f1)" = c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
test "$(cat /sys/kernel/config/usb_gadget/g1/UDC)" = 13200000.dwc3
test "$(cat /sys/class/udc/13200000.dwc3/state)" = configured
grep -q '\[none\]' /sys/power/pm_test
systemctl is-active --quiet a50-kmsg-capture.service
mkdir "$D"
cleanup() { echo none > /sys/power/pm_test; sync; }
trap cleanup EXIT HUP INT TERM
date -Is > "$D/started"
cat /proc/sys/kernel/random/boot_id > "$D/boot-id"
dmesg > "$D/before.dmesg"
ip -4 -brief address > "$D/before.addresses"
cat /sys/kernel/debug/suspend_stats > "$D/before.stats"
sync
printf '<5>A50 session20 aa11: USB-attached %s cycle %s begins\n' "$level" "$cycle" > /dev/kmsg
echo "$level" > /sys/power/pm_test
echo mem > /sys/power/state
cleanup
date -Is > "$D/returned"
cat /sys/kernel/debug/suspend_stats > "$D/after.stats"
ip -4 -brief address > "$D/after.addresses"
dmesg > "$D/after.dmesg"
sync
cat "$D/started" "$D/returned" /sys/power/pm_test
echo 'Cycle returned. Check USB re-enumeration and delayed stability separately.'
