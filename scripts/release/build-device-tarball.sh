#!/bin/bash
# Build out/device_a50.tar.xz - the "device tarball" half of a UBports GSI port.
#
# Upstream normally produces this with halium-generic-adaptation-build-tools'
# build.sh, which also builds the kernel. This port cannot use that path for a
# release yet: the kernel the tools would build has never been boot-tested on
# this device, while a50-halium's has. See docs/kernel.md.
#
# So this script does exactly what build.sh does AFTER the kernel step, using a
# boot image that is already boot-verified:
#
#   partitions/boot.img   <- the boot-tested image (from a50-halium)
#   system/...            <- overlay/system/, i.e. the port's userspace
#   system/usr/lib/modules/...  <- kernel modules, if a module tree is given
#
# and packs it in the same layout build-tarball-mainline.sh does in "usrmerge"
# mode, which is the mode this port uses (see deviceinfo, Rootfs section).
#
#   ./scripts/release/build-device-tarball.sh --boot BOOT.IMG [--modules DIR] [--out DIR]
set -euo pipefail

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
BOOT=""; MODULES=""; OUT="$HERE/out"

while [ $# -gt 0 ]; do
    case "$1" in
        --boot)    BOOT="$2"; shift 2 ;;
        --dirty)   DIRTY=1; shift ;;
        --modules) MODULES="$2"; shift 2 ;;
        --out)     OUT="$2"; shift 2 ;;
        *) echo "E: unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -n "$BOOT" ] && [ -f "$BOOT" ] || { echo "E: --boot BOOT.IMG is required" >&2; exit 2; }

# shellcheck disable=SC1091
source "$HERE/deviceinfo"

# The boot partition is exactly this many bytes. dd does not fail on a larger
# image, it truncates it, and the device then does not boot - so refuse here.
BOOT_PARTITION_BYTES=57671680
size=$(stat -c%s "$BOOT")
if [ "$size" -gt "$BOOT_PARTITION_BYTES" ]; then
    echo "E: boot image is $size bytes, partition is $BOOT_PARTITION_BYTES" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/partitions" "$TMP/system" "$OUT"

cp "$BOOT" "$TMP/partitions/boot.img"

# The port's userspace. overlay/system mirrors the rootfs root, exactly as in
# the reference port (gitlab.com/uports/h10/oneplus-nord-n100).
#
# Taken from the committed tree, not the working tree, for two reasons. A
# release has to correspond to a commit; and a working tree checked out on
# Windows carries symlinks whose absolute targets git-for-windows rewrites
# ("/run/..." becomes "/c/run/..."), which would ship a broken /etc/resolv.conf.
# --dirty overrides this for local iteration.
SRC="$HERE/overlay/system"
if [ -z "${DIRTY:-}" ] && git -C "$HERE" rev-parse --verify HEAD >/dev/null 2>&1; then
    EXPORT="$TMP/export"
    mkdir -p "$EXPORT"
    git -C "$HERE" archive --format=tar HEAD overlay/system | tar -x -C "$EXPORT"
    SRC="$EXPORT/overlay/system"
    echo "I: overlay taken from commit $(git -C "$HERE" rev-parse --short HEAD)"
else
    echo "I: overlay taken from the WORKING TREE - not reproducible"
fi
cp -a "$SRC/." "$TMP/system/"

# usrmerge: /lib is a symlink to /usr/lib on focal and later, so modules and
# udev rules have to be installed under /usr/lib or they land in a directory
# that does not exist. Same fixup build-tarball-mainline.sh does.
if [ -d "$TMP/system/lib" ]; then
    mkdir -p "$TMP/system/usr"
    cp -a "$TMP/system/lib/." "$TMP/system/usr/lib/"
    rm -rf "$TMP/system/lib"
fi

if [ -n "$MODULES" ]; then
    [ -d "$MODULES" ] || { echo "E: --modules $MODULES is not a directory" >&2; exit 1; }
    mkdir -p "$TMP/system/usr/lib/modules"
    cp -a "$MODULES/." "$TMP/system/usr/lib/modules/"
    echo "I: modules: $(find "$TMP/system/usr/lib/modules" -name '*.ko' | wc -l) .ko"
fi

# Executable bits: git preserves them, but be explicit so a checkout made on a
# filesystem without them (Windows, a zip export) still produces a usable image.
find "$TMP/system/usr/local/bin" "$TMP/system/usr/libexec" -type f -print0 2>/dev/null \
    | xargs -0 -r chmod 0755
chmod 0644 "$TMP/system/var/lib/lxc/android/a50-mount-hooks.sh" 2>/dev/null || true

tar -cJf "$OUT/device_${deviceinfo_codename}.tar.xz" -C "$TMP" \
    --owner=root --group=root --numeric-owner \
    --sort=name --mtime="@${SOURCE_DATE_EPOCH:-0}" \
    partitions/ system/
echo "$(date +%Y%m%d)-$$" > "$OUT/device_${deviceinfo_codename}.tar.build"

echo "I: $OUT/device_${deviceinfo_codename}.tar.xz"
sha256sum "$OUT/device_${deviceinfo_codename}.tar.xz"
