#!/bin/bash
# Experiment 001 - can UBports' mkbootimg reproduce this device's boot image?
# See docs/experiments/001-bootimg-header.md for the question and the result.
#
# Needs: python3, git, and a known-good A50 boot image. No device.
#
#   ./001-bootimg-header.sh /path/to/halium-boot-canonical.img
#
# Run it in a container if you like; nothing here writes outside its work dir.
set -euo pipefail

ORIG="$(realpath "${1:?usage: $0 <known-good-boot.img>}")"
WORK="${WORK:-$PWD/exp001}"
mkdir -p "$WORK"
cd "$WORK"

# From the header of halium-boot-canonical.img. If you point this at a
# different image, read its header first - these are not universal.
PAGE=2048
KSZ=41633808
RSZ=6533840

kpages=$(( (KSZ + PAGE - 1) / PAGE ))
koff=$PAGE
roff=$(( koff + kpages * PAGE ))

dd if="$ORIG" of=kernel.bin  bs=$PAGE skip=$((koff/PAGE)) count=$kpages status=none
truncate -s $KSZ kernel.bin
dd if="$ORIG" of=ramdisk.bin bs=$PAGE skip=$((roff/PAGE)) \
   count=$(( (RSZ + PAGE - 1) / PAGE )) status=none
truncate -s $RSZ ramdisk.bin

echo "I: kernel  $(sha256sum kernel.bin  | cut -d' ' -f1)"
echo "I: ramdisk $(sha256sum ramdisk.bin | cut -d' ' -f1)"

# The exact tool and branch halium-generic-adaptation-build-tools fetches.
[ -d mkbootimg ] || git clone -q --depth 1 -b lineage-20.0 \
    https://github.com/LineageOS/android_system_tools_mkbootimg mkbootimg

pack() {
    local out=$1; shift
    python3 mkbootimg/mkbootimg.py \
        --kernel kernel.bin --ramdisk ramdisk.bin \
        --cmdline 'androidboot.selinux=permissive loop.max_part=7' \
        --board 'SRPRL05B007KU' \
        --pagesize $PAGE \
        --os_version 12.0.0 --os_patch_level 2022-09 \
        --header_version 1 \
        "$@" -o "$out"
}

echo
echo "=== A: a50-droidian's offsets (vendor style, deliberately overflowing) ==="
rm -f out-overflow.img
if pack out-overflow.img --base 0x10000000 --kernel_offset 0x00008000 \
        --ramdisk_offset 0xf0000000 --second_offset 0xf0000000 \
        --tags_offset 0x00000100 2>err-a.txt; then
    echo "A: ACCEPTED - the inherited fact about overflow offsets is wrong, say so"
else
    echo "A: REJECTED, as documented:"
    sed 's/^/    /' err-a.txt | tail -3
    # A failed pack leaves a truncated file behind; do not let it be compared.
    rm -f out-overflow.img
fi

echo
echo "=== B: base=0, offsets absolute (what deviceinfo proposes) ==="
pack out-flat.img --base 0x00000000 --kernel_offset 0x10008000 \
     --ramdisk_offset 0x00000000 --second_offset 0x00000000 \
     --tags_offset 0x10000100
echo "B: built, $(stat -c%s out-flat.img) bytes"

# --- comparison ---------------------------------------------------------------
# Every conclusion below is gated on both files existing and being non-empty.
# An earlier version of this script compared two failed `dd` pipelines, found
# them equal, and printed IDENTICAL. A check that can pass while measuring
# nothing is worse than no check.
compare() {
    local a="$1" b="$2"
    for f in "$a" "$b"; do
        [ -s "$f" ] || { echo "E: $f is missing or empty - refusing to compare" >&2; exit 1; }
    done
    echo
    echo "=== $b vs $(basename "$a") ==="
    echo -n "header, magic..cmdline (0..575):     "
    cmp -n 576 "$a" "$b" >/dev/null 2>&1 && echo "identical" || echo "DIFFER"
    echo -n "id digest (576..607):                "
    cmp -i 576:576 -n 32 "$a" "$b" >/dev/null 2>&1 && echo "identical" || echo "differ"
    echo -n "extra_cmdline + payload (608..EOF):  "
    cmp -i 608:608 "$a" "$b" >/dev/null 2>&1 && echo "identical" || echo "DIFFER"
    echo    "sizes: $(stat -c%s "$a") vs $(stat -c%s "$b")"
}

compare "$ORIG" out-flat.img
[ -f out-overflow.img ] && compare "$ORIG" out-overflow.img

echo
echo "Done. Interpretation is in docs/experiments/001-bootimg-header.md."
