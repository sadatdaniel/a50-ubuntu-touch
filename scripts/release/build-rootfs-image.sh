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
        --no-compat) NO_COMPAT=1; shift ;;
        --channel)   CHANNEL="$2"; shift 2 ;;
        --gsi-build) GSI_BUILD="$2"; shift 2 ;;
        --devel) DEVEL=1; shift ;;
        *) echo "E: unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$DEVICE_TARBALL" ] && [ -f "$DEVICE_TARBALL" ] || {
    echo "E: --device-tarball out/device_a50.tar.xz is required" >&2; exit 2; }
[ "$(id -u)" -eq 0 ] || { echo "E: needs root (loop mount)" >&2; exit 1; }

# shellcheck disable=SC1091
source "$HERE/deviceinfo"

SIZE="${SIZE:-${deviceinfo_system_partition_size:-3584M}}"

# Which upstream channel the rootfs comes from. 26.04-1.x currently publishes
# only `daily`, and it is flagged hidden in channels.json - there is no `rc` or
# `stable` for it yet. When one appears, this is the one string that changes:
#
#   ./build-rootfs-image.sh --channel stable ...
#   deviceinfo_ubuntu_touch_channel="stable"     # or set it in deviceinfo
#
# It is NOT enough on its own - docs/UPDATING.md lists what else to re-check
# when the rootfs underneath this port moves.
CHANNEL="${CHANNEL:-${deviceinfo_ubuntu_touch_channel:-daily}}"
OTA_CHANNEL="${deviceinfo_ubuntu_touch_release}/${deviceinfo_arch/aarch64/arm64}/android9plus/${CHANNEL}"

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

# --- 2. the Halium GSI, pinned ----------------------------------------------
# Read from gsi.lock, not from Jenkins' lastSuccessfulBuild, which moves daily.
# See that file for the measurements that made this necessary.
GSI_LOCK="$HERE/gsi.lock"
[ -r "$GSI_LOCK" ] || { echo "E: $GSI_LOCK not readable" >&2; exit 1; }
gsi_get() { grep -E "^$1=" "$GSI_LOCK" | head -1 | cut -d= -f2-; }

GSI_JOB="$(gsi_get GSI_JOB)"
GSI_BUILD="${GSI_BUILD:-$(gsi_get GSI_BUILD)}"
GSI_SHA256="$(gsi_get GSI_SHA256)"
[ -n "$GSI_JOB" ] && [ -n "$GSI_BUILD" ] || { echo "E: gsi.lock is incomplete" >&2; exit 1; }

if [ "$GSI_BUILD" = latest ]; then
    # Deliberate escape hatch: fetch the newest and report it, so the pin can
    # be moved on purpose. It is never moved automatically.
    GSI_BUILD=lastSuccessfulBuild
    GSI_SHA256=""
    echo "W: --gsi-build latest: the GSI is NOT pinned for this build" >&2
fi

GSI_URL="$GSI_JOB/$GSI_BUILD/artifact/halium_halium_arm64.tar.xz"
GSI_TAR="$CACHE/halium_halium_arm64-${GSI_BUILD}.tar.xz"
[ -f "$GSI_TAR" ] || curl -fL --retry 3 -o "$GSI_TAR" "$GSI_URL"

GSI_GOT="$(sha256sum "$GSI_TAR" | cut -d' ' -f1)"
if [ -n "$GSI_SHA256" ]; then
    if [ "$GSI_GOT" != "$GSI_SHA256" ]; then
        echo "E: the Halium GSI does not match the pin in gsi.lock." >&2
        echo "E:   build    $GSI_BUILD" >&2
        echo "E:   expected $GSI_SHA256" >&2
        echo "E:   got      $GSI_GOT" >&2
        echo "E: Jenkins rebuilds this artifact; a numbered build should not" >&2
        echo "E: change, so either the pin is wrong or the download is." >&2
        rm -f "$GSI_TAR"
        exit 1
    fi
    echo "I: GSI build $GSI_BUILD verified against gsi.lock ($(echo "$GSI_GOT" | cut -c1-16)…)"
else
    echo "I: GSI build $GSI_BUILD is $GSI_GOT"
    echo "I: put that in gsi.lock as GSI_SHA256 to pin it"
fi

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
# The image is mounted at $STAGE/system and the tarballs are unpacked from
# $STAGE, so their "system/..." members land in the image with no copy and no
# second copy of the data. That is upstream's trick in
# system-image-from-ota.sh, and it is the reason a 3.5 GB image can be built
# without 3.5 GB of scratch space. $STAGE therefore has to be on a filesystem
# with room for partitions/boot.img - not the container's overlayfs /tmp.
STAGE="$OUT/.stage"
rm -rf "$STAGE"; mkdir -p "$STAGE/system"
cleanup() { mountpoint -q "$STAGE/system" && umount "$STAGE/system"; }
trap cleanup EXIT

rm -f "$IMG"
truncate -s "$SIZE" "$IMG"
mkfs.ext4 -q -F -L ubuntu-touch \
    ${deviceinfo_rootfs_image_sector_size:+-b 4096} "$IMG"
mount -o loop "$IMG" "$STAGE/system"
MNT="$STAGE/system"

for t in "$ROOTFS_TAR" "$GSI_TAR" "$DEVICE_TARBALL" "$CACHE/version.tar.xz"; do
    echo "I: unpacking $(basename "$t")"
    # system-image OTA layout: a top-level system/ holding the rootfs root,
    # plus, for a device tarball, partitions/.
    tar --numeric-owner -xJf "$t" -C "$STAGE"
    df -h --output=avail "$MNT" | tail -1
done

if [ -d "$STAGE/partitions" ]; then
    cp -a "$STAGE/partitions/." "$OUT/"
    rm -rf "$STAGE/partitions"
fi

# UBports CI still names the Halium GSI system.img; lxc-android-config looks
# for android-rootfs.img. Upstream's system-image-from-ota.sh does the same.
if [ -e "$MNT/var/lib/lxc/android/system.img" ]; then
    mv "$MNT/var/lib/lxc/android/system.img" "$MNT/var/lib/lxc/android/android-rootfs.img"
    echo "I: renamed system.img -> android-rootfs.img"
fi

# The halium initramfs loop-mounts this image read-write only if the marker is
# present; a UBports release image ships it, a hand-built one has to add it.
touch "$MNT/.writable_image"

# Ubuntu 26.04 renamed libxml2's SONAME, which stops the preinstalled OpenStore
# and Morph from starting at all. Co-install the old one. --no-compat skips it.
if [ -z "${NO_COMPAT:-}" ]; then
    "$HERE/scripts/release/add-openstore-compat.sh" "$MNT" \
        || echo "W: OpenStore SONAME compat failed - OpenStore will not start"
fi

# --devel turns this into a debug image: sshd on, root password set, adb
# unlocked, USB networking up. Kept out of the release image on purpose.
if [ -n "${DEVEL:-}" ]; then
    "$HERE/scripts/release/add-devel-access.sh" "$MNT"
else
    printf 'variant=release\nssh=off\n' > "$MNT/etc/a50-image-variant"
fi

sync
df -h "$MNT" | tail -1
cleanup
rm -rf "$STAGE"
trap - EXIT

echo "I: $IMG"
ls -l "$IMG"
