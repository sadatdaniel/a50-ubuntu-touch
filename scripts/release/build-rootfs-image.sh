#!/bin/bash
# Build out/rootfs.img - the flashable Ubuntu Touch rootfs for this device.
#
# This is upstream's prepare-fake-ota.sh + system-image-from-ota.sh collapsed
# into one script, with two deliberate deviations, both forced:
#
#   1. prepare-fake-ota.sh only knows the "focal" and "24.04-1.x" releases.
#      This port is on 26.04-1.x, so the rootfs comes from the published
#      system-image pool instead of a Jenkins artifact. That is the same
#      tarball the OTA server hands a real device, which is strictly better
#      provenance than "last successful CI build".
#
#   2. prepare-fake-ota.sh picks the Halium GSI from
#      $deviceinfo_bootimg_os_version. On this device that field is "12.0" -
#      the value the boot-verified image actually carries - while the Halium
#      base is 11. Selecting on $deviceinfo_halium_version instead is the
#      semantically correct read of the same intent.
#
# Everything else - the ext4 image, the unpack order, the android-rootfs.img
# rename, the version tarball - is upstream's, and deliberately so.
#
# Needs root and a loop device: run it inside the build container.
#
#   ./scripts/release/build-rootfs-image.sh --device-tarball out/device_a50.tar.xz \
#       [--size 4G] [--out out] [--cache dl]
set -euo pipefail

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
DEVICE_TARBALL=""; OUT="$HERE/out"; CACHE="$HERE/dl"; SIZE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --device-tarball) DEVICE_TARBALL="$2"; shift 2 ;;
        --out)   OUT="$2"; shift 2 ;;
        --cache) CACHE="$2"; shift 2 ;;
        --size)  SIZE="$2"; shift 2 ;;
        *) echo "E: unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$DEVICE_TARBALL" ] && [ -f "$DEVICE_TARBALL" ] || {
    echo "E: --device-tarball out/device_a50.tar.xz is required" >&2; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "E: needs root (loop mount)" >&2; exit 1; }

# shellcheck disable=SC1091
source "$HERE/deviceinfo"

SIZE="${SIZE:-${deviceinfo_system_partition_size:-3584M}}"
OTA_CHANNEL="${deviceinfo_ubuntu_touch_release}/${deviceinfo_arch/aarch64/arm64}/android9plus/daily"

mkdir -p "$OUT" "$CACHE"

# --- 1. the Ubuntu Touch rootfs --------------------------------------------
# Resolved from the live system-image index rather than pinned, so a rebuild
# picks up the current 26.04 image; the exact path used is recorded in the
# build manifest so any build can be reproduced later.
: "${ROOTFS_URL:=}"
if [ -z "$ROOTFS_URL" ]; then
    echo "I: resolving the newest ${OTA_CHANNEL} rootfs"
    # Any device in the channel serves the same device-independent rootfs; the
    # per-device tarball is what differs, and we supply our own.
    INDEX_DEVICE="${INDEX_DEVICE:-FP5}"
    idx="$CACHE/index-${INDEX_DEVICE}.json"
    curl -fsSL -o "$idx" \
        "https://system-image.ubports.com/${OTA_CHANNEL}/${INDEX_DEVICE}/index.json"
    rootfs_path=$(grep -o '/pool/rootfs-[0-9a-f]*\.tar\.xz' "$idx" | tail -1)
    [ -n "$rootfs_path" ] || { echo "E: no rootfs in $idx" >&2; exit 1; }
    ROOTFS_URL="https://system-image.ubports.com${rootfs_path}"
fi
ROOTFS_TAR="$CACHE/$(basename "$ROOTFS_URL")"
[ -f "$ROOTFS_TAR" ] || curl -fL --retry 3 -o "$ROOTFS_TAR" "$ROOTFS_URL"

# --- 2. the Halium GSI ------------------------------------------------------
GSI_JOB="https://ci.ubports.com/job/UBportsCommunityPortsJenkinsCI/job/ubports%252Fporting%252Fcommunity-ports%252Fjenkins-ci%252Fgeneric_arm64/job"
case "${deviceinfo_halium_version}" in
    9)  GSI_URL="$GSI_JOB/main/lastSuccessfulBuild/artifact/halium_halium_arm64.tar.xz" ;;
    10) GSI_URL="$GSI_JOB/halium-10.0/lastSuccessfulBuild/artifact/halium_halium_arm64.tar.xz" ;;
    11) GSI_URL="$GSI_JOB/halium-11.0/lastSuccessfulBuild/artifact/halium_halium_arm64.tar.xz" ;;
    *)  echo "E: unsupported deviceinfo_halium_version=${deviceinfo_halium_version}" >&2; exit 1 ;;
esac
GSI_TAR="$CACHE/halium_halium_arm64.tar.xz"
[ -f "$GSI_TAR" ] || curl -fL --retry 3 -o "$GSI_TAR" "$GSI_URL"

# --- 3. the version tarball -------------------------------------------------
VER="$CACHE/version"
rm -rf "$VER"; mkdir -p "$VER/system/etc/system-image/config.d"
cat > "$VER/system/etc/system-image/channel.ini" <<EOF
[service]
base: system-image.ubports.com
http_port: 80
https_port: 443
channel: $OTA_CHANNEL
device: ${deviceinfo_codename}
EOF
ln -sf ../client.ini "$VER/system/etc/system-image/config.d/00_default.ini"
ln -sf ../channel.ini "$VER/system/etc/system-image/config.d/01_channel.ini"
tar -cJf "$CACHE/version.tar.xz" --owner=root --group=root -C "$VER" system

# --- 4. the image -----------------------------------------------------------
IMG="$OUT/rootfs.img"
MNT="$(mktemp -d)"
cleanup() { mountpoint -q "$MNT" && umount "$MNT"; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

rm -f "$IMG"
truncate -s "$SIZE" "$IMG"
mkfs.ext4 -q -F -L ubuntu-touch \
    ${deviceinfo_rootfs_image_sector_size:+-b 4096} "$IMG"
mount -o loop "$IMG" "$MNT"

for t in "$ROOTFS_TAR" "$GSI_TAR" "$DEVICE_TARBALL" "$CACHE/version.tar.xz"; do
    echo "I: unpacking $(basename "$t")"
    # The tarballs are in system-image OTA layout: a top-level system/ holding
    # the rootfs root, plus (for the device tarball) partitions/.
    tar --numeric-owner -xJf "$t" -C "$MNT" --strip-components=0
    if [ -d "$MNT/system" ]; then
        cp -a "$MNT/system/." "$MNT/"
        rm -rf "$MNT/system"
    fi
    if [ -d "$MNT/partitions" ]; then
        cp -a "$MNT/partitions/." "$OUT/"
        rm -rf "$MNT/partitions"
    fi
done

# UBports CI still names the Halium GSI system.img; lxc-android-config looks
# for android-rootfs.img. Upstream's system-image-from-ota.sh does the same.
if [ -e "$MNT/var/lib/lxc/android/system.img" ]; then
    mv "$MNT/var/lib/lxc/android/system.img" "$MNT/var/lib/lxc/android/android-rootfs.img"
    echo "I: renamed system.img -> android-rootfs.img"
fi

# The halium initramfs loop-mounts this image read-write only if the marker is
# present; a UBports release image ships it, a hand-built one has to add it.
touch "$MNT/.writable_image"

sync
df -h "$MNT" | tail -1
cleanup
trap - EXIT

echo "I: $IMG"
ls -l "$IMG"
