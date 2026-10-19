#!/bin/bash
# Build the OTA rootfs component: the official UBports 26.04 rootfs plus exactly
# the A50 fixes the full image gets (finalize-rootfs.sh), repacked in the
# system-image layout (top-level system/) that system-image-upgrader unpacks.
# Usage (root, ARM64 execution or binfmt): build-ota-rootfs.sh ROOTFS_TAR ROOTFS_SHA256 BUNDLE OUT_DIR
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOTFS_TAR=$(realpath "${1:?usage: $0 ROOTFS_TAR ROOTFS_SHA256 BUNDLE OUT_DIR}")
ROOTFS_SHA256=${2:?}
BUNDLE=$(realpath "${3:?}")
OUT=$(realpath -m "${4:?}")
[ "$(id -u)" = 0 ] || { echo 'E: needs root' >&2; exit 1; }
echo "$ROOTFS_SHA256  $ROOTFS_TAR" | sha256sum -c -
mkdir -p "$OUT"
[ ! -e "$OUT/rootfs.tar.xz" ] || { echo "E: $OUT/rootfs.tar.xz exists" >&2; exit 1; }
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
tar --numeric-owner -xJf "$ROOTFS_TAR" -C "$STAGE"
[ -d "$STAGE/system/var/lib/dpkg" ] || { echo 'E: not a system-image rootfs (no system/)' >&2; exit 1; }
NO_COMPAT="${NO_COMPAT:-}" DEVEL="${DEVEL:-}" bash "$HERE/finalize-rootfs.sh" "$STAGE/system" "$BUNDLE"
XZ_OPT="-6 -T0" tar --numeric-owner -cJf "$OUT/rootfs.tar.xz.part" -C "$STAGE" system
mv "$OUT/rootfs.tar.xz.part" "$OUT/rootfs.tar.xz"
{
    echo "UBUNTU_ROOTFS=$(basename "$ROOTFS_TAR")"
    echo "UBUNTU_ROOTFS_SHA256=$ROOTFS_SHA256"
    echo "OTA_ROOTFS_SHA256=$(sha256sum "$OUT/rootfs.tar.xz" | cut -d ' ' -f1)"
    echo "VARIANT=$([ -n "${DEVEL:-}" ] && echo devel || echo release)"
} > "$OUT/ota-rootfs-source.txt"
cat "$OUT/ota-rootfs-source.txt"
