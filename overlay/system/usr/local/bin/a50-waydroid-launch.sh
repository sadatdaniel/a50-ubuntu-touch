#!/bin/sh
# Launch a Waydroid app from a .desktop entry, under Lomiri.
#
# Two problems this solves.
#
# 1. Environment. Waydroid's own entries run `waydroid app launch <pkg>`
#    directly. Started from the launcher they inherit no
#    DBUS_SESSION_BUS_ADDRESS, so waydroid cannot see the running session,
#    decides to start a new one, and dies:
#      ERROR: org.freedesktop.DBus.Error.NotSupported: Unable to autolaunch a
#             dbus-daemon without a $DISPLAY for X11
#    Nothing appears and nothing is logged where a user would look.
#
# 2. Lifetime. `waydroid show-full-ui` and `waydroid app launch` are
#    fire-and-forget: they ask the session to show the app and exit (measured:
#    show-full-ui returns after ~1 s, rc=0). The window itself is a Wayland
#    surface owned by the long-running `waydroid session` process. But
#    lomiri-app-launch treats the process it started AS the app, so the moment
#    it exits Lomiri tears the entry down -
#      LauncherModel::applicationRemoved(...) appIndex not found
#    and the window disappears after a split second. Staying alive keeps the
#    app "running" for Lomiri, so the surface survives; when the user closes
#    the app, Lomiri stops this process normally.
#
# Usage:  a50-waydroid-launch.sh <package>      launch one app
#         a50-waydroid-launch.sh --full-ui      the whole Android UI
#
# See docs/experiments/013-waydroid.md.
set -u

U="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$U}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# 3. Stale sessions after a compositor restart. The session's Wayland clip
#    dies with the compositor it connected to, but the session PROCESS
#    survives (graphical-session.target does not cycle when lightdm
#    restarts Lomiri, so the unit's PartOf= never fires). A surviving
#    session then serves launch requests into a dead socket: the app
#    "launches", no window ever maps, and Lomiri's launching splash spins
#    forever. The socket's mtime is newer than the session's start time
#    exactly when the compositor was replaced after the session began -
#    restart the session then. (2026-09-11)
SESSION_PID="$(pgrep -f 'waydroid session start' | head -1)"
if [ -n "$SESSION_PID" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
    # /proc/PID's mtime is dynamic; ps etimes gives the true start time.
    S_ELAPSED="$(ps -o etimes= -p "$SESSION_PID" 2>/dev/null | tr -d " ")"
    S_STARTED="$(($(date +%s) - ${S_ELAPSED:-0}))"
    S_SOCK="$(stat -c %Y "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" 2>/dev/null || echo 0)"
    if [ "$S_SOCK" -gt "$S_STARTED" ]; then
        waydroid session stop >/dev/null 2>&1
        sleep 1
    fi
fi

if [ "${1:-}" = "--full-ui" ]; then
    waydroid show-full-ui || exit $?
else
    [ $# -ge 1 ] || { echo "usage: $0 <package>|--full-ui" >&2; exit 2; }
    waydroid app launch "$1" || exit $?
fi

# Hold the app open for Lomiri, and release the Android surface when the user
# closes it.
#
# Swiping the window away kills this process, but the Android app keeps running
# inside the container and keeps hold of the single surface Waydroid exposes in
# single-window mode. The next launch then finds the surface already taken and
# shows nothing. Sending Android to its home screen on the way out releases it,
# so relaunching works. `waydroid app intent` needs no root, unlike
# `waydroid shell`.
release() {
    waydroid app intent android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1
}
trap release EXIT TERM INT

sleep infinity &
wait $!
