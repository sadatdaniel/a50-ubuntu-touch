#!/bin/sh
# Restore the existing A50 audio bridge using normal systemd enablement.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run: sudo.ws sh fix'; exit 1; }
umask 077
backup=$(mktemp -d /home/phablet/a50-audio-startup.XXXXXX)
exec 3>&1
exec >"$backup/repair.log" 2>&1
trap 'code=$?; cat "$backup/repair.log" >&3; echo "Audio repair exit: $code; backup: $backup" >&3' EXIT
check() { printf '%s  %s\n' "$1" "$2" | sha256sum -c -; }
check 0af6ff6541b1a59220c8fccf9ca6097befabadca43daaab5333223f4fdb7ebe1 /etc/systemd/system/a50-audio-hidl-compat.service
check 911d0a393da62f8bc634275fe12c2916dc0e6f076720c1acab96762547f58038 /etc/systemd/system/a50-audio-route.service
check 3d9d5be9ddbfa522391ac2971f075b7c7d75b0204bb18af0aeb16e1ea5c18c96 /usr/local/bin/a50-audio-hidl-compat.sh
check 80563d1cd10aaa890d871015b051a170eadcc98e175ae3699c5a874cb7dbbbb3 /usr/local/bin/a50-audio-speaker-route.sh
for unit in a50-audio-hidl-compat.service a50-audio-route.service; do
    entry=/etc/systemd/system/multi-user.target.wants/$unit
    if [ -e "$entry" ] && [ ! -L "$entry" ]; then
        case "$unit" in
            a50-audio-hidl-compat.service) expected=0af6ff6541b1a59220c8fccf9ca6097befabadca43daaab5333223f4fdb7ebe1 ;;
            a50-audio-route.service) expected=d3719a85a4d72a0bca6ebad94183108f964d55668787fec4d73514c98ea4ae01 ;;
        esac
        check "$expected" "$entry"
        cp -a "$entry" "$backup/$unit"
        rm "$entry"
    fi
done
systemctl enable a50-audio-hidl-compat.service a50-audio-route.service
systemctl daemon-reload
systemctl restart a50-audio-hidl-compat.service
wrapper=/android/system/lib64/hw/audio.hidl_compat.default.so
hal=/android/vendor/lib64/hw/audio.primary.default.so
[ "$(stat -c %s "$wrapper")" = "$(stat -c %s "$hal")" ]
runuser -u phablet -- env XDG_RUNTIME_DIR=/run/user/32011 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus systemctl --user restart pulseaudio.service
systemctl restart a50-audio-route.service
systemctl is-enabled a50-audio-hidl-compat.service a50-audio-route.service
systemctl is-active a50-audio-hidl-compat.service a50-audio-route.service
echo 'Audio startup restored. Please reopen the video and test sound.'
