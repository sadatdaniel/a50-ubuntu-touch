#!/bin/bash
# Build the installed official sources plus the tested native launcher setting.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=$(realpath "${1:?usage: $0 <empty build directory>}")
SOURCE_SHA=5b7e2e71be3f6bfaaaab3b461251dacaf1ce4991
PACKAGING_SHA=7ebfea8f880a2d7c9c641070fe3cb273fa6c268d
VERSION='1.6.3-0ubports1~20260917185450.14~7ebfea8+ubports26.04.1+a50singleinstance.2+fdclose.1'
# Fixed changelog date: dpkg derives SOURCE_DATE_EPOCH from it, so rebuilds are byte-identical.
CHANGELOG_DATE='Sat, 17 Oct 2026 00:00:00 +0000'
[ "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 26.04 ]
[ -z "$(ls -A "$BUILD_DIR")" ] || { echo 'E: build directory must be empty' >&2; exit 1; }
fetch() {
    git init "$BUILD_DIR/$1"
    git -C "$BUILD_DIR/$1" remote add origin "$2"
    git -C "$BUILD_DIR/$1" fetch --depth 1 origin "$3"
    git -C "$BUILD_DIR/$1" checkout --detach FETCH_HEAD
    [ "$(git -C "$BUILD_DIR/$1" rev-parse HEAD)" = "$3" ]
}
fetch waydroid https://github.com/waydroid/waydroid.git "$SOURCE_SHA"
fetch packaging https://gitlab.com/ubports/development/core/packaging/waydroid.git "$PACKAGING_SHA"
mv "$BUILD_DIR/waydroid/debian" "$BUILD_DIR/upstream-debian"
cp -a "$BUILD_DIR/packaging/debian" "$BUILD_DIR/waydroid/"
cd "$BUILD_DIR/waydroid"
sudo apt-get -y --no-install-recommends build-dep .
dpkg-source --before-build .
echo 'cc0c23d6c7849a108ecbdf800129899993186f6cba9e0d0d2f4edad916ef595e  tools/services/user_manager.py' | sha256sum -c -
if python3 "$HERE/scripts/experiments/check-waydroid-single-instance.py" tools/services/user_manager.py; then
    echo 'E: original unexpectedly passes; recheck source.' >&2
    exit 1
fi
cp "$HERE/scripts/experiments/waydroid-lomiri-single-instance.patch" debian/patches/0013-lomiri-single-instance-launcher.patch
printf '%s\n' 0013-lomiri-single-instance-launcher.patch >> debian/patches/series
dpkg-source --before-build .
echo 'a888527e10171aecb7645bc9d8e9608a11310a7491fe0a1760e0909a1480ca65  tools/services/user_manager.py' | sha256sum -c -
python3 "$HERE/scripts/experiments/check-waydroid-single-instance.py" tools/services/user_manager.py
# Close foreground_pipe's selector and pipe (waydroid/waydroid#2357).
echo '763088cee01f392a824f1d24974ec444c770f88b8e4a68e19acb4ab04abf1bb0  tools/helpers/run_core.py' | sha256sum -c -
if python3 "$HERE/scripts/experiments/test-waydroid-foreground-pipe-fds.py" tools/helpers/run_core.py; then
    echo 'E: original unexpectedly passes the fd test; recheck source.' >&2
    exit 1
fi
cp "$HERE/scripts/experiments/waydroid-foreground-pipe-close.patch" debian/patches/0014-foreground-pipe-close-fds.patch
printf '%s\n' 0014-foreground-pipe-close-fds.patch >> debian/patches/series
dpkg-source --before-build .
echo 'f008879abfd29d766b782ce6fbf1b238efc904e4e39bf40b0d3ef712ab912662  tools/helpers/run_core.py' | sha256sum -c -
python3 "$HERE/scripts/experiments/test-waydroid-foreground-pipe-fds.py" tools/helpers/run_core.py
DEBFULLNAME='A50 port build' DEBEMAIL='noreply@example.invalid' \
    dch --force-bad-version --newversion "$VERSION" --distribution UNRELEASED 'Use native Lomiri single-instance identity for the shared Waydroid UI session; close foreground_pipe descriptors.'
sed -i "0,/^ -- /s/^\( -- .*>  \).*/\1$CHANGELOG_DATE/" debian/changelog
head -8 debian/changelog
dpkg-buildpackage --build=binary --no-sign -j4
mkdir -p "$HERE/waydroid-test"
cp "$BUILD_DIR"/waydroid_*_all.deb "$HERE/waydroid-test/"
printf 'Upstream source: %s\nUBports packaging: %s\nVersion: %s\nActual generator regression: passed\nPackaged reboot validation: pending\n' \
    "$SOURCE_SHA" "$PACKAGING_SHA" "$VERSION" > "$HERE/waydroid-test/build.txt"
dpkg-query -W > "$HERE/waydroid-test/build-dependencies.txt"
(cd "$HERE/waydroid-test"; sha256sum ./*.deb > SHA256SUMS)
