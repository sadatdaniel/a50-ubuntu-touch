#!/bin/sh
# Root-only regression check; never binds a UDC or touches the active gadget.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run as root.' >&2; exit 1; }
G=/sys/kernel/config/usb_gadget/a50_link_test
[ ! -e "$G" ] || { echo "$G already exists; refusing to reuse it." >&2; exit 1; }
cleanup() {
    rm -f "$G/configs/c.1/storage" "$G/configs/c.1/duplicate"
    rmdir "$G/configs/c.1/strings/0x409" 2>/dev/null || true
    rmdir "$G/functions/mass_storage.test" "$G/configs/c.1" "$G" 2>/dev/null || true
}
mkdir "$G"
trap cleanup EXIT HUP INT TERM
mkdir "$G/configs/c.1" "$G/functions/mass_storage.test"
for state in no-directory unset empty normal samsung; do
    case "$state" in
        unset) mkdir "$G/configs/c.1/strings/0x409" ;;
        empty) printf '\n' > "$G/configs/c.1/strings/0x409/configuration" ;;
        normal) printf 'Ubuntu Touch\n' > "$G/configs/c.1/strings/0x409/configuration" ;;
        samsung) printf 'Conf 1\n' > "$G/configs/c.1/strings/0x409/configuration" ;;
    esac
    i=0
    while [ "$i" -lt 3 ]; do
        ln -s "$G/functions/mass_storage.test" "$G/configs/c.1/storage"
        if ln -s "$G/functions/mass_storage.test" "$G/configs/c.1/duplicate" 2>/dev/null; then
            echo 'Duplicate function link unexpectedly accepted.' >&2
            exit 1
        fi
        rm "$G/configs/c.1/storage"
        i=$((i + 1))
    done
    echo "$state: link/unlink and duplicate rejection passed"
done
