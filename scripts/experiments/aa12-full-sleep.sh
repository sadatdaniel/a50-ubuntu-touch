#!/bin/sh
set -eu
umask 077
B=/userdata/a50-session20-aa12
cycle=${1:-1}
case "$cycle" in 1|2|3) ;; *) exit 2 ;; esac
D="$B/deep-$cycle"
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
test "$(cat /sys/class/rtc/rtc0/device/power/wakeup)" = enabled
test -z "$(cat /sys/class/rtc/rtc0/wakealarm)"
grep -q '\[deep\]' /sys/power/mem_sleep
mkdir "$D"
armed=0
cleanup() {
 echo none > /sys/power/pm_test
 if test "$armed" = 1; then
  current=$(cat /sys/class/rtc/rtc0/wakealarm)
  if test -z "$current" || test "$current" = "$(cat "$D/alarm")"; then echo 0 > /sys/class/rtc/rtc0/wakealarm; fi
 fi
 sync
}
trap cleanup EXIT HUP INT TERM
dmesg > "$D/before.dmesg"
cat /sys/kernel/debug/suspend_stats > "$D/before.stats"
cat /proc/interrupts > "$D/before.interrupts"
date -Is > "$D/started"
echo +45 > /sys/class/rtc/rtc0/wakealarm
armed=1
cat /sys/class/rtc/rtc0/wakealarm > "$D/alarm"
sync
printf '<5>A50 session20 aa12: timed full deep sleep begins\n' > /dev/kmsg
rc=0
echo mem > /sys/power/state || rc=$?
date -Is > "$D/returned"
printf '%s\n' "$rc" > "$D/return-code"
cleanup
cat /sys/kernel/debug/suspend_stats > "$D/after.stats"
cat /proc/interrupts > "$D/after.interrupts"
dmesg > "$D/after.dmesg"
ip -4 -brief address > "$D/after.addresses"
sync
exit "$rc"