#!/bin/sh
set -eu
B=/userdata/a50-session20-aa10
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$B/expected-boot-id")"
test "$(nmcli radio wifi)" = enabled
test ! -e "$B/wifi-mode-started"
date -Is > "$B/wifi-mode-started"
restore() { python3 "$B/a50-wifi-suspend-mode.py" 0; date -Is > "$B/wifi-mode-restored"; }
trap restore EXIT HUP INT TERM
python3 "$B/a50-wifi-suspend-mode.py" 1
sleep 3
sh "$B/aa10-full-sleep-wifi-mode.sh"
