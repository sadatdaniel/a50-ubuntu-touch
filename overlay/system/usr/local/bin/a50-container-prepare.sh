#!/bin/sh
# Generate the Android-container overrides this port needs, then wire them into
# the container's LXC mount hook.
#
# Runs once per boot, BEFORE lxc-android-config.service starts the container -
# the bind sources have to exist by the time mount.sh runs, and mount.sh runs
# inside the container's mount namespace where nothing can be fixed afterwards.
#
# Each file below is DERIVED from a vendor or GSI file that is not in git
# (Samsung's blobs are proprietary and the Halium GSI is fetched at build time),
# which is why they are generated here rather than shipped in overlay/.
#
# Idempotent: it only regenerates a file that is missing or older than its
# source, so it costs nothing on a normal boot.
set -eu

D=/var/lib/lxc/android
V=/android/vendor
S=/android/system

log() { echo "a50-container-prepare: $*"; }

[ -d "$D" ] || { log "no $D - lxc-android-config not installed?"; exit 0; }

# --- 1. watchdogd, which freezes every misc device on the system ------------
src="$V/etc/init/init.exynos9610.rc"
if [ -r "$src" ] && [ ! -s "$D/init.exynos9610.rc.nowatchdog" -o "$src" -nt "$D/init.exynos9610.rc.nowatchdog" ]; then
    sed -e 's|^\( *\)start watchdogd|\1# start watchdogd  # a50: hangs misc_mtx|' \
        -e 's|^service watchdogd /system/bin/watchdogd|service watchdogd /system/bin/watchdogd_DISABLED|' \
        "$src" > "$D/init.exynos9610.rc.nowatchdog.tmp"
    mv "$D/init.exynos9610.rc.nowatchdog.tmp" "$D/init.exynos9610.rc.nowatchdog"
    log "generated init.exynos9610.rc.nowatchdog"
fi

# --- 2. the GSI's disabled audio HALs --------------------------------------
src="$S/etc/init/init.disabled.rc"
if [ -r "$src" ] && [ ! -s "$D/init.disabled.rc.audiofix" -o "$src" -nt "$D/init.disabled.rc.audiofix" ]; then
    awk '
        /^service vendor\.audio-hal(-2-0)? / { suppress = 1 }
        suppress { print "# a50: audio HIDL re-enabled: " $0 }
        suppress && /^$/ { suppress = 0; print; next }
        !suppress { print }
    ' "$src" > "$D/init.disabled.rc.audiofix.tmp"
    mv "$D/init.disabled.rc.audiofix.tmp" "$D/init.disabled.rc.audiofix"
    log "generated init.disabled.rc.audiofix"
fi

# --- 3. speaker routing -----------------------------------------------------
src="$V/etc/mixer_paths.xml"
if [ -x /usr/local/bin/a50-gen-mixer-paths.py ] && [ -r "$src" ]; then
    if [ ! -s "$D/mixer_paths.a50.xml" ] || [ "$src" -nt "$D/mixer_paths.a50.xml" ]; then
        python3 /usr/local/bin/a50-gen-mixer-paths.py \
            && log "generated mixer_paths.a50.xml" \
            || log "WARNING mixer_paths generation failed - speaker will be silent"
    fi
fi

# --- 4. wire the hooks into the container's mount hook ----------------------
# One appended line, not a rewritten file, so a lxc-android-config update that
# changes mount.sh does not silently drop or fight with this.
if [ -f "$D/mount.sh" ] && ! grep -q 'a50-mount-hooks.sh' "$D/mount.sh"; then
    cp -a "$D/mount.sh" "$D/mount.sh.bak-a50"
    cat >> "$D/mount.sh" <<'HOOK'

# a50 port: see /var/lib/lxc/android/a50-mount-hooks.sh
[ -f /var/lib/lxc/android/a50-mount-hooks.sh ] && . /var/lib/lxc/android/a50-mount-hooks.sh
HOOK
    log "mount.sh: a50 hooks wired in"
fi

exit 0
