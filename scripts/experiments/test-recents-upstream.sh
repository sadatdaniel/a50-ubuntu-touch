#!/bin/sh
# Exact upstream Lomiri 5fc43d7 rendering setting; runtime-only hardware test.
set -eu
test "$(id -u)" = 0
file=/usr/share/lomiri/Stage/SurfaceContainer.qml
stage=/userdata/a50-recents-upstream-test
case "${1-}" in
    --rollback)
        test "$(findmnt -rn -M "$file" -o TARGET)" = "$file"
        cmp "$file" "$stage/SurfaceContainer.qml"
        umount "$file"
        ;;
    '')
        test -z "$(findmnt -rn -M "$file" -o TARGET)"
        printf '1e2bb126d9f70fd97dd7c103194d9f291255a7b26d6085009297e9ffd22f8900  %s\n' "$file" | sha256sum -c -
        install -d -m 0700 "$stage"
        cp -a "$file" "$stage/SurfaceContainer.original.qml"
        sed 's/fillMode: MirSurfaceItem.Stretch/fillMode: MirSurfaceItem.PadOrCrop/' "$file" > "$stage/SurfaceContainer.qml"
        test "$(grep -c 'fillMode: MirSurfaceItem.PadOrCrop' "$stage/SurfaceContainer.qml")" = 1
        mount --bind "$stage/SurfaceContainer.qml" "$file"
        ;;
    *) echo 'Usage: sh test-recents-upstream.sh [--rollback]' >&2; exit 2 ;;
esac
uid=$(id -u phablet)
runuser -u phablet -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
    systemctl --user restart lomiri-full-greeter.service
echo 'Interface reloaded. The test bind disappears on reboot.'
