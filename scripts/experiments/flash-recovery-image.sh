#!/bin/sh
# Write an image to the A50 recovery partition only, with hash guards.
# Usage (root): flash-recovery-image.sh IMAGE IMAGE_SHA256 CURRENT_RECOVERY_SHA256 CURRENT_BYTES
# The current recovery must hash to CURRENT_RECOVERY_SHA256 over its first
# CURRENT_BYTES (the whole partition for the TWRP dump), so rollback to TWRP is
# the same script with the TWRP image. Boot and vendor must stay unchanged.
set -eu
img=$1 want=$2 cur=$3 curbytes=$4
d=/dev/block/by-name
[ -e "$d/recovery" ] || d=/dev/disk/by-partlabel
rec=$d/recovery
sha() { sha256sum "$1" | cut -d ' ' -f1; }
part_sha() { head -c "$2" "$1" | sha256sum | cut -d ' ' -f1; }
test "$(blockdev --getsize64 "$rec")" = 67633152
size=$(stat -c %s "$img")
test "$size" -le 67633152
test "$(sha "$img")" = "$want"
test "$(part_sha "$rec" "$curbytes")" = "$cur" || { echo 'E: recovery partition is not the expected current image' >&2; exit 1; }
boot_before=$(sha "$d/boot"); vendor_before=$(sha "$d/vendor")
dd if="$img" of="$rec" bs=1048576 conv=fsync
sync
test "$(part_sha "$rec" "$size")" = "$want"
test "$(sha "$d/boot")" = "$boot_before"
test "$(sha "$d/vendor")" = "$vendor_before"
echo "recovery written and read back ($want); boot and vendor unchanged"
