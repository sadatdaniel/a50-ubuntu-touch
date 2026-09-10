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

# Convergence needs BOTH three clean passes AND a minimum runtime. Waydroid
# regenerates the entries once more when Android finishes booting ("Android
# with user 0 is ready", measured ~30-50 s after session start) - a sweep
# that quits on three early clean passes converges before that regeneration
# and the clobbered Waydroid.desktop then silently fails to launch anything,
# because its bare `waydroid show-full-ui` has no session bus (2026-09-10).
MIN_PASSES=$((150 / 3))   # stay alive at least 150 s
clean=0; i=0
while [ "$i" -lt 200 ]; do
    fixed=$(sweep)
    if [ "$fixed" -eq 0 ]; then
        clean=$((clean + 1))
        [ "$clean" -ge 3 ] && [ "$i" -ge "$MIN_PASSES" ] && break
    else
        clean=0; echo "waydroid: adjusted $fixed entries"
    fi
    i=$((i + 1)); sleep 3
done
echo "waydroid: launcher shows Waydroid only"
