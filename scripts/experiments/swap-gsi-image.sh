#!/bin/sh
# Replace the Halium GSI system image inside the installed rootfs, reversibly.
# Usage (root): swap-gsi-image.sh NEW_IMG NEW_SHA256 CURRENT_SHA256 BACKUP_PATH
# Refuses unless the installed image hashes to CURRENT_SHA256. The current image
# is copied to BACKUP_PATH first (verified), so rollback is the same script with
# the backup as NEW_IMG. Takes effect on the next reboot.
set -eu
new=$1 want=$2 cur=$3 backup=$4
dst=/var/lib/lxc/android/android-rootfs.img
sha() { sha256sum "$1" | cut -d ' ' -f1; }
test "$(sha "$new")" = "$want"
test "$(sha "$dst")" = "$cur" || { echo 'E: installed GSI is not the expected image' >&2; exit 1; }
if [ ! -e "$backup" ]; then
    mkdir -p "$(dirname "$backup")"
    cp "$dst" "$backup"
fi
test "$(sha "$backup")" = "$cur" || [ "$(sha "$backup")" = "$want" ] || { echo 'E: backup does not match' >&2; exit 1; }
mount -o remount,rw /
# Busy services can block the read-only remount; the next reboot mounts / RO anyway.
finish() { sync; mount -o remount,ro / || echo 'W: / stays rw until reboot' >&2; }
trap finish EXIT
cp "$new" "$dst.new"
test "$(sha "$dst.new")" = "$want"
chmod 0664 "$dst.new"
mv "$dst.new" "$dst"
sync
test "$(sha "$dst")" = "$want"
echo "GSI image replaced ($want); reboot to use it"
