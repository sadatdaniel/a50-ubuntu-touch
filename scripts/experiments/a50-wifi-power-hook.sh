#!/bin/sh
# Experimental repowerd hook; prepare Wi-Fi before releasing its suspend lock.
set -eu
case "${1-}" in
    0|1) mode=$1 ;;
    *) exit 2 ;;
esac
# Disabled/missing Wi-Fi needs no firmware command. Do not enable the radio.
test -r /sys/class/net/swlan0/flags || exit 0
flags=$(cat /sys/class/net/swlan0/flags)
test "$((flags & 1))" -ne 0 || exit 0
timeout 8 python3 /userdata/a50-session29-aa12/a50-wifi-suspend-mode.py "$mode"
printf '%s\n' "$mode" > /run/a50-wifi-power-hooks/mode
logger -t a50-wifi-power-hook "Wi-Fi host mode=$mode accepted before power transition"
