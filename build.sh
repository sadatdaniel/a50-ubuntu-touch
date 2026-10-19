#!/bin/bash
set -xe

# The standard UBports community-port wrapper, with the build tools pinned:
# the upstream branch moves, and an unpinned clone makes two builds of the same
# commit differ. Move the pin deliberately, with a rebuild and boot test.
TOOLS_COMMIT=7dd99e0de224931a7af1ffcc8d41f3c4c51f5316
if [ ! -d build ]; then
    git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools build
    git -C build checkout --detach "$TOOLS_COMMIT"
fi
[ "$(git -C build rev-parse HEAD)" = "$TOOLS_COMMIT" ] || { echo "E: build/ is not at $TOOLS_COMMIT" >&2; exit 1; }
# The Samsung kernel Makefile turns PLATFORM_VERSION into -DANDROID_VERSION /
# -DANDROID_MAJOR_VERSION (used by Wi-Fi, camera ISP and sdcardfs code). The
# boot-tested build compiles with 120000 / 's', i.e. 12.0.0; without it the
# tools build gets the 990000 fallback (compile-command diff, 2026-10-20).
export PLATFORM_VERSION="${PLATFORM_VERSION:-12.0.0}"
./build/build.sh "$@"
