#!/bin/sh
# Re-apply the runtime workarounds this port needs, after a rootfs reflash.
#
# SINCE 2026-09-06 A FRESH INSTALL DOES NOT NEED THIS. Everything below now
# ships in overlay/system and applies itself at boot:
#   a50-container-prepare.service  before the Android container starts
#   device-hacks -> a50-device-setup.sh   after it is up
# This script is for a device that was flashed BEFORE that change, and as a
# way to run any single block by hand. It stays idempotent so running it on a
# current image is a no-op.
#
# These are STOPGAPS. Each one names the real fix it stands in for; when that
# real fix lands in the kernel, delete the corresponding block here.
#
# Run as root on the device:
#   ssh root@<device> 'sh -s' < scripts/apply-device-workarounds.sh
#
# Idempotent: safe to run repeatedly.
set -eu

D=/var/lib/lxc/android
mount -o remount,rw / 2>/dev/null || true

# ---------------------------------------------------------------------------
# 1. Keep the Android container away from USB gadget configfs.
#
# REAL FIX: an idempotency guard in conn_gadget_setup(), see a50-halium
# kernel/patches/. Until that ships, this stopgap is what keeps the device
# usable at all.
#
# Why: f_conn_gadget.c calls misc_register() on a STATIC miscdevice with no
# already-registered check. usb_moded (host) and vendor_init (container) both
# drive USB gadget configfs, so the function gets instantiated twice;
# misc_register()'s INIT_LIST_HEAD then points that node at itself while its
# old neighbours still point to it, making misc_list circular. The next
# list_for_each_entry inside misc_open() spins forever holding misc_mtx, and
# every misc-device open on the system (mali0, ion, binder, hwbinder, uinput,
# the compositor, every HAL) hangs. See docs/experiments/006-what-we-missed.md
# ---------------------------------------------------------------------------
if [ ! -f "$D/usb.rc.empty" ]; then
    printf '# emptied: UT usb_moded owns the USB gadget; Android double-instantiating\n# configfs gadget functions corrupts misc_list (unguarded misc_register).\n' \
        > "$D/usb.rc.empty"
fi

if ! grep -q 'usb.rc.empty' "$D/mount.sh"; then
    cp "$D/mount.sh" "$D/mount.sh.bak-preworkaround"
    cat >> "$D/mount.sh" <<'HOOK'

# Stopgap: see a50-ubuntu-touch scripts/apply-device-workarounds.sh
if [ -f /var/lib/lxc/android/usb.rc.empty ]; then
    mount --bind /var/lib/lxc/android/usb.rc.empty \
        "${LXC_ROOTFS_MOUNT}/vendor/etc/init/init.exynos9610.usb.rc"
fi
HOOK
    echo "mount.sh: USB gadget hook installed"
else
    echo "mount.sh: USB gadget hook already present"
fi

# ---------------------------------------------------------------------------
# 2. sensorfwd must not stay masked.
#
# It was masked during the misc_mtx investigation (it was one of the daemons
# caught spinning at 100% CPU holding the lock). With the corruption gone it
# runs normally and rotation works; leaving it masked silently disables all
# sensors.
# ---------------------------------------------------------------------------
if [ "$(systemctl is-enabled sensorfwd 2>/dev/null)" = "masked" ]; then
    systemctl unmask sensorfwd
    systemctl daemon-reload
    systemctl start sensorfwd
    echo "sensorfwd: unmasked and started"
else
    echo "sensorfwd: already enabled"
fi

# ---------------------------------------------------------------------------
# 3. Audio: re-enable the Android audio HAL and bridge it to 64-bit.
#
# Two independent problems, both inherited from the Halium GSI rather than
# from this port:
#
#   a) The GSI's system/etc/init/init.disabled.rc points BOTH vendor.audio-hal
#      and vendor.audio-hal-2-0 at nonexistent binaries (_DISABLED /
#      _HYBRIS_DISABLED suffixes), so no Android audio HAL runs at all.
#   b) The real Samsung HAL (audio.primary.exynos9610.so) is 32-bit only and
#      exists solely in /vendor/lib/hw. A 64-bit audio stack cannot load it and
#      silently falls back to the generic stub, which returns a stream with a
#      NULL op table. Android's own 64-bit audio.hidl_compat wrapper forwards
#      the legacy calls to the real 32-bit HIDL service over /dev/hwbinder.
#
# Same diagnosis as the Droidian port (a50-droidian docs/audio.md).
# ---------------------------------------------------------------------------
R="$D/rootfs"
if [ ! -f "$D/init.disabled.rc.audiofix" ] && [ -f "$R/system/etc/init/init.disabled.rc" ]; then
    awk '
        /^service vendor\.audio-hal(-2-0)? / { suppress = 1 }
        suppress { print "# A50 audio HIDL re-enabled: " $0 }
        suppress && /^$/ { suppress = 0; print; next }
        !suppress { print }
    ' "$R/system/etc/init/init.disabled.rc" > "$D/init.disabled.rc.audiofix"
    echo "audio: init.disabled.rc override generated"
