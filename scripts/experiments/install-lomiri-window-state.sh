#!/bin/sh
# Normal package installation; no raw library replacement or authentication change.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run: sudo.ws sh fix'; exit 1; }
old='0.6.2+0~20261001183057.508+ubports26.04.1~1.gbpfcac00'
new="$old+a50state.2"
case "${1-}" in
    '') bundle=/home/phablet/a50-lomiri-state2; expected=$old; version=$new ;;
    --rollback) bundle=/home/phablet/a50-lomiri-state/rollback; expected=$new; version=$old ;;
    *) echo 'Unexpected option' >&2; exit 2 ;;
esac
cd "$bundle"
sha256sum -c SHA256SUMS
for package in lomiri lomiri-private lomiri-common lomiri-greeter; do
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
    test "$(dpkg-query -W -f='${Version}' "$package")" = "$expected"
done
set -- ./lomiri_*.deb ./lomiri-private_*.deb ./lomiri-common_*.deb ./lomiri-greeter_*.deb
test "$#" = 4
probe=/home/phablet/a50-camera-apt-probe
mkdir -p "$bundle/cache/archives/partial"
for file in "$@"; do
    test "$(dpkg-deb -f "$file" Version)" = "$version"
    archive="$(dpkg-deb -f "$file" Package)_$(dpkg-deb -f "$file" Version)_$(dpkg-deb -f "$file" Architecture).deb"
    cp "$file" "$bundle/cache/archives/$archive"
done
apt_local() {
    apt-get -o Dpkg::Use-Pty=0 -o Dir::State::lists="$probe/lists" \
        -o Dir::Cache="$bundle/cache" -o Dir::Etc::sourcelist="$probe/sources.list" \
        -o Dir::Etc::sourceparts=- --no-remove --no-download --no-install-recommends \
        --allow-downgrades "$@" install ./lomiri_*.deb ./lomiri-private_*.deb ./lomiri-common_*.deb ./lomiri-greeter_*.deb
}
apt_local --simulate > "$bundle/preflight.log" 2>&1
cat "$bundle/preflight.log"
# The complete plan must touch exactly these four packages and nothing else.
awk '/^Inst / {print $2}' "$bundle/preflight.log" | sort > "$bundle/plan.txt"
printf '%s\n' lomiri lomiri-common lomiri-greeter lomiri-private | sort > "$bundle/expected-plan.txt"
cmp "$bundle/plan.txt" "$bundle/expected-plan.txt"
test -z "$(dpkg --audit)"
umask 077
backup=$(mktemp -d /home/phablet/a50-window-state.XXXXXX)
dpkg-query -W > "$backup/packages.before.txt"
cp "$bundle/preflight.log" "$backup/"
mount -o remount,rw /
finish() {
    sync
    mount -o remount,ro / || echo 'Root remains writable; a controlled reboot is required.' >&2
}
trap finish EXIT
apt_local --yes > "$backup/install.log" 2>&1 || { cat "$backup/install.log"; exit 1; }
cat "$backup/install.log"
test -z "$(dpkg --audit)"
for package in lomiri lomiri-private lomiri-common lomiri-greeter; do
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
    test "$(dpkg-query -W -f='${Version}' "$package")" = "$version"
done
echo 'Window-state packages verified. No display restart or reboot performed.'
