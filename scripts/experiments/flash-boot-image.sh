#!/bin/sh
# Write a boot image to the A50 boot partition only, with hash guards.
# Usage (as root, from Ubuntu Touch or TWRP's shell):
#   flash-boot-image.sh IMAGE IMAGE_SHA256 CURRENT_BOOT_SHA256 CURRENT_BOOT_BYTES
# The current boot partition must hash to CURRENT_BOOT_SHA256 over its first
# CURRENT_BOOT_BYTES, so a rollback is always "the same script, swapped".
# Vendor and recovery must be unchanged by the write (compared before/after,
# so it works whichever recovery is installed). Every failed check says why.
set -eu
img=$1 want=$2 cur=$3 curbytes=$4
# TWRP names partitions under /dev/block/by-name, Ubuntu Touch under by-partlabel.
d=/dev/block/by-name
[ -e "$d/boot" ] || d=/dev/disk/by-partlabel
boot=$d/boot
sha() { sha256sum "$1" | cut -d ' ' -f1; }
part_sha() { head -c "$2" "$1" | sha256sum | cut -d ' ' -f1; }
die() { echo "E: $*" >&2; exit 1; }
test "$(blockdev --getsize64 "$boot")" = 57671680 || die "boot partition size unexpected"
size=$(stat -c %s "$img")
test "$size" -le 57671680 || die "image larger than boot partition"
test "$(sha "$img")" = "$want" || die "image hash is not $want"
test "$(part_sha "$boot" "$curbytes")" = "$cur" || { echo 'E: boot partition is not the expected current image' >&2; exit 1; }
vendor_before=$(sha $d/vendor); recovery_before=$(sha $d/recovery)
dd if="$img" of="$boot" bs=1048576 conv=fsync
sync
test "$(part_sha "$boot" "$size")" = "$want" || die "readback mismatch after write"
test "$(sha $d/vendor)" = "$vendor_before" || die "vendor changed"
test "$(sha $d/recovery)" = "$recovery_before" || die "recovery changed"
echo "boot written and read back ($want); vendor and recovery unchanged"
