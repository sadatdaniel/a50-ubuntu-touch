#!/bin/bash
# Run in a normal Halium 11 source tree after its standard hybris patches.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TREE="$(realpath "${1:?Halium source tree required}")"
OUT="$(realpath -m "${2:?Output directory required}")"
PATCH="$HERE/halium11-recording-audioflinger.patch"
cd "$TREE"
actual=$(git hash-object frameworks/av/media/libaudioclient/AudioSystem.cpp)
[ "$actual" = d84c49e22a93bef2b875d0066698c8a20673437e ] || {
    echo "E: source differs from GSI 1542 after its recording patch: $actual" >&2; exit 1;
}
git -C frameworks/av apply --check "$PATCH"
git -C frameworks/av apply "$PATCH"
[ "$(git hash-object frameworks/av/media/libaudioclient/AudioSystem.cpp)" = 3f3e99c2cb745b2928c5ec57f75af0f98bd39979 ]
export LC_ALL=C
unset USE_CCACHE
# Android envsetup predates nounset; use its conventional shell environment.
set +u
source build/envsetup.sh
lunch lineage_halium_arm64-userdebug
make -j"${BUILD_JOBS:-2}" libaudioclient
set -u
mkdir -p "$OUT/lib" "$OUT/lib64"
for arch in lib lib64; do
    source="out/target/product/halium_arm64/system/$arch/libaudioclient.so"
    test -s "$source"
    readelf -h "$source" > "$OUT/$arch/elf-header.txt"
    readelf -d "$source" > "$OUT/$arch/elf-dynamic.txt"
    cp "$source" "$OUT/$arch/libaudioclient.so"
done
grep -q 'Class:.*ELF32' "$OUT/lib/elf-header.txt"
grep -q 'Class:.*ELF64' "$OUT/lib64/elf-header.txt"
(cd "$OUT" && sha256sum lib/libaudioclient.so lib64/libaudioclient.so > SHA256SUMS)
repo manifest -r -o "$OUT/built-manifest.xml"
git -C frameworks/av diff > "$OUT/frameworks-av.patch"
echo 'Compiled both Android library architectures; phone validation still required.'
