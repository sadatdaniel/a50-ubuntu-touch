#!/bin/sh
# Repair the .desktop entries Waydroid generates, and keep repairing them.
#
# Waydroid rewrites ~/.local/share/applications/waydroid.*.desktop on EVERY
# session start, with:
#
#   NoDisplay=true                  -> invisible in the Lomiri app drawer
#   Exec=waydroid app launch <pkg>  -> fails from the launcher: it inherits no
#                                      DBUS_SESSION_BUS_ADDRESS, cannot see the
#                                      running session, tries to start a new one
#                                      and dies. The window appears for a split
#                                      second and vanishes.
#
# A single pass loses a race: the session unit's ExecStartPost fires as soon as
# waydroid is spawned, but waydroid writes the entries later, overwriting the
# repair. So sweep repeatedly for a while, and only stop once the entries have
# stayed fixed.
#
# See docs/experiments/013-waydroid.md.
set -u

D="$HOME/.local/share/applications"
LAUNCH=/usr/local/bin/a50-waydroid-launch.sh

repair() {
    n=0
    for f in "$D"/waydroid.*.desktop; do
        [ -e "$f" ] || continue
        if grep -q '^Exec=waydroid app launch \|^NoDisplay=true' "$f" 2>/dev/null; then
            sed -i "s|^Exec=waydroid app launch |Exec=$LAUNCH |" "$f"
            sed -i 's/^NoDisplay=true/NoDisplay=false/' "$f"
            n=$((n + 1))
        fi
    done
    if [ -e "$D/Waydroid.desktop" ] && grep -q '^Exec=waydroid show-full-ui' "$D/Waydroid.desktop" 2>/dev/null; then
        sed -i "s|^Exec=waydroid show-full-ui|Exec=$LAUNCH --full-ui|" "$D/Waydroid.desktop"
        n=$((n + 1))
    fi
    echo "$n"
}

# Sweep for up to ~4 minutes, and require the entries to stay clean for three
# consecutive passes before declaring victory.
clean=0
i=0
while [ "$i" -lt 80 ]; do
    fixed=$(repair)
    if [ "$fixed" -eq 0 ]; then
        clean=$((clean + 1))
        [ "$clean" -ge 3 ] && break
    else
        clean=0
        echo "waydroid: repaired $fixed entries (pass $i)"
    fi
    i=$((i + 1))
    sleep 3
done
echo "waydroid: entries settled after $i passes"
