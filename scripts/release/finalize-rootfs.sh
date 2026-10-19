#!/bin/bash
# The rootfs changes every A50 build makes on top of the official UBports rootfs,
# shared by the full image (build-rootfs-image.sh) and the OTA rootfs tarball
# (build-ota-rootfs.sh) so both carry exactly the same validated fixes.
# Usage: finalize-rootfs.sh OFFLINE_ROOT PACKAGE_BUNDLE   (env: NO_COMPAT, DEVEL)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=${1:?usage: $0 OFFLINE_ROOT PACKAGE_BUNDLE}
BUNDLE=${2:?usage: $0 OFFLINE_ROOT PACKAGE_BUNDLE}

# Native, versioned fixes; dependency/maintainer-script failures abort.
bash "$HERE/install-validated-packages.sh" "$ROOT" "$BUNDLE"

# Ubuntu 26.04 renamed libxml2's SONAME, which stops the preinstalled OpenStore
# and Morph from starting at all. Co-install the old one. NO_COMPAT skips it.
if [ -z "${NO_COMPAT:-}" ]; then
    "$HERE/add-openstore-compat.sh" "$ROOT"
fi

# Upstream's cgroup probe contains an NBSP before `true`, making the
# intended fallback abort on kernels without nested schedtune groups.
python3 "$HERE/fix-partition-probe.py" "$ROOT"

# Kernel 4.14 needs the installed polkit helper in its supported legacy mode.
bash "$HERE/configure-polkit-legacy.sh" "$ROOT"

# DEVEL turns this into a debug build: sshd on, root password set, adb
# unlocked, USB networking up. Kept out of release builds on purpose.
if [ -n "${DEVEL:-}" ]; then
    touch "$ROOT/.writable_image"
    "$HERE/add-devel-access.sh" "$ROOT"
else
    rm -f "$ROOT/.writable_image"
    printf 'variant=release\nssh=off\n' > "$ROOT/etc/a50-image-variant"
fi
