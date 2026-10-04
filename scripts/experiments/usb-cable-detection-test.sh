#!/bin/sh
# Test usb-moded's built-in cable detectors without always-connected mode.
set -eu
umask 077
P=/userdata/a50-usb-detection-20261004
U=a50-usb-detection-rollback
case "${1:-}" in
    "") ;;
    --android-tracking) P="$P/android-1"; U=a50-usb-android-rollback ;;
    --aa17) P=/userdata/a50-aa17-test/usb-1; U=a50-aa17-usb-rollback ;;
    --aa16) P=/userdata/a50-aa16-test/usb-1; U=a50-aa16-usb-rollback ;;
    *) exit 2 ;;
esac
E=/run/usb-moded/zz-a50-cable-test.conf
test "$(id -u)" = 0
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(cat /sys/class/power_supply/usb/online)" = 1
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
if [ "${1:-}" = --aa17 ]; then
    test "$(head -c 55984128 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = a413d2bc4a605489225a0b5d8e512965af83eea39b7abb6097dbc2f7420775c8
fi
if [ "${1:-}" = --aa16 ]; then
    test "$(head -c 55984128 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = 05a84a04cb162cb8ef0b193859cc8dbc1ad2c20d665f1b978de5e3c52a3531a5
fi
test ! -e "$E"
mode=$(gdbus call --system --dest com.meego.usb_moded --object-path /com/meego/usb_moded --method com.meego.usb_moded.get_config)
case "$mode" in
    "('charging_only_adb',)"|"('mtp_adb',)"|"('rndis_adb',)") ;;
    *) echo 'An existing developer mode is required' >&2; exit 1 ;;
esac
printf '%s\n' "$mode" > "$P/saved-mode"
if [ "${1:-}" = --android-tracking ]; then
    T=/etc/usb-moded/90-device-specific-config.ini
    test -f "$T"
    ! findmnt --mountpoint "$T" >/dev/null
    test ! -e "$P/android-tracking-mounted"
    cp -p "$T" "$P/original-device-config.ini"
    # This test requires the current placeholder configuration, not other settings.
    ! grep -q '^[[:space:]]*[^#;[:space:]]' "$T"
    printf '%s\n' '[udev]' 'android_tracking=1' > "$P/android-tracking.ini"
    sha256sum "$P/android-tracking.ini" | cut -d ' ' -f1 > "$P/expected-config-sha256"
fi
printf '%s\n' 'USB_MODED_ARGS="-D"' 'USB_MODED_HW_ADAPTATION_ARGS=""' > "$P/candidate-env"
sha256sum "$P/candidate-env" | cut -d ' ' -f1 > "$P/expected-env-sha256"
# Exclude deep sleep: this test isolates cable detection and daemon lifecycle.
echo 'a50-usb-detection-hold 660000000000' > /sys/power/wake_lock
deadline=$(date -u -d '+10 minutes' '+%Y-%m-%d %H:%M:%S UTC')
printf '%s\n' "$deadline" > "$P/rollback-deadline"
systemd-run --unit="$U" --on-calendar="$deadline" --timer-property=AccuracySec=1s --timer-property=WakeSystem=yes /bin/sh "$P/usb-cable-detection-rollback.sh" "${1:-}"
systemctl is-active --quiet "$U.timer"
trap '/bin/sh "$P/usb-cable-detection-rollback.sh" "${1:-}"' EXIT
if [ "${1:-}" = --android-tracking ]; then
    touch "$P/android-tracking-mounted"
    mount --bind "$P/android-tracking.ini" "$T"
fi
# These EnvironmentFiles are an existing packaged USB service interface.
# Disable rescue mode and -f; preserve the saved mode and authorization.
cp "$P/candidate-env" "$E"
date -Is > "$P/started"
systemctl restart usb-moded.service
systemctl is-active --quiet usb-moded.service
pid=$(systemctl show usb-moded -p MainPID --value)
tr '\0' ' ' < "/proc/$pid/cmdline" > "$P/candidate-cmdline"
trap - EXIT
