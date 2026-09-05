#!/bin/sh
# Launch a Waydroid app from a .desktop entry, with the environment Waydroid
# needs to find the already-running session.
#
# Waydroid's generated entries run `waydroid app launch <pkg>` directly. When
# Lomiri starts them they inherit no DBUS_SESSION_BUS_ADDRESS, so waydroid
# cannot see the running session, decides to start a new one, and dies:
#
#   [..] Starting waydroid session
#   ERROR: org.freedesktop.DBus.Error.NotSupported: Unable to autolaunch a
#          dbus-daemon without a $DISPLAY for X11
#
# The app never appears and nothing is logged where a user would look - tapping
# the icon simply does nothing.
#
# Everything is defaulted rather than hardcoded, so this works for any uid and
# does not override a caller that already set the variables properly.
#
# Usage:  a50-waydroid-launch.sh <package>      launch one app
#         a50-waydroid-launch.sh --full-ui      the whole Android UI
#
# See docs/experiments/013-waydroid.md.
set -eu

U="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$U}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

if [ "${1:-}" = "--full-ui" ]; then
    exec waydroid show-full-ui
fi

[ $# -ge 1 ] || { echo "usage: $0 <package>|--full-ui" >&2; exit 2; }
exec waydroid app launch "$1"
