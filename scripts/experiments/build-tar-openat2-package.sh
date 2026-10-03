#!/bin/bash
# Current 26.04 tar with its existing gnulib fallback for kernels without openat2.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=$(realpath "${1:?usage: $0 <empty build directory>}")
SOURCE_VERSION='1.35+dfsg-4ubuntu0.4'
[ "$(dpkg --print-architecture)" = arm64 ]
[ "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 26.04 ]
[ -z "$(ls -A "$BUILD_DIR")" ] || { echo 'E: build directory must be empty' >&2; exit 1; }
sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
sudo apt-get -o APT::Update::Error-Mode=any update
sudo apt-get -y --no-install-recommends build-dep "tar=$SOURCE_VERSION"
sudo apt-get -y --no-install-recommends install libseccomp-dev
cd "$BUILD_DIR"
apt-get source "tar=$SOURCE_VERSION"
cd tar-1.35+dfsg
DEBFULLNAME='A50 port build' DEBEMAIL='noreply@example.invalid' \
    dch --newversion "$SOURCE_VERSION+a50openat2.1" --distribution UNRELEASED 'Retain the existing gnulib runtime ENOSYS fallback on old kernels.'
ac_cv_func_openat2=no dpkg-buildpackage --build=binary --no-sign -j4
mkdir -p "$BUILD_DIR/test-fixed" "$BUILD_DIR/fixture/sub" "$BUILD_DIR/extracted"
dpkg-deb -x "$BUILD_DIR"/tar_*_arm64.deb "$BUILD_DIR/test-fixed"
cc -Wall -Wextra -Werror "$HERE/scripts/experiments/test-tar-openat2-fallback.c" -lseccomp -o "$BUILD_DIR/no-openat2"
printf 'nested archive test\n' > "$BUILD_DIR/fixture/sub/file"
if "$BUILD_DIR/no-openat2" /usr/bin/tar -cf "$BUILD_DIR/original.tar" -C "$BUILD_DIR/fixture" sub/file; then
    echo 'E: baseline no longer reproduces; review the official fix first' >&2; exit 1
fi
"$BUILD_DIR/no-openat2" "$BUILD_DIR/test-fixed/usr/bin/tar" -cf "$BUILD_DIR/fixed.tar" -C "$BUILD_DIR/fixture" sub/file
"$BUILD_DIR/no-openat2" "$BUILD_DIR/test-fixed/usr/bin/tar" -xf "$BUILD_DIR/fixed.tar" -C "$BUILD_DIR/extracted"
cmp "$BUILD_DIR/fixture/sub/file" "$BUILD_DIR/extracted/sub/file"
mkdir -p "$HERE/tar-test"
cp "$BUILD_DIR"/tar_*_arm64.deb "$HERE/tar-test/"
printf 'Ubuntu tar source: %s\nConfigure: ac_cv_func_openat2=no\nBlocked-openat2 create/extract: PASS\nHardware validation: pending\n' "$SOURCE_VERSION" > "$HERE/tar-test/build.txt"
dpkg-query -W > "$HERE/tar-test/build-dependencies.txt"
(cd "$HERE/tar-test"; sha256sum ./*.deb > SHA256SUMS)
