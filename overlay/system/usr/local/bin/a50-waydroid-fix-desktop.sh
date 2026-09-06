#!/bin/sh
# Keep the Lomiri launcher showing ONLY the Waydroid entry.
#
# Waydroid rewrites ~/.local/share/applications/waydroid.*.desktop on every
# session start, so this must keep sweeping, not run once.
#
# Policy (user's choice): only one Waydroid app can be shown at a time, because
# Waydroid exposes a single Android surface in single-window mode. Rather than
# per-app icons that steal the surface from each other, show only the Waydroid
# launcher and start apps from inside Android.
#
#   Waydroid.desktop        -> visible, via the wrapper
#   waydroid.<pkg>.desktop  -> hidden
#
# The wrapper supplies XDG_RUNTIME_DIR / DBUS_SESSION_BUS_ADDRESS /
# WAYLAND_DISPLAY, without which the launcher silently fails.
set -u

D="$HOME/.local/share/applications"
LAUNCH=/usr/local/bin/a50-waydroid-launch.sh

sweep() {
    n=0
    for f in "$D"/waydroid.*.desktop; do
        [ -e "$f" ] || continue
        if ! grep -q '^NoDisplay=true' "$f" 2>/dev/null; then
            if grep -q '^NoDisplay=' "$f"; then
                sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f"
            else
                echo "NoDisplay=true" >> "$f"
            fi
            n=$((n + 1))
        fi
    done
    W="$D/Waydroid.desktop"
    if [ -e "$W" ]; then
        if grep -q '^Exec=waydroid show-full-ui' "$W" 2>/dev/null; then
            sed -i "s|^Exec=waydroid show-full-ui|Exec=$LAUNCH --full-ui|" "$W"
            n=$((n + 1))
        fi
        if grep -q '^NoDisplay=true' "$W" 2>/dev/null; then
            sed -i 's/^NoDisplay=.*/NoDisplay=false/' "$W"
            n=$((n + 1))
        fi
    fi
    echo "$n"
}

clean=0; i=0
while [ "$i" -lt 80 ]; do
    fixed=$(sweep)
    if [ "$fixed" -eq 0 ]; then
        clean=$((clean + 1)); [ "$clean" -ge 3 ] && break
    else
        clean=0; echo "waydroid: adjusted $fixed entries"
    fi
    i=$((i + 1)); sleep 3
done
echo "waydroid: launcher shows Waydroid only"
