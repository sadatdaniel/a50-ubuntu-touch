#!/bin/sh
# Bounded activation of Android 11's normal wake-lock-aware suspend loop.
set -eu
umask 077
P=/userdata/a50-session29-aa12
B="$P/auto-7"
test ! -e "$B"
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat "$P/expected-boot-id")"
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
grep -q '\[none\]' /sys/power/pm_test
test "$(head -c 55785472 /dev/disk/by-partlabel/boot | sha256sum | cut -d ' ' -f1)" = c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
systemctl is-active --quiet repowerd
systemctl is-active --quiet a50-kmsg-capture
test -f "$P/aa12-auto7-stop.sh"
mkdir "$B"
cat /proc/sys/kernel/random/boot_id > "$B/boot-id"
echo "a50-auto-test-hold 600000000000" > /sys/power/wake_lock
trap 'sh "$P/aa12-auto7-stop.sh"' EXIT HUP INT TERM
cat /sys/kernel/debug/suspend_stats > "$B/before.stats"
cat /sys/kernel/debug/wakeup_sources > "$B/before.wakeup-sources"
dmesg > "$B/before.dmesg"
# Wait for the user to unplug USB before activation; abort after three minutes.
systemctl stop a50-test-awake.service
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
# Require proof that the supported hook prepared Wi-Fi before allowing sleep.
waited=0
while [ "$(cat /run/a50-wifi-power-hooks/mode 2>/dev/null)" != 1 ]; do
    test "$waited" -lt 20 || exit 1
    test "$(cat /sys/class/power_supply/usb/online)" = 0 || exit 1
    sleep 1
    waited=$((waited + 1))
done
cat /sys/kernel/debug/wakeup_sources > "$B/disconnected.wakeup-sources"
# Use the established calendar-timer workaround for systemd issue #29245.
deadline=$(date -u -d '+90 seconds' '+%Y-%m-%d %H:%M:%S UTC')
printf '%s\n' "$deadline" > "$B/deadline"
systemd-run --unit=a50-oct02-auto7-stop --on-calendar="$deadline" --timer-property=AccuracySec=1s --timer-property=WakeSystem=yes /bin/sh "$P/aa12-auto7-stop.sh"
systemctl is-active --quiet a50-oct02-auto7-stop.timer
systemctl show a50-oct02-auto7-stop.timer -p WakeSystem -p NextElapseUSecRealtime -p AccuracyUSec > "$B/timer"
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
