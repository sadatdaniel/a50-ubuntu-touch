#!/bin/bash
# Pack a recovery-flashable zip: one file that installs this port end to end.
#
# UBports' own GSI ports ship boot.img + ubuntu.img and tell you to run
# `fastboot flash`. That is not available here: this is a Samsung Exynos
# device, its bootloader is S-Boot, and it has no fastboot mode at all - the
# only way in is Odin (which takes signed Samsung tarballs, not raw images) or
# a custom recovery. TWRP exists and is well tested for the A50, so the
# flashable zip is this port's equivalent of the fastboot sequence, and it
# writes exactly what fastboot would: the boot partition and the rootfs.
#
#   ./scripts/release/make-installer-zip.sh --out DIR --version 2026-09-06
set -euo pipefail

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$HERE/out"; VERSION="$(date -u +%Y-%m-%d)"; MANIFEST=""; VARIANT="release"

while [ $# -gt 0 ]; do
    case "$1" in
        --out)      OUT="$2"; shift 2 ;;
        --version)  VERSION="$2"; shift 2 ;;
        --manifest) MANIFEST="$2"; shift 2 ;;
        --variant)  VARIANT="$2"; shift 2 ;;
        *) echo "E: unknown argument: $1" >&2; exit 2 ;;
    esac
done

# shellcheck disable=SC1091
source "$HERE/deviceinfo"

BOOT="$OUT/boot.img"
ROOTFS="$OUT/rootfs.img"
[ -f "$BOOT" ]   || { echo "E: $BOOT not found - run build-device-tarball.sh" >&2; exit 1; }
[ -f "$ROOTFS" ] || { echo "E: $ROOTFS not found - run build-rootfs-image.sh" >&2; exit 1; }

STAGE="$OUT/.zip"
rm -rf "$STAGE"
mkdir -p "$STAGE/install"
cp -a "$HERE/installer/META-INF" "$STAGE/"
cp -a "$HERE/installer/install/a50-install.sh" "$STAGE/install/"
cp "$BOOT" "$STAGE/install/boot.img"

echo "I: compressing the rootfs (this is the slow part)"
# pigz when it is available - the stream is ordinary gzip either way, and the
# phone-side "gzip -dc" cannot tell the difference, but this is a 6 GB file.
if command -v pigz >/dev/null 2>&1; then
    pigz -9 -c "$ROOTFS" > "$STAGE/install/rootfs.img.gz"
else
    gzip -9 -c "$ROOTFS" > "$STAGE/install/rootfs.img.gz"
fi

{
    echo "device=${deviceinfo_codename} (${deviceinfo_manufacturer} ${deviceinfo_name})"
    echo "release=${deviceinfo_ubuntu_touch_release}"
    echo "halium=${deviceinfo_halium_version}"
    echo "version=${VERSION}"
    echo "variant=${VARIANT}"
    echo "rootfs_bytes=$(stat -c%s "$ROOTFS")"
    echo "boot_bytes=$(stat -c%s "$BOOT")"
    [ -n "$MANIFEST" ] && [ -f "$MANIFEST" ] && sed 's/^/kernel_/' "$MANIFEST"
} > "$STAGE/install/manifest.txt"

# Hashes of the UNCOMPRESSED artifacts: what the installer verifies is what
# ends up on the partition, not what sat in the zip.
( cd "$OUT" && sha256sum boot.img rootfs.img ) > "$STAGE/install/SHA256SUMS"

SUFFIX=""
[ "$VARIANT" = release ] || SUFFIX="-$VARIANT"
ZIPNAME="ubuntu-touch-${deviceinfo_codename}-${deviceinfo_ubuntu_touch_release}${SUFFIX}-${VERSION}.zip"
rm -f "$OUT/$ZIPNAME"
# The rootfs payload is added with -0: it is already gzipped, and deflating it
# a second time would cost minutes on the build host and save nothing.
(
  cd "$STAGE"
  zip -q -r -9 "$OUT/$ZIPNAME" META-INF install/a50-install.sh \
                               install/manifest.txt install/SHA256SUMS install/boot.img
  zip -q -0    "$OUT/$ZIPNAME" install/rootfs.img.gz
)
rm -rf "$STAGE"

echo "I: $OUT/$ZIPNAME"
ls -l "$OUT/$ZIPNAME"
sha256sum "$OUT/$ZIPNAME"
