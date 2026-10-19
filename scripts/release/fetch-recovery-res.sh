#!/bin/bash
# Fetch res-<density>/images from ubports/halium_bootable_recovery at a pinned
# commit, as the adaptation tools copy them for deviceinfo_unified_recovery_ui_density.
# Symlinks are resolved like `cp` does (font.png -> ../../fonts/18x32.png): a
# link's raw content is its target path, which broke the recovery font once.
# Usage: fetch-recovery-res.sh OUT_DIR   (verifies scripts/release/recovery-res-xxhdpi.sha256)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
COMMIT=9cdb4a9815b002acbb4a0c1ca292a9ffc0282ee3
DENSITY=xxhdpi
OUT=${1:?usage: $0 OUT_DIR}
RAW=https://raw.githubusercontent.com/ubports/halium_bootable_recovery/$COMMIT/res-$DENSITY/images
mkdir -p "$OUT"
while read -r _ name; do
    curl -fsSL -o "$OUT/$name" "$RAW/$name"
    if [ "$(head -c 4 "$OUT/$name" | od -An -tx1 | tr -d ' ')" != 89504e47 ]; then
        target=$(cat "$OUT/$name")
        curl -fsSL -o "$OUT/$name" "$RAW/$target"
    fi
done < "$HERE/recovery-res-$DENSITY.sha256"
(cd "$OUT" && sha256sum -c --quiet "$HERE/recovery-res-$DENSITY.sha256")
echo "I: res-$DENSITY images at $COMMIT verified in $OUT"
