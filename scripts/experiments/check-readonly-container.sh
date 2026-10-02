#!/bin/sh
set -eu
test "$(cat /proc/sys/kernel/random/boot_id)" = "$(cat /userdata/a50-session29-aa12/expected-boot-id)"
systemctl is-active --quiet a50-test-awake.service
mkdir -p /run/a50-android
unshare --mount --propagation private /bin/sh <<'NS'
set -eu
B=/var/lib/lxc/android
P=/userdata/a50-session29-aa12
chmod 0755 "$P/a50-gen-mixer-paths.py"
mount -t tmpfs -o mode=755 tmpfs /run/a50-android
mount --bind "$B" "$B"
mount -o remount,bind,ro "$B"
mount --bind "$P/a50-gen-mixer-paths.py" /usr/local/bin/a50-gen-mixer-paths.py
before=$(sha256sum "$B/mount.sh" | cut -d' ' -f1)
sh -n "$P/a50-container-prepare.sh"
sh "$P/a50-container-prepare.sh"
for f in init.exynos9610.rc.nowatchdog init.disabled.rc.audiofix mixer_paths.a50.xml vndservicemanager.rc.selinux-stubs; do
    test -s "/run/a50-android/$f"
done
mountpoint -q "$B/mount.sh"
test "$B/mount.sh" -ef /run/a50-android/mount.sh
grep -q '^\. /var/lib/lxc/android/a50-mount-hooks.sh$' "$B/mount.sh"
sh "$P/a50-container-prepare.sh"
test "$(grep -c '^\. /var/lib/lxc/android/a50-mount-hooks.sh$' "$B/mount.sh")" = 1
umount "$B/mount.sh"
test "$before" = "$(sha256sum "$B/mount.sh" | cut -d' ' -f1)"
echo READONLY_CONTAINER_PREPARATION=PASS
NS
test ! -e /run/a50-android/mount.sh
echo LIVE_MOUNT_NAMESPACE_UNCHANGED=PASS
