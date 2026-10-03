#!/bin/sh
# Repair the observed partial installation using verified local packages.
set -eu
test "$(id -u)" = 0
offline=0
case "${1-}" in
    --offline)
        # Offline mode is only valid inside the mounted recovery chroot.
        test "$(stat -Lc '%d:%i' /)" != "$(stat -Lc '%d:%i' /proc/1/root)"
        offline=1 ;;
    '') ;;
    *) echo 'Unexpected repair option' >&2; exit 2 ;;
esac
bundle=/home/phablet/a50-validated-compatibility
probe=/home/phablet/a50-camera-apt-probe
cd "$bundle"
sha256sum -c packages.sha256
cd settings
sha256sum -c SHA256SUMS
settings_version='1.4.0+0~20261001195229.487+ubports26.04.1~1.gbpd10c47+a50qtquick.1'
test "$(find . -maxdepth 1 -name '*.deb' | wc -l)" = 3
for package in ./*.deb; do
    test "$(dpkg-deb -f "$package" Version)" = "$settings_version"
    test "$(dpkg-deb -f "$package" Architecture)" = arm64
done
cd "$bundle"
cd content-hub
sha256sum -c SHA256SUMS
version='2.2.3+0~20261002220132.55+ubports26.04.1~1.gbpf9f0ad'
test "$(find . -maxdepth 1 -name '*.deb' | wc -l)" = 5
for package in ./*.deb; do
    test "$(dpkg-deb -f "$package" Version)" = "$version"
    test "$(dpkg-deb -f "$package" Architecture)" = arm64
done
apt_local() {
    apt-get -o Dir::State::lists="$probe/lists" -o Dir::Cache="$probe/cache" \
        -o Dir::Etc::sourcelist="$probe/sources.list" -o Dir::Etc::sourceparts=- \
        --fix-broken --no-remove --no-download --no-install-recommends "$@" \
        install ./*.deb ../libqt5mir1server1.deb ../qml-module-qtmir0.1.deb \
        ../qtmir-qt5-mir1.deb ../settings/*.deb
}
# APT resolves every dependency before a real installation can begin.
apt_local --simulate > "$bundle/package-repair-preflight.log" 2>&1 || {
    cat "$bundle/package-repair-preflight.log"
    exit 1
}
cat "$bundle/package-repair-preflight.log"
if [ "$offline" = 0 ]; then mount -o remount,rw /; fi
cleanup() {
    sync
    if [ "$offline" = 0 ] && ! mount -o remount,ro /; then
        echo 'Root remains writable: a controlled reboot is still required.' >&2
    fi
}
trap cleanup EXIT
apt_local --yes > "$bundle/content-hub-repair.log" 2>&1 || {
    cat "$bundle/content-hub-repair.log"
    exit 1
}
cat "$bundle/content-hub-repair.log"
dpkg --audit
for package in libqt5mir1server1 qml-module-qtmir0.1 qtmir-qt5-mir1 \
    liblomiri-content-hub1 libcontent-hub1 lomiri-content-hub \
    qml-module-lomiri-content qml-module-ubuntu-content tar libexiv2-27-compat \
    lomiri-system-settings liblomirisystemsettings1 liblomirisystemsettingsprivate0.0; do
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
done
test "$(dpkg-query -W -f='${Version}' libqt5mir1server1)" = \
 '0.7.2+0~20261001152353.82+ubports26.04.1~1.gbp38268e+a50mir1.1'
test "$(dpkg-query -W -f='${Version}' lomiri-system-settings)" = "$settings_version"
grep -qx 'import QtQuick 2.14' /usr/share/lomiri-system-settings/qml-plugins/security-privacy/LockSecurity.qml
if ldd /usr/share/click/preinstalled/camera.ubports/4.1.1/lib/aarch64-linux-gnu/CameraApp/libcamera-qml.so | grep 'not found'; then
    echo 'Camera still has a missing library.' >&2
    exit 1
fi
if [ -f /etc/systemd/system/a50-aa13-diagnostics.service ]; then
    if [ "$offline" = 0 ]; then systemctl disable --now a50-aa13-diagnostics.service; fi
    rm -f /etc/systemd/system/multi-user.target.wants/a50-aa13-diagnostics.service
    rm -f /etc/systemd/system/a50-aa13-diagnostics.service
    if [ "$offline" = 0 ]; then systemctl daemon-reload; fi
fi
echo 'Package repair verified. No display restart or reboot performed.'
