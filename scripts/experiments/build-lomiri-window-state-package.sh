#!/bin/bash
# Rebuild the exact installed Lomiri revision with shared hidden-state protection.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=$(realpath "${1:?usage: $0 <empty build directory>}")
SOURCE_SHA=fcac00b977a96f050ebcde4fdbd78e77c2e9b26a
VERSION='0.6.2+0~20261001183057.508+ubports26.04.1~1.gbpfcac00+a50state.1'
[ "$(dpkg --print-architecture)" = arm64 ]
[ "$(. /etc/os-release; printf '%s' "$VERSION_ID")" = 26.04 ]
[ -z "$(ls -A "$BUILD_DIR")" ] || { echo 'E: build directory must be empty' >&2; exit 1; }
git init "$BUILD_DIR/lomiri"
cd "$BUILD_DIR/lomiri"
git remote add origin https://gitlab.com/ubports/development/core/lomiri.git
git fetch --depth 1 origin "$SOURCE_SHA"
git checkout --detach FETCH_HEAD
[ "$(git rev-parse HEAD)" = "$SOURCE_SHA" ]
sudo apt-get -y --no-install-recommends build-dep -Pnoinsttest .
git apply --check "$HERE/scripts/experiments/lomiri-hidden-window-state.patch"
git apply "$HERE/scripts/experiments/lomiri-hidden-window-state.patch"
# Run the existing storage unit tests, including the real SQLite regression,
# without starting a compositor or running the full hardware-dependent suite.
mkdir "$BUILD_DIR/state-check"
cp plugins/Utils/windowstatestorage.{cpp,h} tests/plugins/Utils/WindowStateStorageTest.cpp "$BUILD_DIR/state-check/"
cat > "$BUILD_DIR/state-check/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.16)
project(WindowStateCheck LANGUAGES CXX)
set(CMAKE_AUTOMOC ON)
find_package(Qt5 REQUIRED COMPONENTS Core Gui Sql Test)
find_package(PkgConfig REQUIRED)
pkg_check_modules(APPLICATION_API REQUIRED IMPORTED_TARGET lomiri-shell-application=28)
pkg_check_modules(QTMIRSERVER REQUIRED IMPORTED_TARGET qt5mir1server)
add_executable(WindowStateStorageTestExec WindowStateStorageTest.cpp windowstatestorage.cpp)
target_compile_options(WindowStateStorageTestExec PRIVATE -include QtCore/QRect)
target_link_libraries(WindowStateStorageTestExec Qt5::Core Qt5::Gui Qt5::Sql Qt5::Test PkgConfig::APPLICATION_API PkgConfig::QTMIRSERVER)
CMAKE
# Demonstrate that the new regression fails against the unmodified storage code.
git show "$SOURCE_SHA:plugins/Utils/windowstatestorage.cpp" > "$BUILD_DIR/state-check/windowstatestorage.cpp"
cmake -S "$BUILD_DIR/state-check" -B "$BUILD_DIR/state-check/build"
cmake --build "$BUILD_DIR/state-check/build" -j4
if "$BUILD_DIR/state-check/build/WindowStateStorageTestExec" testHiddenStateDoesNotPreventReopening > "$BUILD_DIR/state-check/baseline.txt" 2>&1; then
    echo 'E: regression did not reproduce against the original code' >&2
    exit 1
fi
grep -q 'FAIL!.*testHiddenStateDoesNotPreventReopening' "$BUILD_DIR/state-check/baseline.txt"
cat "$BUILD_DIR/state-check/baseline.txt"
cp plugins/Utils/windowstatestorage.cpp "$BUILD_DIR/state-check/windowstatestorage.cpp"
cmake --build "$BUILD_DIR/state-check/build" -j4
"$BUILD_DIR/state-check/build/WindowStateStorageTestExec"
DEBFULLNAME='A50 port build' DEBEMAIL='noreply@example.invalid' \
    dch --newversion "$VERSION" --distribution UNRELEASED 'Do not persist or restore transient hidden window states.'
DEB_BUILD_PROFILES=noinsttest DEB_BUILD_OPTIONS=nocheck \
    dpkg-buildpackage --build=binary --no-sign -j4
mkdir -p "$HERE/lomiri-test"
cp "$BUILD_DIR"/lomiri_*_arm64.deb "$BUILD_DIR"/lomiri-private_*_arm64.deb \
   "$BUILD_DIR"/lomiri-common_*_all.deb "$BUILD_DIR"/lomiri-greeter_*_all.deb \
   "$BUILD_DIR"/indicators-client_*_arm64.deb "$HERE/lomiri-test/"
printf 'Lomiri source: %s\nVersion: %s\nWindowStateStorage tests: passed\nFull upstream suite: not run\nPhone close/reopen: pending\n' \
    "$SOURCE_SHA" "$VERSION" > "$HERE/lomiri-test/build.txt"
dpkg-query -W > "$HERE/lomiri-test/build-dependencies.txt"
(cd "$HERE/lomiri-test"; sha256sum ./*.deb > SHA256SUMS)
