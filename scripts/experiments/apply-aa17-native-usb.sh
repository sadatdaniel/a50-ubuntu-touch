#!/bin/sh
# Apply the exact tested configuration to this aa17 phone; image uses overlay.
set -eu
umask 077
P=/userdata/a50-aa17-test
C=/etc/default/usb-moded.d/device-specific-config.conf
N=/home/phablet/a50-native-usb.conf
test "$(id -u)" = 0
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(head -c 55984128 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = a413d2bc4a605489225a0b5d8e512965af83eea39b7abb6097dbc2f7420775c8
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
test "$(sha256sum "$N" | cut -d ' ' -f1)" = 3398022380878820739ac5eb80fa4fbf35e4e5f325550d1c9408fd6ddb6f4965
findmnt -no OPTIONS / | grep -q '^ro,'
test ! -e "$P/native-usb-applied"
if test ! -f "$P/original-usb-config.conf"; then cp -p "$C" "$P/original-usb-config.conf"; fi
cmp "$C" "$P/original-usb-config.conf"
trap 'mount -o remount,ro /' EXIT
mount -o remount,rw /
install -o root -g root -m 0644 "$N" "$C"
cmp "$N" "$C"
mount -o remount,ro /
trap - EXIT
findmnt -no OPTIONS / | grep -q '^ro,'
date -Is > "$P/native-usb-applied"
echo 'Native configuration installed; end runtime experiment and restart USB separately.'
