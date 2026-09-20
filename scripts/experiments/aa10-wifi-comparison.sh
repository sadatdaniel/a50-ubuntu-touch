#!/bin/sh
set -eu
B=/userdata/a50-session20-aa10
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/expected-boot-id")"
test "$(nmcli radio wifi)" = enabled
test ! -e "$B/wifi-comparison-started"
date -Is > "$B/wifi-comparison-started"
restore() { nmcli radio wifi on; date -Is > "$B/wifi-restored"; }
trap restore EXIT HUP INT TERM
nmcli radio wifi off
sleep 5
sh "$B/aa10-full-sleep-wifi-off.sh"
