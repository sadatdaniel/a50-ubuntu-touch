#!/sbin/sh
# Restore the saved development installation, retaining the failed test state.
set -eu
test -n "$(getprop ro.twrp.version)"
test "$(readlink -f /dev/block/by-name/userdata)" = /dev/block/sda32
test "$(readlink -f /dev/block/by-name/boot)" = /dev/block/sda14
grep -q ' /data ' /proc/mounts
if awk '$2 ~ /^\/data\// {found=1} END {exit !found}' /proc/mounts; then
    echo 'Unexpected mounts below /data; inspect before continuing.' >&2
    exit 1
fi
backup=/data/a50-before-clean-20261002
failed=/data/a50-clean-test-failed-20261002
test -f "$backup/rootfs.img"
test ! -e "$failed"
sha256sum -c "$backup/boot-partition.sha256"
test "$(stat -c %s "$backup/boot-partition.img")" = 57671680
for name in rootfs.img user-data system-data android-data .force-adb .force-ssh; do
    test ! -L "/data/$name"
    test ! -L "$backup/$name"
done
mkdir "$failed"
for name in rootfs.img user-data system-data android-data .force-adb .force-ssh; do
    if [ -e "/data/$name" ]; then mv "/data/$name" "$failed/$name"; fi
    if [ -e "$backup/$name" ]; then mv "$backup/$name" "/data/$name"; fi
done
dd if="$backup/boot-partition.img" of=/dev/block/sda14 bs=1048576
sync
expected=$(sha256sum "$backup/boot-partition.img" | cut -d ' ' -f1)
actual=$(sha256sum /dev/block/sda14 | cut -d ' ' -f1)
test "$actual" = "$expected"
echo 'Previous image, state and boot restored. TWRP remains installed.'
