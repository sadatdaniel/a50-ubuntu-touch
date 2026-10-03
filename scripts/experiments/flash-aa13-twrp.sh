#!/sbin/sh
set -eu
img=/tmp/boot-aa13.img
boot=/dev/block/by-name/boot
expected=8ae7ab85c08c13b0a7f454882dda3c52162a004a718de2be657d3cd75218fca6
file_sha256() { sha256sum "$1" | cut -d ' ' -f1; }
test "$(readlink -f "$boot")" = /dev/block/sda14
test "$(blockdev --getsize64 "$boot")" = 57671680
test "$(stat -c %s "$img")" = 55851008
test "$(file_sha256 "$img")" = "$expected"
test "$(head -c 55851008 "$boot" | sha256sum | cut -d ' ' -f1)" = 795e8b7fffda6b46e318d1bccc542b3a7d807987a7787f5115f0dcb27b7b9dcb
test -f /data/ubuntu.img
test ! -e /data/rootfs.img
if mountpoint -q /tmp/a50-root-check; then umount /tmp/a50-root-check; fi
if grep -q '/tmp/a50-root-' /proc/mounts; then
    echo 'Unexpected root image check mount remains' >&2
    exit 1
fi
dd if="$img" of="$boot" bs=1048576
sync
test "$(head -c 55851008 "$boot" | sha256sum | cut -d ' ' -f1)" = "$expected"
test "$(file_sha256 /dev/block/by-name/vendor)" = 48f5e9bfb9ef2dfd032ec7c92986ac1c8886abe7d658430b57ccacb5e3cffe3b
test "$(file_sha256 /dev/block/by-name/recovery)" = 8535a9d9193243412fcefc0e6f1ba585d60e1533e65069867444a49d0287e51f
echo 'aa13 boot readback verified; vendor and recovery hashes unchanged'
