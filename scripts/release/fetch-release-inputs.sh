#!/bin/bash
# Restore archived build inputs from a GitHub release into dl/, so a fresh
# checkout can build without the expired upstream artifacts.
# Usage: fetch-release-inputs.sh [TAG]   (default inputs-20261017)
# Result: dl/halium_halium_arm64-<build>.tar.xz, dl/rootfs-*.tar.xz and
# dl/validated-packages/ holding exactly the archives named in the lock.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
TAG=${1:-inputs-20261017}
BASE="https://github.com/sadatdaniel/a50-ubuntu-touch/releases/download/$TAG"
DL="$HERE/dl"; STAGE="$DL/release-$TAG"
mkdir -p "$STAGE"
curl -fsSL --retry 3 -o "$STAGE/SHA256SUMS" "$BASE/SHA256SUMS"
while read -r _ name; do
    # GitHub stores '~' in asset names as '.'; keep the real (hashed) filename locally.
    [ -f "$STAGE/$name" ] || curl -fL --retry 3 -o "$STAGE/$name" "$BASE/${name//\~/.}"
done < "$STAGE/SHA256SUMS"
(cd "$STAGE" && sha256sum -c --quiet SHA256SUMS)

# Only the GSI build pinned in this checkout's gsi.lock, under the builder's cache name.
build=$(grep -E '^GSI_BUILD=' "$HERE/gsi.lock" | cut -d= -f2)
cp -n "$STAGE/halium_halium_arm64-$build.tar.xz" "$DL/"
cp -n "$STAGE"/rootfs-*.tar.xz "$DL/"
mkdir -p "$DL/validated-packages"
grep -v '^#' "$HERE/scripts/release/validated-packages.lock" | while IFS=$'\t' read -r n v a h _; do
    f="${n}_${v}_${a}.deb"
    echo "$h  $STAGE/$f" | sha256sum -c --quiet -
    cp "$STAGE/$f" "$DL/validated-packages/$f"
done
echo "I: restored $TAG: GSI $build, $(ls "$DL"/rootfs-*.tar.xz | wc -l) rootfs, $(ls "$DL/validated-packages" | wc -l) locked packages"
