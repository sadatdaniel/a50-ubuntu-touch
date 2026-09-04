#!/bin/sh
# Re-apply the runtime workarounds this port needs, after a rootfs reflash.
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

# The droid HAL accepts writes and returns success, but nothing ever reaches
# the ABOX hardware - no RDMA trigger, no UAIF activity, silence. Raw ALSA on
# hw:0,0 works once ABOX is routed, so drive the card directly with a native
# ALSA sink and make it the default. The droid card stays loaded: it still owns
# voice call and mode switching, which have no ALSA equivalent here. Stopgap for
# media playback, not a replacement for the HAL.
# See docs/experiments/007-abox-firmware-too-early.md.
if ! grep -q 'a50_speaker' /etc/pulse/touch.pa; then
    [ -f /etc/pulse/touch.pa.a50-orig ] || cp /etc/pulse/touch.pa /etc/pulse/touch.pa.a50-orig
    cat >> /etc/pulse/touch.pa <<'EOS'

### A50: native ALSA sink for the speaker (see a50-audio-route.service).
.ifexists module-alsa-sink.so
.nofail
load-module module-alsa-sink device=hw:0,0 sink_name=a50_speaker sink_properties="device.description='Speaker'" rate=48000 channels=2 format=s16le
set-default-sink a50_speaker
.fail
.endif
EOS
    echo "audio: touch.pa ALSA sink added (restart pulseaudio to apply)"
else
    echo "audio: touch.pa ALSA sink already present"
fi

sync
echo "done."
