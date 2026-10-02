#!/bin/sh
# Capture before refreshing or restarting anything. No mutations or app launch.
set -eu
date -Is
desktop=/home/phablet/.local/share/applications/Waydroid.desktop
stat -c '%n size=%s modified=%y owner=%U mode=%a' "$desktop"
grep -E '^(Name|Exec|Icon|NoDisplay|Hidden|OnlyShowIn|NotShowIn)=' "$desktop"
uid=$(id -u phablet)
as_user() {
    runuser -u phablet -- env XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        XDG_CURRENT_DESKTOP=Lomiri "$@"
}
as_user python3 - <<'PY'
from gi.repository import Gio
for app in Gio.AppInfo.get_all():
    if app.get_id() == 'Waydroid.desktop':
        print('Gio:', app.get_id(), 'visible:', app.should_show())
PY
as_user lomiri-app-launch-appids | grep -x Waydroid || true
as_user lomiri-app-info Waydroid
as_user waydroid status
systemctl show waydroid-container.service -p ActiveState -p SubState -p NRestarts -p ExecMainStartTimestamp
as_user systemctl --user show waydroid-session.service -p ActiveState -p SubState -p NRestarts -p ExecMainStartTimestamp
journalctl -b --no-pager --grep='Waydroid|Empty ualAppId|Failed to get app info' -n 25 || true