fi

if ! grep -q 'audiofix' "$D/mount.sh"; then
    cat >> "$D/mount.sh" <<'HOOK'

# Audio: re-enable the GSI-disabled audio HALs, and present Android's 64-bit
# audio.hidl_compat wrapper at the HAL name a 64-bit stack resolves.
if [ -f /var/lib/lxc/android/init.disabled.rc.audiofix ]; then
    mount --bind /var/lib/lxc/android/init.disabled.rc.audiofix \
        "${LXC_ROOTFS_MOUNT}/system/etc/init/init.disabled.rc"
fi
if [ -f /android/system/lib64/hw/audio.hidl_compat.default.so ]; then
    mount --bind /android/system/lib64/hw/audio.hidl_compat.default.so \
        "${LXC_ROOTFS_MOUNT}/vendor/lib64/hw/audio.primary.default.so"
fi
HOOK
    echo "audio: mount.sh hooks installed (take effect next container start)"
else
    echo "audio: mount.sh hooks already present"
fi

# The legacy HAL has no create_audio_patch; without this flag the droid module
# calls that absent operation and dereferences a NULL function pointer, and
# PulseAudio segfaults in a restart loop. Verified: SEGV before, clean run and
# sink.primary-out / sink.fast after.
if ! grep -q 'use_legacy_stream_set_parameters' /etc/pulse/touch.pa; then
    cp /etc/pulse/touch.pa /etc/pulse/touch.pa.bak
    sed -i 's/load-module module-droid-discover voice_virtual_stream=true usb_devices=true/load-module module-droid-discover voice_virtual_stream=true usb_devices=true use_legacy_stream_set_parameters=true/' \
        /etc/pulse/touch.pa
    echo "audio: touch.pa patched (restart pulseaudio to apply)"
else
    echo "audio: touch.pa already patched"
fi


# A50 speaker routing: the stock mixer_paths.xml routes the speaker amplifier
# from SIFS1, fed by RDMA7 - a channel this ABOX DSP NACKs - so nothing reaches
# the amp. Generate a patched copy and bind it in via the LXC mount hook, so the
# HAL itself routes correctly on every stream and every call.
# See docs/experiments/007-abox-firmware-too-early.md.
if [ -x /usr/local/bin/a50-gen-mixer-paths.py ]; then
    python3 /usr/local/bin/a50-gen-mixer-paths.py || echo "audio: mixer_paths patch FAILED"
fi
if ! grep -q mixer_paths.a50.xml /var/lib/lxc/android/mount.sh 2>/dev/null; then
    cat >> /var/lib/lxc/android/mount.sh <<'HOOK'

if [ -f /var/lib/lxc/android/mixer_paths.a50.xml ]; then
    mount --bind /var/lib/lxc/android/mixer_paths.a50.xml \
        "${LXC_ROOTFS_MOUNT}/vendor/etc/mixer_paths.xml"
fi
HOOK
    echo "audio: mixer_paths bind added to mount.sh (takes effect next container start)"
else
    echo "audio: mixer_paths bind already in mount.sh"
fi

# ---------------------------------------------------------------------------
# 5. GPS: the two things that stopped a location session ever starting.
#
# REAL FIX (a): none needed beyond this rule - overlay/ ships it for new builds;
#               this block installs it on an already-flashed device.
# REAL FIX (b): a kernel with AppArmor built in. When one boots, delete the
#               drop-in and the trust-store prompt comes back.
#
# (a) /dev/gnss_ipc comes up 0600 root:root. The vendor's own
#     /vendor/etc/init/init.gps.rc says "chmod 0660 / chown system system", and
#     its gpsd service runs as "user gps" with "group system" - so gpsd
#     (uid 1021) reaches the node through the system group and cannot open it
#     as shipped. That post-fs-data block never runs in the Halium container.
#
# (b) lomiri-location-service resolves each client's AppArmor profile before it
#     will open a session. With no AppArmor in this kernel that resolution
#     fails and CreateSessionForCriteria returns Error.CreatingSession for
#     every client, so no app can ever get a position.
#
# See docs/experiments/009-gps-permissions.md.
# ---------------------------------------------------------------------------
if [ ! -f /etc/udev/rules.d/99-a50-gnss.rules ]; then
    cat > /etc/udev/rules.d/99-a50-gnss.rules <<'EOF'
# See docs/experiments/009-gps-permissions.md - vendor init.gps.rc wants
# 0660 system system on /dev/gnss_ipc; the container never applies it.
KERNEL=="gnss_ipc", SUBSYSTEM=="misc", OWNER="system", GROUP="system", MODE="0660"
EOF
    udevadm control --reload-rules 2>/dev/null || true
    echo "gps: gnss_ipc udev rule installed"
