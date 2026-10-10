#!/bin/sh
# Bounded activation of Android 11's normal wake-lock-aware suspend loop.
set -eu
umask 077
P=/userdata/a50-session30-aa13
U=a50-oct04-auto1-stop
case "${1:-}" in
    "") ;;
    --aa17) P=/userdata/a50-aa17-test; U=a50-aa17-auto-stop ;;
    --aa17-startup) P=/userdata/a50-aa17-startup-test; U=a50-aa17-startup-stop ;;
    *) exit 2 ;;
esac
test_seconds=${2:-90}
case "$test_seconds" in 90|1800) ;; *) exit 2 ;; esac
B="$P/auto-1"
test ! -e "$B"
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
grep -q '\[none\]' /sys/power/pm_test
if [ -n "${1:-}" ]; then
    test "$(head -c 55984128 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = a413d2bc4a605489225a0b5d8e512965af83eea39b7abb6097dbc2f7420775c8
else
    test "$(head -c 55851008 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = 8ae7ab85c08c13b0a7f454882dda3c52162a004a718de2be657d3cd75218fca6
fi
systemctl is-active --quiet repowerd
systemctl is-active --quiet a50-kmsg-capture
test -f "$P/aa13-auto-stop.sh"
mkdir "$B"
cat /proc/sys/kernel/random/boot_id > "$B/boot-id"
echo "a50-auto-test-hold 900000000000" > /sys/power/wake_lock
trap 'sh "$P/aa13-auto-stop.sh" "${1:-}"' EXIT HUP INT TERM
cat /sys/kernel/debug/suspend_stats > "$B/before.stats"
cat /sys/kernel/debug/wakeup_sources > "$B/before.wakeup-sources"
dmesg > "$B/before.dmesg"
phase() {
    printf '%s\n' "$1" > "$B/phase"
    printf 'A50 sleep test: %s at %s\n' "$1" "$(date -Is)"
}
# Allow ten minutes for physical preparation; sleep timing starts after unplug.
date -u -d '+600 seconds' '+%Y-%m-%d %H:%M:%S UTC' > "$B/preparation-deadline"
phase waiting-for-usb-removal
if systemctl is-active --quiet a50-test-awake.service; then
    systemctl stop a50-test-awake.service
fi
waited=0
while [ "$(cat /sys/class/power_supply/usb/online)" != 0 ]; do
    test "$waited" -lt 600 || { echo "USB preparation deadline expired"; exit 1; }
    sleep 1
    waited=$((waited + 1))
done
date -Is > "$B/usb-disconnected"
phase waiting-for-display-off
# Cable removal can wake the display; allow the normal lock-screen timeout.
waited=0
while [ "$(cat /sys/class/backlight/panel/brightness)" != 0 ]; do
    test "$waited" -lt 45 || exit 1
    test "$(cat /sys/class/power_supply/usb/online)" = 0 || exit 1
    sleep 1
    waited=$((waited + 1))
done
phase waiting-for-wifi-preparation
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
deadline=$(date -u -d "+$test_seconds seconds" '+%Y-%m-%d %H:%M:%S UTC')
printf '%s\n' "$deadline" > "$B/deadline"
systemd-run --unit="$U" --on-calendar="$deadline" --timer-property=AccuracySec=1s --timer-property=WakeSystem=yes /bin/sh "$P/aa13-auto-stop.sh" "${1:-}"
systemctl is-active --quiet "$U.timer"
systemctl show "$U.timer" -p WakeSystem -p NextElapseUSecRealtime -p AccuracyUSec > "$B/timer"
grep -q '^WakeSystem=yes$' "$B/timer"
# Android 11 AIDL method 1 is enableAutosuspend(); method 3 would force sleep.
if [ "${1:-}" = --aa17-startup ]; then
    # Observe normal boot activation; do not enable the worker from this test.
    systemctl is-active --quiet a50-enable-autosuspend.service
    test "$(systemctl show a50-enable-autosuspend.service -p Result --value)" = success
    systemctl show a50-enable-autosuspend.service -p ActiveState -p Result > "$B/activation"
else
    timeout 8 lxc-attach -n android -- /system/bin/service call suspend_control 1 > "$B/activation"
fi
if [ "${1:-}" = --aa17-startup ] || ! grep -Eq '00000000[[:space:]]+00000001' "$B/activation"; then
    # Android 11 returns false when already started. Prove its worker exists
    # and is waiting on the held kernel wake lock; never accept false blindly.
    if [ "${1:-}" != --aa17-startup ]; then
        grep -Eq '00000000[[:space:]]+00000000' "$B/activation"
    fi
    init_pid=$(lxc-info -n android -pH)
    android_ns=$(readlink "/proc/$init_pid/ns/pid")
    : > "$B/existing-worker"
    for pid in $(pgrep -f '^/system/bin/hw/android.system.suspend@1.0-service$'); do
        [ "$(readlink "/proc/$pid/ns/pid")" = "$android_ns" ] || continue
        grep -H '^pm_get_wakeup_count$' /proc/"$pid"/task/*/wchan >> "$B/existing-worker" || true
    done
    test -s "$B/existing-worker"
fi
phase sleep-observation-started
date -Is > "$B/started"
echo a50-auto-test-hold > /sys/power/wake_unlock
if [ "$test_seconds" = 90 ]; then
    sleep 60
else
    # A long soak must not end after only 60 seconds of accumulated awake time.
    # Ordinary sleeps do not arm a wake alarm; the independent calendar timer does.
    while [ ! -f "$B/stopped" ]; do sleep 10; done
fi
# EXIT re-acquires the hold; the independent timer also bounds the requested interval.
