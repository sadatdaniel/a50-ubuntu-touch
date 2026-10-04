#!/bin/sh
# Restore only this test's runtime EnvironmentFile; never edit normal config.
set -eu
P=/userdata/a50-usb-detection-20261004
E=/run/usb-moded/zz-a50-cable-test.conf
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
if [ -e "$E" ]; then
    test "$(sha256sum "$E" | cut -d ' ' -f1)" = "$(cat "$P/expected-env-sha256")"
    rm "$E"
    systemctl restart usb-moded.service
fi
printf '%s\n' a50-usb-detection-hold > /sys/power/wake_unlock
date -Is > "$P/rolled-back"
