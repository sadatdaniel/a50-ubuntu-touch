#!/bin/sh
# One bounded, authenticated check. No persistent service or policy change.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run: sudo.ws sh check'; exit 1; }
umask 077
work=$(mktemp -d /tmp/a50-release-health.XXXXXX)
profile=a50-release-probe-$$
loaded=0
cleanup() {
    if [ "$loaded" = 1 ]; then apparmor_parser -R "$work/profile"; fi
    rm -rf "$work"
}
trap cleanup EXIT
exec 3>&1
exec >"$work/result" 2>&1
date -Is
uname -r
cat /sys/module/apparmor/parameters/enabled
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
printf 'allowed\n' > "$work/allowed"
printf 'forbidden\n' > "$work/denied"
cat > "$work/profile" <<EOF
#include <tunables/global>
profile $profile {
  #include <abstractions/base>
  /usr/bin/cat rix,
  $work/allowed r,
  deny $work/denied r,
}
EOF
apparmor_parser -a "$work/profile"
loaded=1
test "$(aa-exec -p "$profile" -- /usr/bin/cat "$work/allowed")" = allowed
if aa-exec -p "$profile" -- /usr/bin/cat "$work/denied" > "$work/denied-result" 2> "$work/denied-error"; then
    echo 'FAIL: forbidden read succeeded'; exit 1
fi
test ! -s "$work/denied-result"
grep -q 'Permission denied' "$work/denied-error"
echo APPARMOR_ALLOW_DENY=PASS
apparmor_parser -R "$work/profile"
loaded=0
echo 'Blocked kernel workers (comm, wait channel, stack):'
for process in /proc/[0-9]*; do
    pid=${process#/proc/}
    [ -r "/proc/$pid/comm" ] || continue
    case "$(cat "/proc/$pid/comm")" in
        tz_worker*|scsi_srpmb_work|ree_time|tz_iwsock|simpleinteracti*)
            printf 'PID %s ' "$pid"
            cat "/proc/$pid/comm"
            cat "/proc/$pid/wchan"
            cat "/proc/$pid/stack" || true ;;
    esac
done
echo 'Bluetooth protocol availability (no pairing or connection):'
python3 - <<'PY'
import socket
for name, kind, protocol in [('RFCOMM', socket.SOCK_STREAM, socket.BTPROTO_RFCOMM),
                             ('L2CAP', socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)]:
    try:
        with socket.socket(socket.AF_BLUETOOTH, kind, protocol):
            print(name, 'socket creation: PASS')
    except OSError as error:
        print(name, 'socket creation:', error.errno, error.strerror)
PY
systemctl --failed --no-pager
cat /sys/kernel/debug/suspend_stats || true
cat /sys/fs/cgroup/cpu,cpuacct/system.slice/rtkit-daemon.service/cpu.rt_runtime_us || true
install -o phablet -g phablet -m 0600 "$work/result" /home/phablet/a50-health.log
echo 'Health check complete; private log saved.' >&3
