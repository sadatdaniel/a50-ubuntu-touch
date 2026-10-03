#!/bin/bash
# Rebuild the exact installed Lomiri revision with the original upstream transient-state correction.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=$(realpath "${1:?usage: $0 <empty build directory>}")
SOURCE_SHA=fcac00b977a96f050ebcde4fdbd78e77c2e9b26a
VERSION='0.6.2+0~20261001183057.508+ubports26.04.1~1.gbpfcac00+a50state.2'
[ "$(dpkg --print-architecture)" = arm64 ]
[ "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 26.04 ]
[ -z "$(ls -A "$BUILD_DIR")" ] || { echo 'E: build directory must be empty' >&2; exit 1; }
git init "$BUILD_DIR/lomiri"
cd "$BUILD_DIR/lomiri"
git remote add origin https://gitlab.com/ubports/development/core/lomiri.git
git fetch --depth 1 origin "$SOURCE_SHA"
git checkout --detach FETCH_HEAD
[ "$(git rev-parse HEAD)" = "$SOURCE_SHA" ]
# Match the existing 26.04 phone runtime instead of the runner's newer LightDM
# and rolling UBports headers. These preferences affect this disposable builder.
cat > "$BUILD_DIR/runtime.preferences" <<'PINS'
Package: src:lightdm:any
Pin: version 1.30.0-0ubuntu14ubports1+0~20260425115354.2+ubports26.04.1~1.gbp12d40d
Pin-Priority: 1001

Package: src:lomiri-indicator-network:any
Pin: version 1.99.0+0~20260930165218.255+ubports26.04.1~1.gbp489ef1
Pin-Priority: 1001

Package: src:lomiri-ui-toolkit:any
Pin: version 1.3.5908+0~20260930165252.351+ubports26.04.1~1.gbpc41976
Pin-Priority: 1001
PINS
sudo install -m 0644 "$BUILD_DIR/runtime.preferences" /etc/apt/preferences.d/a50-lomiri-build
sudo apt-get -y --no-install-recommends build-dep -Pnoinsttest .
sudo apt-get -y --no-install-recommends install nodejs
cp qml/Stage/WindowStateSaver.qml "$BUILD_DIR/WindowStateSaver.original.qml"
git apply --check "$HERE/scripts/experiments/lomiri-window-state-upstream.patch"
git apply "$HERE/scripts/experiments/lomiri-window-state-upstream.patch"
# The original source must reproduce the regression; the exact upstream
# correction must preserve usable states and repair transient save/load states.
if node "$HERE/scripts/experiments/check-window-state-saver.js" "$BUILD_DIR/WindowStateSaver.original.qml" > "$BUILD_DIR/baseline.txt" 2>&1; then
    echo 'E: window-state regression did not reproduce' >&2
    exit 1
fi
grep -q 'AssertionError' "$BUILD_DIR/baseline.txt"
node "$HERE/scripts/experiments/check-window-state-saver.js" qml/Stage/WindowStateSaver.qml
DEBFULLNAME='A50 port build' DEBEMAIL='noreply@example.invalid' \
    dch --newversion "$VERSION" --distribution UNRELEASED 'Backport upstream 598d550 transient window-state protection.'
DEB_BUILD_PROFILES=noinsttest DEB_BUILD_OPTIONS=nocheck \
    dpkg-buildpackage --build=binary --no-sign -j4
mkdir -p "$HERE/lomiri-test"
cp "$BUILD_DIR"/lomiri_*_arm64.deb "$BUILD_DIR"/lomiri-private_*_arm64.deb \
   "$BUILD_DIR"/lomiri-common_*_all.deb "$BUILD_DIR"/lomiri-greeter_*_all.deb \
   "$BUILD_DIR"/indicators-client_*_arm64.deb "$HERE/lomiri-test/"
printf 'Lomiri source: %s\nVersion: %s\nWindowStateSaver regression: passed\nFull upstream suite: not run\nPhone close/reopen: pending\n' \
    "$SOURCE_SHA" "$VERSION" > "$HERE/lomiri-test/build.txt"
dpkg-query -W > "$HERE/lomiri-test/build-dependencies.txt"
(cd "$HERE/lomiri-test"; sha256sum ./*.deb > SHA256SUMS)
printf 'Upstream correction: 598d550be9d8175e645ee5f0585421b7c9c412ca\nMR 331 remains unmerged; its later revision is not used.\n' >> "$HERE/lomiri-test/build.txt"
cp "$BUILD_DIR/runtime.preferences" "$HERE/lomiri-test/"
for package in "$HERE/lomiri-test"/*.deb; do
    dpkg-deb -f "$package" Package Version Architecture Depends
done > "$HERE/lomiri-test/runtime-dependencies.txt"
