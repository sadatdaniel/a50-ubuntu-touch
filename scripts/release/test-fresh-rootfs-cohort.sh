#!/bin/bash
# Install the locked cohort into a FRESH official 26.04 rootfs using the exact
# image-builder step (install-validated-packages.sh), inside a disposable,
# network-disabled container. No image, GSI, boot or phone is involved.
# Usage: test-fresh-rootfs-cohort.sh ROOTFS_TAR BUNDLE_DIR EVIDENCE_DIR
# Needs Docker with an arm64 binfmt interpreter (Docker Desktop provides one).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/../.." && pwd)
ROOTFS_TAR=$(realpath "${1:?usage: $0 ROOTFS_TAR BUNDLE_DIR EVIDENCE_DIR}")
BUNDLE=$(realpath "${2:?}")
EVIDENCE=$(realpath -m "${3:?}")
IMAGE=${IMAGE:-a50-halium-build:latest}
mkdir -p "$EVIDENCE"
[ -z "$(ls -A "$EVIDENCE")" ] || { echo 'E: evidence directory must be empty' >&2; exit 1; }
export MSYS_NO_PATHCONV=1
docker run --rm --network none \
    -v "$HERE:/src:ro" -v "$ROOTFS_TAR:/in/rootfs.tar.xz:ro" \
    -v "$BUNDLE:/in/bundle:ro" -v "$EVIDENCE:/out" "$IMAGE" bash -euo pipefail -c '
        mkdir /stage
        # The builder verifies the bundle first too; fail before the long extraction.
        python3 /src/scripts/release/verify-package-bundle.py --bundle /in/bundle
        tar --numeric-owner -xJf /in/rootfs.tar.xz -C /stage
        R=/stage/system
        chroot $R dpkg-query -W > /out/packages-before.tsv
        bash /src/scripts/release/install-validated-packages.sh $R /in/bundle 2>&1 | tee /out/install.log
        chroot $R dpkg-query -W > /out/packages-after.tsv
        cp $R/usr/share/a50-release/validated-packages.lock /out/embedded.lock
        test -z "$(chroot $R dpkg --audit)"
        echo PASS > /out/result'
diff <(grep -v '^#' "$HERE/scripts/release/validated-packages.lock") <(grep -v '^#' "$EVIDENCE/embedded.lock")
# Only cohort packages may change; everything else in the fresh rootfs stays put.
cut -f1 "$HERE/scripts/release/validated-packages.lock" | grep -v '^#' | sort > "$EVIDENCE/cohort.names"
changed=$(diff <(sort "$EVIDENCE/packages-before.tsv") <(sort "$EVIDENCE/packages-after.tsv") | awk '/^[<>]/{print $2}' | cut -d: -f1 | sort -u)
outside=$(comm -23 <(printf '%s\n' "$changed" | grep .) "$EVIDENCE/cohort.names" || true)
[ -z "$outside" ] || { echo "E: non-cohort packages changed: $outside" >&2; exit 1; }
printf '%s\n' "$changed" > "$EVIDENCE/changed.names"
echo "PASS: fresh rootfs $(basename "$ROOTFS_TAR") took the $(wc -l < "$EVIDENCE/cohort.names")-package cohort via native APT; $(wc -l < "$EVIDENCE/changed.names") packages changed, all in the cohort"