else
    echo "gps: gnss_ipc udev rule already present"
fi
# Apply to the node that already exists, so no reboot is needed.
if [ -e /dev/gnss_ipc ]; then
    chown system:system /dev/gnss_ipc && chmod 0660 /dev/gnss_ipc
fi

if [ ! -f /etc/systemd/system/lomiri-location-service.service.d/50-a50-trust-store.conf ]; then
    mkdir -p /etc/systemd/system/lomiri-location-service.service.d
    cat > /etc/systemd/system/lomiri-location-service.service.d/50-a50-trust-store.conf <<'EOF'
# See docs/experiments/009-gps-permissions.md. Grants location without the
# trust-store prompt, because AppArmor profile resolution cannot work on a
# kernel with no AppArmor. Delete once such a kernel boots.
[Service]
Environment=TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING=1
EOF
    systemctl daemon-reload
    systemctl try-restart lomiri-location-service
    echo "gps: location-service trust-store drop-in installed"
else
    echo "gps: location-service trust-store drop-in already present"
fi

# ---------------------------------------------------------------------------
# 6. GPS: unblock gpsd, which waits for a boot animation that never runs.
#
# REAL FIX: none available - this is closed vendor code. The property is what
# stock Android's boot animation sets; the container simply has no boot
# animation to set it.
#
# /vendor/bin/hw/gpsd reads service.bootanim.exit at startup and, until it is
# set, sits in a 250 ms poll loop forever: one thread, never reads its config,
# never opens /dev/gnss_ipc, never binds its socket, logs nothing. The GNSS HAL
# then fails to connect to @GNSSND and spins lal_state_handle_transition three
# times a second. With the property set, gpsd reaches 12 threads, binds the
# socket, and real satellites arrive.
#
# See docs/experiments/009-gps-permissions.md.
# ---------------------------------------------------------------------------
install -D -m 0755 /dev/stdin /usr/local/bin/a50-gnss-unblock.sh <<'SCRIPT'
#!/bin/sh
set -eu
A="lxc-attach -n android --"
$A /system/bin/setprop service.bootanim.exit 1
$A /system/bin/setprop ctl.restart gpsd
i=0
while [ $i -lt 40 ]; do
    grep -q GNSSND /proc/net/unix 2>/dev/null && { echo "gnss: gpsd bound @GNSSND"; break; }
    i=$((i + 1)); sleep 0.25
done
grep -q GNSSND /proc/net/unix 2>/dev/null || echo "gnss: WARNING gpsd did not bind @GNSSND" >&2
$A /system/bin/setprop ctl.restart sec_gnss_service
systemctl try-restart lomiri-location-service || true
echo "gnss: done"
SCRIPT

install -D -m 0644 /dev/stdin /etc/systemd/system/a50-gnss-unblock.service <<'UNIT'
[Unit]
Description=A50: unblock Samsung gpsd (waits for a boot animation that never runs)
Documentation=https://github.com/sadatdaniel/a50-ubuntu-touch/blob/main/docs/experiments/009-gps-permissions.md
After=lxc-android-config.service
Wants=lxc-android-config.service
Before=lomiri-location-service.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/a50-gnss-unblock.sh
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable a50-gnss-unblock.service >/dev/null 2>&1 || true
echo "gps: gpsd unblock service installed"

# ---------------------------------------------------------------------------
# 7. Fingerprint: let biometryd operate without kernel AppArmor.
#
# REAL FIX: a kernel with AppArmor built in. When one boots, delete this
# drop-in and the caller-profile check works normally.
#
# biometryd gates enroll/identify/clear behind an AppArmor credentials check on
# the D-Bus caller (DaemonCredentialsResolver via libapparmor). With no
# AppArmor that resolution fails and every call returns
# com.ubports.biometryd.Error.NotPermitted - which also crashes System Settings
# (SIGABRT) the instant the Fingerprint page opens, because it does not catch
# the exception. BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING makes the
# skeleton permit the call before resolving a profile - the same mechanism as
# the location-service trust-store bypass in block 5.
#
# See docs/experiments/012-fingerprint.md.
# ---------------------------------------------------------------------------
if [ ! -f /etc/systemd/system/biometryd.service.d/50-a50-testing.conf ]; then
    mkdir -p /etc/systemd/system/biometryd.service.d
    cat > /etc/systemd/system/biometryd.service.d/50-a50-testing.conf <<'EOF'
# See docs/experiments/012-fingerprint.md. Lets biometryd operate with no
# kernel AppArmor; without it every op returns NotPermitted and opening the
# Settings fingerprint page crashes System Settings. Delete once AppArmor boots.
[Service]
Environment=BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING=1
EOF
    systemctl daemon-reload
    systemctl restart biometryd
    echo "fingerprint: biometryd testing drop-in installed"
