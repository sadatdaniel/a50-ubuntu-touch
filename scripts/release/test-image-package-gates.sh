#!/bin/bash
# Tiny real ZIP build: no loop mounts, downloads, phone access or image flashing.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/repo/scripts/release" "$TMP/out"
cp "$HERE/deviceinfo" "$TMP/repo/"
cp -a "$HERE/installer" "$TMP/repo/"
cp "$HERE/scripts/release/"{build-rootfs-image.sh,make-installer-zip.sh,verify-package-bundle.py,validated-packages.lock} "$TMP/repo/scripts/release/"
touch "$TMP/device.tar.xz"
if bash "$TMP/repo/scripts/release/build-rootfs-image.sh" --device-tarball "$TMP/device.tar.xz" --out "$TMP/out" > "$TMP/missing.log" 2>&1; then
    echo 'E: builder accepted missing package bundle' >&2; exit 1
fi
grep -q -- '--package-bundle DIR is required' "$TMP/missing.log"
printf boot > "$TMP/out/boot.img"
printf rootfs > "$TMP/out/rootfs.img"
if bash "$TMP/repo/scripts/release/make-installer-zip.sh" --out "$TMP/out" > "$TMP/partial.log" 2>&1; then
    echo 'E: ZIP builder accepted unfinished image' >&2; exit 1
fi
grep -q 'integrated build stamp missing' "$TMP/partial.log"
cp "$HERE/scripts/release/validated-packages.lock" "$TMP/out/validated-packages.txt"
printf 'UBUNTU_ROOTFS_URL=https://example.invalid/CaseSensitive\n' > "$TMP/out/rootfs-source.txt"
printf 'GSI_BUILD=test-Candidate\nGSI_SHA256=actual-test-input\nGSI_ANDROID_ROOTFS_SHA256=actual-test-system\n' > "$TMP/out/gsi-source.txt"
stamp() {
    (cd "$TMP/out"; sha256sum rootfs.img boot.img validated-packages.txt rootfs-source.txt gsi-source.txt) > "$TMP/out/rootfs-inputs.sha256"
}
stamp
bash "$TMP/repo/scripts/release/make-installer-zip.sh" --out "$TMP/out" --version regression > "$TMP/zip.log" 2>&1 || { cat "$TMP/zip.log"; exit 1; }
zipfile=$(find "$TMP/out" -name '*.zip')
test -n "$zipfile"
unzip -p "$zipfile" install/manifest.txt | grep -q '^gsi_build=test-Candidate$'
unzip -p "$zipfile" install/manifest.txt | grep -q '^ubuntu_rootfs_url=https://example.invalid/CaseSensitive$'
unzip -p "$zipfile" install/SHA256SUMS | grep -q 'actual-test-input'
unzip -p "$zipfile" install/validated-packages.lock | cmp - "$TMP/out/validated-packages.txt"
printf corrupt >> "$TMP/out/rootfs.img"
if bash "$TMP/repo/scripts/release/make-installer-zip.sh" --out "$TMP/out" > "$TMP/stale.log" 2>&1; then
    echo 'E: ZIP builder accepted changed image' >&2; exit 1
fi
stamp
printf '# stale cohort\n' >> "$TMP/out/validated-packages.txt"
stamp
if bash "$TMP/repo/scripts/release/make-installer-zip.sh" --out "$TMP/out" > "$TMP/cohort.log" 2>&1; then
    echo 'E: ZIP builder accepted old cohort' >&2; exit 1
fi
echo 'PASS: required bundle, partial/changed image rejection, cohort identity, actual candidate GSI provenance and default ZIP packaging'
