#!/bin/sh
# Install exactly the two signed camera dependencies; no app or account reset.
set -eu
test "$(id -u)" = 0
probe=/home/phablet/a50-camera-apt-probe
bundle=/home/phablet/a50-validated-compatibility/camera-action
version='1.2.2+0~20260619091020.22+ubports26.04.1~1.gbp82e7ca'
test -z "$(dpkg --audit)"
cd "$bundle"
sha256sum -c SHA256SUMS
test "$(find . -maxdepth 1 -name '*.deb' | wc -l)" = 2
for package in ./*.deb; do
    test "$(dpkg-deb -f "$package" Version)" = "$version"
    test "$(dpkg-deb -f "$package" Architecture)" = arm64
    archive="$(dpkg-deb -f "$package" Package)_${version}_arm64.deb"
    cp "$package" "$probe/cache/archives/$archive"
done
apt_local() {
    apt-get -o Dpkg::Use-Pty=0 -o Dir::State::lists="$probe/lists" \
        -o Dir::Cache="$probe/cache" -o Dir::Etc::sourcelist="$probe/sources.list" \
        -o Dir::Etc::sourceparts=- --no-remove --no-download --no-install-recommends \
        "$@" install ./*.deb
}
apt_local --simulate
mount -o remount,rw /
cleanup() {
    sync
    if ! mount -o remount,ro /; then
        echo 'Root remains writable; a controlled reboot is required.' >&2
    fi
}
trap cleanup EXIT
apt_local --yes
for package in liblomiri-action-qt1 qml-module-lomiri-action; do
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
    test "$(dpkg-query -W -f='${Version}' "$package")" = "$version"
done
test -z "$(dpkg --audit)"
echo 'Official camera Action API dependencies installed. No display restart performed.'
