#!/bin/sh
# Restore this test's runtime files and bind mount; never edit normal config.
set -eu
P=/userdata/a50-usb-detection-20261004
case "${1:-}" in
    "") ;;
    --android-tracking) P="$P/android-1" ;;
    --aa17) P=/userdata/a50-aa17-test/usb-1 ;;
    --aa16) P=/userdata/a50-aa16-test/usb-1 ;;
    *) exit 2 ;;
esac
E=/run/usb-moded/zz-a50-cable-test.conf
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
changed=0
if [ -e "$P/android-tracking-mounted" ]; then
    T=/etc/usb-moded/90-device-specific-config.ini
    if findmnt --mountpoint "$T" >/dev/null; then
        test "$(sha256sum "$T" | cut -d ' ' -f1)" = "$(cat "$P/expected-config-sha256")"
        umount "$T"
        changed=1
    fi
    cmp "$T" "$P/original-device-config.ini"
    rm "$P/android-tracking-mounted"
fi
if [ -e "$E" ]; then
    test "$(sha256sum "$E" | cut -d ' ' -f1)" = "$(cat "$P/expected-env-sha256")"
    rm "$E"
    changed=1
fi
if [ "$changed" = 1 ]; then systemctl restart usb-moded.service; fi
printf '%s\n' a50-usb-detection-hold > /sys/power/wake_unlock
date -Is > "$P/rolled-back"
