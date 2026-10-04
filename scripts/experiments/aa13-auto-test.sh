#!/bin/sh
# Bounded activation of Android 11's normal wake-lock-aware suspend loop.
set -eu
umask 077
P=/userdata/a50-session30-aa13
U=a50-oct04-auto1-stop
case "${1:-}" in
    "") ;;
    --aa17) P=/userdata/a50-aa17-test; U=a50-aa17-auto-stop ;;
    *) exit 2 ;;
esac
B="$P/auto-1"
test ! -e "$B"
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
grep -q '\[none\]' /sys/power/pm_test
if [ "${1:-}" = --aa17 ]; then
    test "$(head -c 55984128 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = a413d2bc4a605489225a0b5d8e512965af83eea39b7abb6097dbc2f7420775c8
else
    test "$(head -c 55851008 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = 8ae7ab85c08c13b0a7f454882dda3c52162a004a718de2be657d3cd75218fca6
fi
systemctl is-active --quiet repowerd
systemctl is-active --quiet a50-kmsg-capture
test -f "$P/aa13-auto-stop.sh"
mkdir "$B"
cat /proc/sys/kernel/random/boot_id > "$B/boot-id"
echo "a50-auto-test-hold 600000000000" > /sys/power/wake_lock
trap 'sh "$P/aa13-auto-stop.sh" "${1:-}"' EXIT HUP INT TERM
cat /sys/kernel/debug/suspend_stats > "$B/before.stats"
cat /sys/kernel/debug/wakeup_sources > "$B/before.wakeup-sources"
dmesg > "$B/before.dmesg"
# Wait for the user to unplug USB before activation; abort after three minutes.
if systemctl is-active --quiet a50-test-awake.service; then
    systemctl stop a50-test-awake.service
fi
waited=0
while [ "$(cat /sys/class/power_supply/usb/online)" != 0 ]; do
    test "$waited" -lt 180 || exit 1
    sleep 1
    waited=$((waited + 1))
done
# Cable removal can wake the display; allow the normal lock-screen timeout.
waited=0
while [ "$(cat /sys/class/backlight/panel/brightness)" != 0 ]; do
    test "$waited" -lt 45 || exit 1
    test "$(cat /sys/class/power_supply/usb/online)" = 0 || exit 1
    sleep 1
    waited=$((waited + 1))
done
# The packaged helper has no experimental mode marker. Require the latest
# driver command to request sleep preparation; actual recovery is tested below.
waited=0
while [ "$(dmesg | awk '/slsi_ioctl: command: SETSUSPENDMODE/{mode=$NF} END{print mode}')" != 1 ]; do
    test "$waited" -lt 20 || exit 1
    test "$(cat /sys/class/power_supply/usb/online)" = 0 || exit 1
    sleep 1
    waited=$((waited + 1))
done
dmesg | grep 'SETSUSPENDMODE' | tail -10 > "$B/wifi-preparation"
cat /sys/kernel/debug/wakeup_sources > "$B/disconnected.wakeup-sources"
# Use the established calendar-timer workaround for systemd issue #29245.
deadline=$(date -u -d '+90 seconds' '+%Y-%m-%d %H:%M:%S UTC')
printf '%s\n' "$deadline" > "$B/deadline"
systemd-run --unit="$U" --on-calendar="$deadline" --timer-property=AccuracySec=1s --timer-property=WakeSystem=yes /bin/sh "$P/aa13-auto-stop.sh" "${1:-}"
systemctl is-active --quiet "$U.timer"
systemctl show "$U.timer" -p WakeSystem -p NextElapseUSecRealtime -p AccuracyUSec > "$B/timer"
grep -q '^WakeSystem=yes$' "$B/timer"
# Android 11 AIDL method 1 is enableAutosuspend(); method 3 would force sleep.
timeout 8 lxc-attach -n android -- /system/bin/service call suspend_control 1 > "$B/activation"
if ! grep -Eq '00000000[[:space:]]+00000001' "$B/activation"; then
    # Android 11 returns false when already started. Prove its worker exists
    # and is waiting on the held kernel wake lock; never accept false blindly.
    grep -Eq '00000000[[:space:]]+00000000' "$B/activation"
    init_pid=$(lxc-info -n android -pH)
    android_ns=$(readlink "/proc/$init_pid/ns/pid")
    : > "$B/existing-worker"
    for pid in $(pgrep -f '^/system/bin/hw/android.system.suspend@1.0-service$'); do
        [ "$(readlink "/proc/$pid/ns/pid")" = "$android_ns" ] || continue
        grep -H '^pm_get_wakeup_count$' /proc/"$pid"/task/*/wchan >> "$B/existing-worker" || true
    done
    test -s "$B/existing-worker"
fi
date -Is > "$B/started"
echo a50-auto-test-hold > /sys/power/wake_unlock
sleep 60
# EXIT re-acquires the hold; the independent timer also does so after 90 seconds.
