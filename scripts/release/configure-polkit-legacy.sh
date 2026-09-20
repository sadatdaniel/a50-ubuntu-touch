#!/bin/bash
# Configure polkit's supported legacy helper in an OFFLINE A50 rootfs.
# Kernel 4.14 lacks SO_PEERPIDFD required by polkit 127 socket mode.
# Password/PAM authorization remains enabled. See docs/polkit-legacy.md.
set -euo pipefail
ROOT=$(realpath "${1:?usage: $0 <offline mounted rootfs>}")
[ "$ROOT" != / ] || { echo 'E: refusing the running host root' >&2; exit 1; }
H=/usr/lib/polkit-1/polkit-agent-helper-1
[ -f "$ROOT$H" ] && [ ! -L "$ROOT$H" ] || {
    echo 'E: expected a regular installed polkit helper' >&2; exit 1; }
[ "$(stat -c %u:%g "$ROOT$H")" = 0:0 ] || {
    echo 'E: helper must be owned by root:root' >&2; exit 1; }
[ -f "$ROOT/usr/lib/systemd/system/polkit-agent-helper.socket" ] || {
    echo 'E: socket unit missing; review this package version before applying' >&2; exit 1; }
BEFORE=$(sha256sum "$ROOT$H" | cut -d' ' -f1)
OLD=$(dpkg-statoverride --root "$ROOT" --list "$H" || test "$?" = 1)
case "$OLD" in
    '') dpkg-statoverride --root "$ROOT" --add --update root root 4755 "$H" ;;
    "root root 4755 $H") chmod 4755 "$ROOT$H" ;;
    *) echo "E: conflicting permission override: $OLD" >&2; exit 1 ;;
esac
mkdir -p "$ROOT/etc/systemd/system"
SOCKET="$ROOT/etc/systemd/system/polkit-agent-helper.socket"
if [ -e "$SOCKET" ] || [ -L "$SOCKET" ]; then
    [ "$(readlink "$SOCKET")" = /dev/null ] || {
        echo 'E: local socket configuration needs review' >&2; exit 1; }
else
    ln -s /dev/null "$SOCKET"
fi
[ "$(stat -c %a "$ROOT$H")" = 4755 ]
[ "$(sha256sum "$ROOT$H" | cut -d' ' -f1)" = "$BEFORE" ]
echo 'I: A50 polkit legacy helper configured; PAM unchanged'