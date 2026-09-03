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

sync
echo "done."
