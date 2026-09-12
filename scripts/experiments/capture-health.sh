#!/bin/sh
# Optional development diagnostic; never installed in the production overlay.
# Keep at most 48 half-hour slots on userdata. Logs may contain private data.
set -eu
umask 077
dir=/userdata/a50-health
mkdir -p "$dir"
chmod 0700 "$dir"
slot=$(( $(date +%s) / 1800 % 48 ))
tmp="$dir/sample.tmp"
trap 'rm -f "$tmp"' EXIT
{
    date -Is
    cat /proc/sys/kernel/random/boot_id
    uptime
    free -m
    cat /sys/kernel/debug/suspend_stats 2>/dev/null || true
    systemctl --failed --no-pager || true
    ps -eo pid,stat,pcpu,pmem,wchan:32,comm --sort=-pcpu | head -30
    journalctl -b --since=-30min -p warning --no-pager -n 200 || true
    dmesg | tail -200
} > "$tmp" 2>&1
mv "$tmp" "$dir/sample-$slot.log"
