#!/bin/sh
# Replace the tested local DPR patch with its official UBports Mir1 fix.
# This is a guarded development-phone transaction, not a release installer.
set -eu
test "$(id -u)" = 0
old='0.7.2+0~20261001152353.82+ubports26.04.1~1.gbp38268e+a50mir1.1'
new='0.7.2+0~20261008000645.83+ubports26.04.1~1.gbpac3ee9'
bundle=/userdata/a50-qtmir-upstream-test
case "${1-}" in
    '') expected=$old; version=$new; archives="$bundle/cache/archives" ;;
    --rollback) expected=$new; version=$old; archives="$bundle/rollback" ;;
    *) echo 'Usage: sh install-qtmir-upstream.sh [--rollback]' >&2; exit 2 ;;
esac
test -z "$(dpkg --audit)"
for package in libqt5mir1server1 qml-module-qtmir0.1 qtmir-qt5-mir1; do
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
    test "$(dpkg-query -W -f='${Version}' "$package")" = "$expected"
done
cd "$archives"
if [ "$version" = "$new" ]; then
    sha256sum -c <<EOF
932b6e7d28fb0f3cc8da8ed0247592d1f3ce64c121813517b49896fd56140b59  libqt5mir1server1_${version}_arm64.deb
d89cc9473bfd19a1688ae501393094723d1d6a89d32d866a462899580d51d317  qml-module-qtmir0.1_${version}_arm64.deb
5d536431acc23bfb3acc888cae01bb8ca870ca4cc85c3549f141eb934cc09d9c  qtmir-qt5-mir1_${version}_arm64.deb
EOF
else
    sha256sum -c <<EOF
db1d41d5cc870a8aa0b6059fbc7a4ff0ec88ae3c3074d685a18ee070622cc7e3  libqt5mir1server1_${version}_arm64.deb
57f5130583b8309ecdfb9898188512d3ee25298f0dc812d0686802f06b737de9  qml-module-qtmir0.1_${version}_arm64.deb
8b12fe7bb5f45fc82370ea3e2f564ef45719ead4b72205341250809098dedf48  qtmir-qt5-mir1_${version}_arm64.deb
EOF
fi
set -- "$archives/libqt5mir1server1_${version}_arm64.deb" \
    "$archives/qml-module-qtmir0.1_${version}_arm64.deb" \
    "$archives/qtmir-qt5-mir1_${version}_arm64.deb"
for archive in "$@"; do
    test "$(dpkg-deb -f "$archive" Version)" = "$version"
    test "$(dpkg-deb -f "$archive" Architecture)" = arm64
    if [ "$archives" != "$bundle/cache/archives" ]; then
        cp "$archive" "$bundle/cache/archives/"
    fi
done
probe=/userdata/a50-20261010-check/apt
apt_local() {
    apt-get -o Dpkg::Use-Pty=0 -o Dir::State::lists="$probe/lists" \
        -o Dir::Cache="$bundle/cache" -o Dir::Etc::sourcelist="$probe/sources.list" \
        -o Dir::Etc::sourceparts=- --no-remove --no-download --no-install-recommends \
        --allow-downgrades "$@" install "$archives/libqt5mir1server1_${version}_arm64.deb" \
        "$archives/qml-module-qtmir0.1_${version}_arm64.deb" \
        "$archives/qtmir-qt5-mir1_${version}_arm64.deb"
}
apt_local --simulate > "$bundle/transaction-preflight.log" 2>&1
cat "$bundle/transaction-preflight.log"
awk '/^Inst / {print $2}' "$bundle/transaction-preflight.log" | sort > "$bundle/plan.txt"
printf '%s\n' libqt5mir1server1 qml-module-qtmir0.1 qtmir-qt5-mir1 | sort > "$bundle/expected-plan.txt"
cmp "$bundle/plan.txt" "$bundle/expected-plan.txt"
dpkg-query -W > "$bundle/packages-before.txt"
mount -o remount,rw /
finish() {
    sync
    mount -o remount,ro / || echo 'A controlled reboot is required to restore read-only root.' >&2
}
trap finish EXIT
apt_local --yes > "$bundle/install.log" 2>&1 || { cat "$bundle/install.log"; exit 1; }
cat "$bundle/install.log"
test -z "$(dpkg --audit)"
for package in libqt5mir1server1 qml-module-qtmir0.1 qtmir-qt5-mir1; do
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
    test "$(dpkg-query -W -f='${Version}' "$package")" = "$version"
done
echo 'Official QtMir transaction complete. Restart/reboot validation remains.'
