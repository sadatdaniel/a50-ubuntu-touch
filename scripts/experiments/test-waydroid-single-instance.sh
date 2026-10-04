#!/bin/sh
# Reversible native launcher setting test; reboot restores package source.
set -eu
[ "$(id -u)" = 0 ] || exit 1
target=/usr/lib/waydroid/tools/services/user_manager.py
state=/run/a50-waydroid-single-instance
desktop=/home/phablet/.local/share/applications/Waydroid.desktop
uid=$(id -u phablet)
as_user() {
    runuser -u phablet -- env XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" "$@"
}
case "${1:-}" in
    apply)
        [ $# = 2 ] || exit 2
        [ ! -e "$state" ] || { echo 'An experiment already exists.' >&2; exit 1; }
        echo "cc0c23d6c7849a108ecbdf800129899993186f6cba9e0d0d2f4edad916ef595e  $target" | sha256sum -c -
        install -d -m 0700 "$state"
        cp -p "$desktop" "$state/Waydroid.desktop"
        install -m 0644 -o root -g root "$2" "$state/user_manager.py"
        echo "5fdb97bccca110ae88389121001bf41055bad9721e68b663042344421867dec4  $state/user_manager.py" | sha256sum -c -
        as_user waydroid session stop
        mount --bind "$state/user_manager.py" "$target"
        mount -o remount,bind,ro "$target"
        as_user env PYTHONPATH=/usr/lib/waydroid python3 - <<'PY'
from tools.services.user_manager import makeWaydroidDesktopFile
makeWaydroidDesktopFile('/home/phablet/.local/share/applications', False)
PY
        grep -x 'X-Lomiri-Single-Instance=true' "$desktop"
        echo 'Native single-instance test ready; refresh the drawer and open Waydroid.'
        ;;
    restore)
        [ -e "$state/Waydroid.desktop" ] || exit 1
        as_user waydroid session stop
        umount "$target"
        echo "cc0c23d6c7849a108ecbdf800129899993186f6cba9e0d0d2f4edad916ef595e  $target" | sha256sum -c -
        cp -p "$state/Waydroid.desktop" "$desktop"
        touch "$state/restored"
        echo 'Original generator and launcher restored; existing Android data retained.'
        ;;
    *) echo 'Usage: test-waydroid-single-instance.sh apply CANDIDATE_FILE | restore' >&2; exit 2 ;;
esac
