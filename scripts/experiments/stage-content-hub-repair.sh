#!/bin/sh
set -eu
umask 077
probe=/home/phablet/a50-camera-apt-probe
bundle=/home/phablet/a50-validated-compatibility
version='2.2.3+0~20261002220132.55+ubports26.04.1~1.gbpf9f0ad'
mkdir -p "$bundle/content-hub"
cd "$bundle/content-hub"
apt-get -o Dir::State::lists="$probe/lists" -o Dir::Cache="$probe/cache" \
 -o Dir::Etc::sourcelist="$probe/sources.list" -o Dir::Etc::sourceparts=- \
 -o APT::Sandbox::User=phablet download \
 "liblomiri-content-hub1=$version" "libcontent-hub1=$version" \
 "lomiri-content-hub=$version" "qml-module-lomiri-content=$version" \
 "qml-module-ubuntu-content=$version"
sha256sum ./*.deb > SHA256SUMS
for package in ./*.deb; do dpkg-deb -f "$package" Package Version Architecture; done
apt-get -s --fix-broken -o Debug::NoLocking=1 -o Dir::State::lists="$probe/lists" \
 -o Dir::Cache="$probe/cache" -o Dir::Etc::sourcelist="$probe/sources.list" \
 -o Dir::Etc::sourceparts=- --no-remove --no-install-recommends install \
 ./*.deb "$bundle/libqt5mir1server1.deb" "$bundle/qml-module-qtmir0.1.deb" \
 "$bundle/qtmir-qt5-mir1.deb"
