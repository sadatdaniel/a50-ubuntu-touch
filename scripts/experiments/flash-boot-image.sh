#!/bin/sh
# Write a boot image to the A50 boot partition only, with hash guards.
# Usage (as root, from Ubuntu Touch or TWRP's shell):
#   flash-boot-image.sh IMAGE IMAGE_SHA256 CURRENT_BOOT_SHA256 CURRENT_BOOT_BYTES
# The current boot partition must hash to CURRENT_BOOT_SHA256 over its first
# CURRENT_BOOT_BYTES, so a rollback is always "the same script, swapped".
# Vendor and recovery must be unchanged before and after.
set -eu
img=$1 want=$2 cur=$3 curbytes=$4
# TWRP names partitions under /dev/block/by-name, Ubuntu Touch under by-partlabel.
d=/dev/block/by-name
[ -e "$d/boot" ] || d=/dev/disk/by-partlabel
boot=$d/boot
VENDOR=48f5e9bfb9ef2dfd032ec7c92986ac1c8886abe7d658430b57ccacb5e3cffe3b
RECOVERY=8535a9d9193243412fcefc0e6f1ba585d60e1533e65069867444a49d0287e51f
sha() { sha256sum "$1" | cut -d ' ' -f1; }
part_sha() { head -c "$2" "$1" | sha256sum | cut -d ' ' -f1; }
check_others() {
    test "$(sha $d/vendor)" = "$VENDOR"
    test "$(sha $d/recovery)" = "$RECOVERY"
}
test "$(blockdev --getsize64 "$boot")" = 57671680
size=$(stat -c %s "$img")
test "$size" -le 57671680
test "$(sha "$img")" = "$want"
test "$(part_sha "$boot" "$curbytes")" = "$cur" || { echo 'E: boot partition is not the expected current image' >&2; exit 1; }
check_others
dd if="$img" of="$boot" bs=1048576 conv=fsync
sync
test "$(part_sha "$boot" "$size")" = "$want"
check_others
echo "boot written and read back ($want); vendor and recovery unchanged"
