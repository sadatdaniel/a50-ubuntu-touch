#!/bin/sh
# Install or roll back the tested native launcher package using normal APT.
set -eu
[ "$(id -u)" = 0 ] || exit 1
base='1.6.3-0ubports1~20260917185450.14~7ebfea8+ubports26.04.1'
new="$base+a50singleinstance.1"
cd /userdata/a50-waydroid-package-test
case "${1:-}" in
    '') file=/userdata/a50-waydroid-package-test/candidate.deb; expected=$base; version=$new
        hash=3f2233b1c20486e907e45932d0dca37452e29bef07ffef01534e3cfdf0aed540 ;;
    --rollback) file="/userdata/a50-waydroid-package-test/waydroid_${base}_all.deb"; expected=$new; version=$base
        hash=c62fe6dd5cb90cf67392481e13f5e7c1170a1fd822dee6463c4c363cac17226e ;;
    *) exit 2 ;;
esac
[ "$(dpkg-query -W -f='${Version}' waydroid)" = "$expected" ]
[ "$(dpkg-deb -f "$file" Package)" = waydroid ]
[ "$(dpkg-deb -f "$file" Version)" = "$version" ]
echo "$hash  $file" | sha256sum -c -
! mountpoint -q /usr/lib/waydroid/tools/services/user_manager.py
[ -z "$(dpkg --audit)" ]
mkdir -p cache/archives/partial
archive="waydroid_${version}_all.deb"
cp "$file" "cache/archives/$archive"
apt_local() {
    apt-get -o Dpkg::Use-Pty=0 \
        -o Dir::Cache=/userdata/a50-waydroid-package-test/cache --no-remove --no-download \
        --no-install-recommends --allow-downgrades "$@" install "$file"
}
apt_local --simulate > preflight.log 2>&1
cat preflight.log
[ "$(awk '/^Inst / {print $2}' preflight.log)" = waydroid ]
uid=$(id -u phablet)
as_user() {
    runuser -u phablet -- env XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" "$@"
}
dpkg-query -W > packages.before.txt
as_user waydroid session stop
mount -o remount,rw /
finish() { sync; mount -o remount,ro /; }
trap finish EXIT
apt_local --yes
[ "$(dpkg-query -W -f='${Version}' waydroid)" = "$version" ]
[ -z "$(dpkg --audit)" ]
as_user env PYTHONPATH=/usr/lib/waydroid python3 - <<'PY'
from tools.services.user_manager import makeWaydroidDesktopFile
makeWaydroidDesktopFile('/home/phablet/.local/share/applications', False)
PY
echo 'Waydroid package installed and verified; Android data retained.'
