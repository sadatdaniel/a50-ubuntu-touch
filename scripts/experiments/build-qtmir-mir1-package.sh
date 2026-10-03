#!/bin/bash
# Disposable Ubuntu 26.04 ARM64 build; the output is an experiment, not a release.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=$(realpath "${1:?usage: $0 <empty build directory>}")
SOURCE_SHA=38268ef19928ffebf9720b308a1a2bee7935716f
VERSION='0.7.2+0~20261001152353.82+ubports26.04.1~1.gbp38268e+a50mir1.1'
[ "$(dpkg --print-architecture)" = arm64 ]
[ "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 26.04 ]
[ -z "$(ls -A "$BUILD_DIR")" ] || { echo 'E: build directory must be empty' >&2; exit 1; }
git clone --depth 1 https://gitlab.com/ubports/development/core/qtmir.git "$BUILD_DIR/qtmir"
cd "$BUILD_DIR/qtmir"
[ "$(git rev-parse HEAD)" = "$SOURCE_SHA" ] || { echo 'E: upstream changed; review the new source first' >&2; exit 1; }
sudo apt-get -o APT::Update::Error-Mode=any update
sudo apt-get -y --no-install-recommends build-dep .
patch --dry-run -p1 < "$HERE/scripts/experiments/qtmir-mir1-physical-extents.patch"
patch -p1 < "$HERE/scripts/experiments/qtmir-mir1-physical-extents.patch"
DEBFULLNAME='A50 port build' DEBEMAIL='noreply@localhost' \
    dch --newversion "$VERSION" --distribution UNRELEASED 'Experimental Mir1 physical-extents DPR compatibility fix.'
# Hardware behavior is checked on the phone; CI cannot reproduce its Mali backend.
DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage --build=binary --no-sign -j4
mkdir -p "$HERE/qtmir-test"
cp "$BUILD_DIR"/libqt5mir1server1_*_arm64.deb "$BUILD_DIR"/qtmir-qt5-mir1_*_arm64.deb \
   "$BUILD_DIR"/qml-module-qtmir0.1_*_arm64.deb "$HERE/qtmir-test/"
printf 'QtMir source: %s\nVersion: %s\nHardware validation: pending\n' "$SOURCE_SHA" "$VERSION" > "$HERE/qtmir-test/build.txt"
dpkg-query -W > "$HERE/qtmir-test/build-dependencies.txt"
(cd "$HERE/qtmir-test"; sha256sum ./*.deb > SHA256SUMS)
