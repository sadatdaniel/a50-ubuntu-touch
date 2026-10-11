#!/bin/bash
# Native APT installation in an OFFLINE image; never run against the phone root.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(realpath "${1:?usage: $0 OFFLINE_ROOT BUNDLE}")
BUNDLE=$(realpath "${2:?usage: $0 OFFLINE_ROOT BUNDLE}")
[ "$ROOT" != / ] || { echo 'E: refusing the running root' >&2; exit 1; }
[ "$(id -u)" = 0 ] || { echo 'E: image installation needs root' >&2; exit 1; }
python3 "$HERE/verify-package-bundle.py" --bundle "$BUNDLE"
# This must execute ARM64 code, either natively or using an already configured
# binfmt interpreter. Do not silently unpack .deb payloads as a substitute.
[ "$(chroot "$ROOT" dpkg --print-architecture)" = arm64 ]
chroot "$ROOT" /bin/sh -c '. /etc/os-release; test "$VERSION_ID" = 26.04'
test -z "$(chroot "$ROOT" dpkg --audit)"
STAGE=$(mktemp -d "$ROOT/tmp/a50-image-packages.XXXXXX")
REL=${STAGE#"$ROOT"}
POLICY="$ROOT/usr/sbin/policy-rc.d"
HAD_POLICY=0
if [ -e "$POLICY" ] || [ -L "$POLICY" ]; then
    mv "$POLICY" "$STAGE/policy-rc.d.saved"
    HAD_POLICY=1
fi
cleanup() {
    rm -f "$POLICY"
    if [ "$HAD_POLICY" = 1 ]; then mv "$STAGE/policy-rc.d.saved" "$POLICY"; fi
    rm -rf "$STAGE"
}
trap cleanup EXIT
printf '#!/bin/sh\nexit 101\n' > "$POLICY"
chmod 0755 "$POLICY"
set --
while IFS=$'\t' read -r name version arch digest origin; do
    case "$name" in ''|'#'*) continue ;; esac
    archive="${name}_${version}_${arch}.deb"
    cp "$BUNDLE/$archive" "$STAGE/$archive"
    set -- "$@" "$REL/$archive"
    printf '%s\n' "$name" >> "$STAGE/expected-plan"
done < "$HERE/validated-packages.lock"
apt_local() {
    chroot "$ROOT" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C \
        apt-get -o Dpkg::Use-Pty=0 --no-remove --no-download \
        --no-install-recommends --allow-downgrades "$@"
}
apt_local --simulate install "$@" > "$STAGE/plan.log" 2>&1 || { cat "$STAGE/plan.log"; exit 1; }
cat "$STAGE/plan.log"
# Existing dependencies must satisfy the cohort. Missing dependencies need a
# deliberate signed-repository input update, not an accidental network fetch.
awk '/^Inst / {print $2}' "$STAGE/plan.log" | sort -u > "$STAGE/actual-plan"
sort -u "$STAGE/expected-plan" > "$STAGE/allowed-plan"
test -z "$(comm -23 "$STAGE/actual-plan" "$STAGE/allowed-plan")"
apt_local --yes install "$@"
apt_local check
test -z "$(chroot "$ROOT" dpkg --audit)"
python3 "$HERE/verify-package-bundle.py" --root "$ROOT"
mkdir -p "$ROOT/usr/share/a50-release"
cp "$HERE/validated-packages.lock" "$ROOT/usr/share/a50-release/"
chroot "$ROOT" dpkg-query -W > "$ROOT/usr/share/a50-release/packages.tsv"
echo 'I: validated package cohort installed by native APT'
