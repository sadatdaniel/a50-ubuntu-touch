#!/sbin/sh
# Run only in TWRP after the installer ZIP has been transferred and verified.
# Move the development installation aside, preserving an immediate rollback.
set -eu
test -n "$(getprop ro.twrp.version)"
test "$(readlink -f /dev/block/by-name/userdata)" = /dev/block/sda32
test "$(readlink -f /dev/block/by-name/boot)" = /dev/block/sda14
test "$(blockdev --getsize64 /dev/block/sda14)" = 57671680
grep -q ' /data ' /proc/mounts
# Do not move directories which still contain live bind/loop mounts.
if awk '$2 ~ /^\/data\// {found=1} END {exit !found}' /proc/mounts; then
    echo 'Unexpected mounts below /data; inspect before continuing.' >&2
    exit 1
fi
test -f /data/rootfs.img
backup=/data/a50-before-clean-20261002
test ! -e "$backup"
for name in rootfs.img user-data system-data android-data .force-adb .force-ssh; do
    test ! -L "/data/$name"
done
mkdir "$backup"
dd if=/dev/block/sda14 of="$backup/boot-partition.img" bs=1048576
test "$(stat -c %s "$backup/boot-partition.img")" = 57671680
sha256sum "$backup/boot-partition.img" > "$backup/boot-partition.sha256"
for name in rootfs.img user-data system-data android-data .force-adb .force-ssh; do
    path="/data/$name"
    if [ -e "$path" ]; then
        mv "$path" "$backup/$name"
        printf '%s\n' "$name" >> "$backup/moved-paths.txt"
    fi
done
sync
echo 'Previous installation preserved. Ready for the verified clean-test ZIP.'
