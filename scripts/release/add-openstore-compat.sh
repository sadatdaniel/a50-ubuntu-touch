#!/bin/bash
# Co-install the pre-26.04 libxml2 and ICU SONAMEs into a mounted rootfs.
#
# WHY. Ubuntu 26.04 ships libxml2 2.15, which renamed the SONAME
# libxml2.so.2 -> libxml2.so.16. Every click built against the older framework
# links the old name, so the preinstalled OpenStore 4.1.0 - the newest there is
# - cannot start:
#
#   ./openstore: error while loading shared libraries: libxml2.so.2
#
# Morph is hit by the same thing. This is an Ubuntu-wide change, not an Ubuntu
# Touch one, and there is no newer click that fixes it.
#
# Differing SONAMEs are *designed* to coexist, so the fix is to install the
# genuine old libraries alongside the new ones - which was proven on the device
# before it was put in a build script (docs/device-provisioning.md). libxml2
# 2.9 links ICU 74, so that set comes too; the dependency only surfaces once
# libxml2.so.2 is in place.
#
# What NOT to do, both tried and reverted: symlinking a renamed library to the
# old name. libsnapd-qt.so.1 -> libsnapd-qt-2.so.1 links, starts, and then dies
# with "corrupted size vs. prev_size" - the ABI differs and it corrupts the
# heap. Co-installing the genuine old library is safe; aliasing a different one
# is not.
#
#   ./scripts/release/add-openstore-compat.sh /path/to/mounted/rootfs
set -euo pipefail

ROOT="${1:?usage: $0 <mounted rootfs>}"
[ -d "$ROOT/usr/lib/aarch64-linux-gnu" ] || { echo "E: $ROOT is not an arm64 rootfs" >&2; exit 1; }

# noble = 24.04 LTS, the last release with the 2.9 SONAME.
MIRROR="${UBUNTU_PORTS_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"
SUITE=noble
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch_pkg() {
    # $1 = binary package name. Resolved from the release's own Packages index
    # rather than pinned, so this does not rot the moment noble gets a security
    # update - and the exact filename ends up in the build log either way.
    local pkg="$1" path
    for comp in main universe; do
        path=$(curl -fsSL "$MIRROR/dists/$SUITE/$comp/binary-arm64/Packages.gz" \
               | gzip -dc \
               | awk -v p="$pkg" '
                   /^Package: /   { cur = $2 }
                   /^Filename: /  { if (cur == p) { print $2; exit } }') || true
        [ -n "$path" ] && break
    done
    [ -n "$path" ] || { echo "E: $pkg not found in $SUITE" >&2; return 1; }
    echo "I: $pkg -> $path" >&2
    curl -fsSL -o "$TMP/$pkg.deb" "$MIRROR/$path"
    ( cd "$TMP" && dpkg-deb -x "$pkg.deb" "unpacked-$pkg" )
    echo "$TMP/unpacked-$pkg"
}

L=usr/lib/aarch64-linux-gnu

x=$(fetch_pkg libxml2)
cp -a "$x/$L/"libxml2.so.2* "$ROOT/$L/"

i=$(fetch_pkg libicu74)
cp -a "$i/$L/"libicu*.so.74* "$ROOT/$L/"

echo "I: co-installed:"
ls -l "$ROOT/$L/"libxml2.so.2* "$ROOT/$L/"libicuuc.so.74* | sed 's/^/    /'

# ldconfig runs against the target rootfs, not the build host's.
if command -v ldconfig >/dev/null 2>&1; then
    ldconfig -r "$ROOT" 2>/dev/null || echo "W: ldconfig -r failed; it will run at boot"
fi
