#!/sbin/sh
# Offline repair of the existing Ubuntu image; never writes vendor or recovery.
set -eu
test "$(id -u)" = 0
image=/data/ubuntu.img
backup=/data/ubuntu.before-compatibility-20261003.img
verified=$backup.verified
root=/tmp/a50-package-repair-root
bundle=/data/user-data/phablet/a50-validated-compatibility
test -f "$image"
test -d "$bundle/content-hub"
test -d "$bundle/settings"
test -d /data/system-data/var/lib/extrausers
test ! -e "$root"
if [ ! -e "$backup" ]; then
    echo 'Backing up the current Ubuntu image on userdata.'
    cp -p "$image" "$backup"
    cmp "$image" "$backup"
    touch "$verified"
else
    echo 'Existing backup retained; refusing to overwrite it.'
    test -f "$verified"
    test "$(stat -c '%s' "$backup")" = "$(stat -c '%s' "$image")"
fi
mkdir -p "$root"
root_mounted=0
home_mounted=0
extra_mounted=0
logs_mounted=0
dev_mounted=0
proc_mounted=0
sys_mounted=0
policy_created=0
cleanup() {
    if [ "$policy_created" = 1 ]; then rm -f "$root/usr/sbin/policy-rc.d"; fi
    sync
    if [ "$sys_mounted" = 1 ]; then umount "$root/sys"; fi
    if [ "$proc_mounted" = 1 ]; then umount "$root/proc"; fi
    if [ "$dev_mounted" = 1 ]; then umount "$root/dev"; fi
    if [ "$logs_mounted" = 1 ]; then umount "$root/var/log"; fi
    if [ "$extra_mounted" = 1 ]; then umount "$root/var/lib/extrausers"; fi
    if [ "$home_mounted" = 1 ]; then umount "$root/home"; fi
    if [ "$root_mounted" = 1 ]; then umount "$root"; fi
    rmdir "$root"
}
trap cleanup EXIT
mount -o loop,rw "$image" "$root"
root_mounted=1
grep -qx 'VERSION_ID="26.04"' "$root/etc/os-release"
mount --bind /data/user-data "$root/home"
home_mounted=1
mount --bind /data/system-data/var/lib/extrausers "$root/var/lib/extrausers"
extra_mounted=1
mount --bind /data/system-data/var/log "$root/var/log"
logs_mounted=1
mount --bind /dev "$root/dev"
dev_mounted=1
mount --bind /proc "$root/proc"
proc_mounted=1
mount --bind /sys "$root/sys"
sys_mounted=1
# Standard Debian chroot policy: package installation must not start services.
if [ ! -e "$root/usr/sbin/policy-rc.d" ] && [ ! -L "$root/usr/sbin/policy-rc.d" ]; then
    printf '#!/bin/sh\nexit 101\n' > "$root/usr/sbin/policy-rc.d"
    chmod 755 "$root/usr/sbin/policy-rc.d"
    policy_created=1
fi
cp "$bundle/repair-compatibility-packages.sh" "$root/tmp/a50-offline-package-repair.sh"
DEBIAN_FRONTEND=noninteractive chroot "$root" /bin/sh /tmp/a50-offline-package-repair.sh --offline
rm -f "$root/tmp/a50-offline-package-repair.sh"
echo 'Offline package repair passed; credentials and vendor were preserved.'
