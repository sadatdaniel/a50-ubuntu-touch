#!/bin/sh
# Per-boot device setup for the A50 that has to happen AFTER the Android
# container is running. Static configuration belongs in the build overlay.
#
# Everything here is idempotent and cheap on a boot where it has already been
# done.  It is invoked from /usr/libexec/lxc-android-config/device-hacks, the
# hook Ubuntu Touch provides for exactly this, which runs after
# lxc-android-config.service.
#
# Things that must happen BEFORE the container starts are in
# /usr/local/bin/a50-container-prepare.sh instead.
set -u

log() { echo "a50-device-setup: $*"; }

# --- /dev/gnss_ipc on a node that already exists ----------------------------
# usr/lib/udev/rules.d/99-a50-gnss.rules handles it at hotplug time; this
# catches the node udev created before the rule was in place.
if [ -e /dev/gnss_ipc ]; then
    chown system:system /dev/gnss_ipc 2>/dev/null || true
    chmod 0660 /dev/gnss_ipc 2>/dev/null || true
fi

# --- Waydroid ---------------------------------------------------------------
# The session has to run as a systemd *user* unit: started as root, or through
# `su phablet -c`, the D-Bus address stays root's and the session refuses to
# start with AccessDenied on /run/user/0/bus.
# docs/experiments/013-waydroid.md
if [ -x /usr/bin/waydroid ] && [ -f /usr/lib/systemd/user/waydroid-session.service ]; then
    P_UID=$(id -u phablet 2>/dev/null || echo 32011)
    if [ -d "/run/user/$P_UID" ]; then
        su phablet -c "XDG_RUNTIME_DIR=/run/user/$P_UID \
            DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$P_UID/bus \
            systemctl --user enable --now waydroid-session.service" >/dev/null 2>&1 \
            && log "waydroid session unit enabled"
    fi
fi


# The .desktop sweep is NOT started here.  It edits files under the phablet
# user's $HOME, and waydroid-session.service - a *user* unit, with the right
# $HOME - already launches it.
exit 0
