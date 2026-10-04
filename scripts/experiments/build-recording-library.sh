#!/bin/bash
# Run in a normal Halium 11 source tree after its standard hybris patches.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TREE="$(realpath "${1:?Halium source tree required}")"
readonly A50_RECORDING_ARTIFACT_DIR="$(realpath -m "${2:?Output directory required}")"
readonly A50_RECORDING_BUILD_MODE="${3:-libraries}"
case "$A50_RECORDING_BUILD_MODE" in libraries|full-image) ;; *) echo 'E: mode must be libraries or full-image' >&2; exit 2 ;; esac
PATCH="$HERE/halium11-camera-record-service.patch"
cd "$TREE"
actual=$(git hash-object frameworks/av/media/libaudioclient/AudioSystem.cpp)
[ "$actual" = d84c49e22a93bef2b875d0066698c8a20673437e ] || {
    echo "E: source differs from GSI 1542 after its recording patch: $actual" >&2; exit 1;
}
git -C frameworks/av apply --check "$PATCH"
git -C frameworks/av apply "$PATCH"
[ "$(git hash-object frameworks/av/media/libaudioclient/AudioSystem.cpp)" = 74a68fec469df1edccebfd58104045f5a3d0c10c ]
export LC_ALL=C
unset USE_CCACHE
# Android envsetup predates nounset; use its conventional shell environment.
set +u
source build/envsetup.sh
lunch lineage_halium_arm64-userdebug
if [ "$A50_RECORDING_BUILD_MODE" = full-image ]; then
    # Same generic Halium 11 targets as UBports' halium-build-tools/build.sh.
    make -j"${BUILD_JOBS:-2}" recoveryramdisk systemimage simg2img
else
    make -j"${BUILD_JOBS:-2}" libaudioclient
fi
set -u
mkdir -p "$A50_RECORDING_ARTIFACT_DIR/lib" "$A50_RECORDING_ARTIFACT_DIR/lib64"
for arch in lib lib64; do
    source="out/target/product/halium_arm64/system/$arch/libaudioclient.so"
    test -s "$source"
    readelf -h "$source" > "$A50_RECORDING_ARTIFACT_DIR/$arch/elf-header.txt"
    readelf -d "$source" > "$A50_RECORDING_ARTIFACT_DIR/$arch/elf-dynamic.txt"
    cp "$source" "$A50_RECORDING_ARTIFACT_DIR/$arch/libaudioclient.so"
done
grep -q 'Class:.*ELF32' "$A50_RECORDING_ARTIFACT_DIR/lib/elf-header.txt"
grep -q 'Class:.*ELF64' "$A50_RECORDING_ARTIFACT_DIR/lib64/elf-header.txt"
(cd "$A50_RECORDING_ARTIFACT_DIR" && sha256sum lib/libaudioclient.so lib64/libaudioclient.so > SHA256SUMS)
repo manifest -r -o "$A50_RECORDING_ARTIFACT_DIR/built-manifest.xml"
git -C frameworks/av diff > "$A50_RECORDING_ARTIFACT_DIR/frameworks-av.patch"
echo 'Built the pinned upstream correction; image integration/boot validation remains separate.'