else
    echo "fingerprint: biometryd testing drop-in already present"
fi

# ---------------------------------------------------------------------------
# 8. Waydroid: start the session with the user's own bus.
#
# REAL FIX: none needed - this is packaging, not a workaround for a bug. The
# kernel half (the anbox-* binder nodes) lives in a50-halium.
#
# Waydroid needs XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS and WAYLAND_DISPLAY.
# Starting it as root, or with `su phablet -c`, fails with
#   org.freedesktop.DBus.Error.AccessDenied: /run/user/0/bus: Permission denied
# because the bus address is still root's. A systemd *user* unit inherits the
# correct values from the user manager, so it just works.
#
# Without a running session the desktop entries Waydroid generates
# (~/.local/share/applications/waydroid.*.desktop) fail after a reboot, since
# `waydroid app launch` needs one. waydroid-container.service is static and
# starts on demand, so only the session needs arranging.
#
# See docs/experiments/013-waydroid.md.
# ---------------------------------------------------------------------------
if [ -x /usr/bin/waydroid ] && [ ! -f /usr/lib/systemd/user/waydroid-session.service ]; then
    echo "waydroid: session unit missing - install it from overlay/" >&2
elif [ -x /usr/bin/waydroid ]; then
    P_UID=$(id -u phablet 2>/dev/null || echo 32011)
    su phablet -c "XDG_RUNTIME_DIR=/run/user/$P_UID \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$P_UID/bus \
        systemctl --user enable waydroid-session.service" >/dev/null 2>&1 \
        && echo "waydroid: session unit enabled" \
        || echo "waydroid: could not enable session unit (is the user session up?)"
fi

# Waydroid's generated app entries are broken in two ways for Lomiri:
#
#   1. Every one is written NoDisplay=true, hiding all Android apps from the
#      app drawer.
#   2. Their Exec runs `waydroid app launch <pkg>` directly. Started from the
#      launcher they inherit no DBUS_SESSION_BUS_ADDRESS, so waydroid cannot
#      find the running session, tries to start a new one, and fails with
#      "Unable to autolaunch a dbus-daemon without a $DISPLAY". Tapping the
#      icon silently does nothing.
#
# a50-waydroid-launch.sh supplies the environment; point every entry at it.
# Re-run this after installing new Android apps - Waydroid regenerates them.
D=/home/phablet/.local/share/applications
if [ -d "$D" ]; then
    n=0
    for f in "$D"/waydroid.*.desktop; do
        [ -e "$f" ] || continue
        sed -i 's|^Exec=waydroid app launch |Exec=/usr/local/bin/a50-waydroid-launch.sh |' "$f"
        sed -i 's/^NoDisplay=true/NoDisplay=false/' "$f"
        chown phablet:phablet "$f"
        n=$((n + 1))
    done
    if [ -e "$D/Waydroid.desktop" ]; then
        sed -i 's|^Exec=waydroid show-full-ui|Exec=/usr/local/bin/a50-waydroid-launch.sh --full-ui|' "$D/Waydroid.desktop"
        chown phablet:phablet "$D/Waydroid.desktop"
    fi
    echo "waydroid: fixed $n app entries (visible + working Exec)"
fi

# ---------------------------------------------------------------------------
# 9. Camera app: the SONAME it was built against.
#
# REAL FIX: none needed here - libexiv2-27-compat is a real UBports package for
# 26.04 that exists precisely for this.
#
# 26.04 ships libexiv2.so.28, but camera.ubports 4.1.1 was built against
# libexiv2.so.27. Its QML plugin therefore fails to load:
#
#   plugin cannot be loaded for module "CameraApp": Cannot load library
#   .../CameraApp/libcamera-qml.so: (libexiv2.so.27: cannot open shared object
#   file: No such file or directory)
#
# and the app sits on a spinner forever with no visible error. Same class as
# the OpenStore SONAME problem in docs/device-provisioning.md.
#
# See docs/experiments/014-camera.md.
# ---------------------------------------------------------------------------
if [ -e /usr/share/click/preinstalled/camera.ubports ]; then
    if [ -e /usr/lib/aarch64-linux-gnu/libexiv2.so.27 ]; then
        echo "camera: libexiv2.so.27 already present"
    else
        # apt's _apt sandbox user cannot resolve DNS on this device.
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            -o APT::Sandbox::User=root -o Acquire::ForceIPv4=true \
            libexiv2-27-compat >/dev/null 2>&1 \
            && echo "camera: installed libexiv2-27-compat" \
            || echo "camera: could not install libexiv2-27-compat (no network?)" >&2
    fi
fi

sync
echo "done."
