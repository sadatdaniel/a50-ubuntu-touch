#!/bin/sh
set -eu
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y || exit 0
B=/userdata/a50-session20-aa12
partition=/dev/disk/by-partlabel/boot
fallback=/userdata/boot-aa1.img
expected=c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
candidate=795e8b7fffda6b46e318d1bccc542b3a7d807987a7787f5115f0dcb27b7b9dcb
test "$(readlink -f "$partition")" = /dev/sda14
test "$(blockdev --getsize64 "$partition")" = 57671680
test "$(stat -c %s "$fallback")" = 55785472
test "$(sha256sum "$fallback" | cut -d ' ' -f1)" = "$expected"
if test "$(head -c 55785472 "$partition" | sha256sum | cut -d ' ' -f1)" != "$expected"; then
    test "$(head -c 55851008 "$partition" | sha256sum | cut -d ' ' -f1)" = "$candidate"
    dd if="$fallback" of="$partition" bs=4M conv=fsync
fi
test "$(head -c 55785472 "$partition" | sha256sum | cut -d ' ' -f1)" = "$expected"
date -Is > "$B/boot-restored.txt"
cat /proc/sys/kernel/random/boot_id >> "$B/boot-restored.txt"
sync
