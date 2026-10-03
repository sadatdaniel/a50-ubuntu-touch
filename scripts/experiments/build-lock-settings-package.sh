#!/bin/bash
# Native ARM64 package build from the installed official Settings revision.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=$(realpath "${1:?usage: $0 <empty build directory>}")
SOURCE_SHA=d10c4792deb79e9c995bbb0b9eecd1226338a1ef
VERSION='1.4.0+0~20261001195229.487+ubports26.04.1~1.gbpd10c47+a50qtquick.1'
[ "$(dpkg --print-architecture)" = arm64 ]
[ "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 26.04 ]
[ -z "$(ls -A "$BUILD_DIR")" ] || { echo 'E: build directory must be empty' >&2; exit 1; }
git init "$BUILD_DIR/lomiri-system-settings"
cd "$BUILD_DIR/lomiri-system-settings"
git remote add origin https://gitlab.com/ubports/development/core/lomiri-system-settings.git
git fetch --depth 1 origin "$SOURCE_SHA"
git checkout --detach FETCH_HEAD
[ "$(git rev-parse HEAD)" = "$SOURCE_SHA" ]
sudo apt-get -y --no-install-recommends build-dep -Pnocheck .
sudo apt-get -y --no-install-recommends install qmlscene qml-module-qtquick2
git apply --check --unidiff-zero "$HERE/scripts/experiments/lock-security-qtquick-import.patch"
git apply --unidiff-zero "$HERE/scripts/experiments/lock-security-qtquick-import.patch"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 15 /usr/lib/qt5/bin/qmlscene "$HERE/scripts/experiments/check-lock-validator.qml"
DEBFULLNAME='A50 port build' DEBEMAIL='noreply@example.invalid' \
    dch --newversion "$VERSION" --distribution UNRELEASED 'Fix QtQuick import required by the lock-screen PIN validator.'
# The targeted Qt 5 reproducer runs above; full phone integration is checked on-device.
DEB_BUILD_PROFILES=nocheck DEB_BUILD_OPTIONS=nocheck \
    dpkg-buildpackage --build=binary --no-sign -j4
mkdir -p "$HERE/settings-test"
cp "$BUILD_DIR"/lomiri-system-settings_*_arm64.deb \
   "$BUILD_DIR"/liblomirisystemsettings1_*_arm64.deb \
   "$BUILD_DIR"/liblomirisystemsettingsprivate0.0_*_arm64.deb "$HERE/settings-test/"
printf 'Settings source: %s\nVersion: %s\nQtQuick validator reproducer: passed\nPackaged phone UI validation: pending\n' \
    "$SOURCE_SHA" "$VERSION" > "$HERE/settings-test/build.txt"
dpkg-query -W > "$HERE/settings-test/build-dependencies.txt"
(cd "$HERE/settings-test"; sha256sum ./*.deb > SHA256SUMS)
