#!/bin/sh
# Genuine cgroup-v1 OOM; never exhaust global RAM or alter production limits.
set -eu
umask 077
test "$(id -u)" = 0
test "$(cat /proc/sys/vm/panic_on_oom)" = 0
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
findmnt -no OPTIONS / | grep -q '^ro,'
awk '/MemAvailable:/ { exit !($2 > 524288) }' /proc/meminfo
stamp=$(date -u +%Y%m%dT%H%M%SZ)
base=/userdata/a50-oom-test/$stamp
runtime=/run/a50-oom-test-$stamp
unit=a50-oom-test-$stamp.service
mkdir -p "$base"
mkdir -m 0755 "$runtime"
kpid=
cleanup() {
    systemctl stop "$unit" 2>/dev/null || true
    systemctl reset-failed "$unit" 2>/dev/null || true
    if test -n "$kpid"; then kill "$kpid" 2>/dev/null || true; wait "$kpid" 2>/dev/null || true; fi
    rm -f -- "$runtime/go" "$runtime/allocate.py" "$runtime/supervise.sh"
    rmdir -- "$runtime"
}
trap cleanup EXIT
cp /proc/meminfo "$base/memory-before.txt"
cat /proc/sys/kernel/random/boot_id > "$base/boot-before.txt"
uid=$(id -u phablet)
user_state() {
    runuser -u phablet -- env XDG_RUNTIME_DIR=/run/user/$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
        systemctl --user show lomiri-full-greeter.service lomiri-app-launch--application-legacy--Waydroid--.service \
        -p Id -p MainPID -p InvocationID -p ActiveState -p NRestarts
    lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH -pH
}
user_state > "$base/processes-before.txt"
cat > "$runtime/allocate.py" <<'PY'
import os, sys, time
from pathlib import Path
print('WORKER_PID=' + str(os.getpid()), flush=True)
deadline = time.monotonic() + 30
while not Path(sys.argv[1]).exists():
    if time.monotonic() > deadline:
        sys.exit(4)
    time.sleep(0.05)
blocks = []
for _ in range(16):
    block = bytearray(8 * 1024 * 1024)
    block[::4096] = b'x' * (len(block) // 4096)
    blocks.append(block)
    time.sleep(0.02)
print('NO_OOM_WITHIN_128_MIB', flush=True)
sys.exit(2)
PY
cat > "$runtime/supervise.sh" <<'SH'
#!/bin/sh
python3 "$(dirname "$0")/allocate.py" "$(dirname "$0")/go"
result=$?
echo "WORKER_EXIT=$result"
# Retain the test cgroup briefly so its OOM counter can be inspected.
sleep 5
exit "$result"
SH
chmod 0644 "$runtime/allocate.py" "$runtime/supervise.sh"
python3 "$(dirname "$0")/capture-kmsg.py" --events-only --output "$base/kernel.log" &
kpid=$!
systemd-run --unit="$unit" --property=User=phablet --property=MemoryAccounting=yes \
    --property=MemoryMax=64M --property=OOMScoreAdjust=500 --property=OOMPolicy=continue \
    --property=Restart=no --property=RuntimeMaxSec=45 --property=TimeoutStopSec=5 \
    /bin/sh "$runtime/supervise.sh"
group=$(systemctl show "$unit" -p ControlGroup --value)
case "$group" in /system.slice/a50-oom-test-*.service) ;; *) exit 5 ;; esac
cg=/sys/fs/cgroup/memory$group
test "$(cat "$cg/memory.limit_in_bytes")" = 67108864
echo 67108864 > "$cg/memory.memsw.limit_in_bytes"
test "$(cat "$cg/memory.memsw.limit_in_bytes")" = 67108864
grep -q '^oom_kill_disable 0$' "$cg/memory.oom_control"
cat "$cg/memory.limit_in_bytes" "$cg/memory.memsw.limit_in_bytes" > "$base/limits.txt"
cat "$cg/memory.oom_control" > "$base/oom-before.txt"
touch "$runtime/go"
chmod 0644 "$runtime/go"
count=0
while systemctl is-active --quiet "$unit"; do
    test "$count" -lt 50 || exit 6
    if cat "$cg/memory.oom_control" > "$base/oom-current.tmp" 2>/dev/null; then
        mv "$base/oom-current.tmp" "$base/oom-after.txt"
    fi
    count=$((count + 1))
    sleep 1
done
systemctl show "$unit" -p Result -p ExecMainCode -p ExecMainStatus > "$base/unit-result.txt"
journalctl -u "$unit" --no-pager -o cat > "$base/worker.txt"
kill "$kpid"
wait "$kpid" 2>/dev/null || true
kpid=
worker=$(sed -n 's/^WORKER_PID=//p' "$base/worker.txt" | head -n 1)
test -n "$worker"
grep -q '^WORKER_EXIT=137$' "$base/worker.txt"
grep -q '^oom_kill 1$' "$base/oom-after.txt"
grep -q 'Memory cgroup out of memory' "$base/kernel.log"
grep -E "Killed process $worker " "$base/kernel.log" > "$base/verified-kill.txt"
python3 -c 'b=bytearray(8*1024*1024); b[::4096]=b"x"*2048; print("POST_OOM_ALLOCATION=PASS")' > "$base/recovery.txt"
cp /proc/meminfo "$base/memory-after.txt"
cat /proc/sys/kernel/random/boot_id > "$base/boot-after.txt"
user_state > "$base/processes-after.txt"
cmp "$base/boot-before.txt" "$base/boot-after.txt"
cmp "$base/processes-before.txt" "$base/processes-after.txt"
findmnt -no OPTIONS / | grep -q '^ro,'
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
cleanup
trap - EXIT
systemctl --failed --no-pager > "$base/failed-units.txt"
echo "ISOLATED_OOM_RECOVERY=PASS"
echo "Private evidence: $base"
