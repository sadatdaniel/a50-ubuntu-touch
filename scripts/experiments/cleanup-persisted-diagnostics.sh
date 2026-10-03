#!/bin/sh
# Authenticated cleanup of the persisted development diagnostic unit only.
set -eu
test "$(id -u)" = 0
unit=a50-aa13-diagnostics.service
file=/etc/systemd/system/$unit
backup=/home/phablet/a50-validated-compatibility/diagnostic-unit.before-cleanup
if [ -f "$file" ]; then
    grep -qx 'ExecStart=/bin/sh /userdata/.a50-aa13-diagnostics/probe.sh' "$file"
    test ! -e "$backup"
    cp -p "$file" "$backup"
    chmod 600 "$backup"
    systemctl disable --now "$unit"
    rm -f "$file"
    systemctl daemon-reload
fi
test ! -e "$file"
test ! -e /etc/systemd/system/multi-user.target.wants/$unit
echo 'Persisted diagnostic service removed. Root mount and authentication unchanged.'
