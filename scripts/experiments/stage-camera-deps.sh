#!/bin/sh
# Stage the official Qt5 Action API required by the preinstalled Camera click.
set -eu
umask 077
probe=/home/phablet/a50-camera-apt-probe
bundle=/home/phablet/a50-validated-compatibility/camera-action
version='1.2.2+0~20260619091020.22+ubports26.04.1~1.gbp82e7ca'
mkdir -p "$bundle"
cd "$bundle"
apt-get -o Dir::State::lists="$probe/lists" -o Dir::Cache="$probe/cache" \
    -o Dir::Etc::sourcelist="$probe/sources.list" -o Dir::Etc::sourceparts=- \
    -o APT::Sandbox::User=phablet download \
    "liblomiri-action-qt1=$version" "qml-module-lomiri-action=$version"
printf '%s  %s\n' \
    b36c578718d811cea94ccaca0fe6195be6c47e453e416df718a22c5e72d822c8 "liblomiri-action-qt1_${version}_arm64.deb" \
    6de2b6581035be4670294a9a01b13ab69a0e234d7bdcf91e2d804f84f477ae4f "qml-module-lomiri-action_${version}_arm64.deb" > SHA256SUMS
sha256sum -c SHA256SUMS
apt-get -s -o Dir::State::lists="$probe/lists" -o Dir::Cache="$probe/cache" \
    -o Dir::Etc::sourcelist="$probe/sources.list" -o Dir::Etc::sourceparts=- \
    --no-remove --no-install-recommends install ./*.deb
