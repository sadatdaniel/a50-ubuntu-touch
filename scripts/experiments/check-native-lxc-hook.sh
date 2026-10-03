#!/bin/bash
set -euo pipefail
[ -f /.dockerenv ] || { echo 'Run only in the documented disposable test container.' >&2; exit 1; }
mkdir -p /var/lib/lxc/android /run/a50-android /android/vendor /android/system /tmp/hook-root/bin /tmp/hook-root/dev /tmp/hook-root/proc
cp /bin/busybox /tmp/hook-root/bin/busybox
[ -e /tmp/hook-root/dev/null ] || mknod /tmp/hook-root/dev/null c 1 3
cat > /var/lib/lxc/android/config <<'CONF'
lxc.rootfs.path = /tmp/hook-root
lxc.uts.name = hook-check
lxc.net.0.type = none
lxc.apparmor.profile = unconfined
lxc.autodev = 0
lxc.console.path = none
lxc.pty.max = 0
lxc.tty.max = 0
lxc.hook.mount = /var/lib/lxc/android/mount.sh
CONF
cat > /var/lib/lxc/android/mount.sh <<'HOOK'
#!/bin/sh
echo upstream >> /tmp/hook-order
HOOK
cat > /var/lib/lxc/android/a50-mount-hooks.sh <<'HOOK'
echo a50 >> /tmp/hook-order
HOOK
chmod 755 /var/lib/lxc/android/mount.sh
mount -t tmpfs -o noexec,nosuid,mode=755 tmpfs /run/a50-android
mount --bind /var/lib/lxc/android /var/lib/lxc/android
mount -o remount,bind,ro /var/lib/lxc/android
config_before=$(sha256sum /var/lib/lxc/android/config)
hook_before=$(sha256sum /var/lib/lxc/android/mount.sh)
sh -n /repo/overlay/system/usr/local/bin/a50-container-prepare.sh
sh /repo/overlay/system/usr/local/bin/a50-container-prepare.sh
sh /repo/overlay/system/usr/local/bin/a50-container-prepare.sh
test /var/lib/lxc/android/config -ef /run/a50-android/config
test "$(grep -c a50-mount-hooks.sh /var/lib/lxc/android/config)" = 1
test "$hook_before" = "$(sha256sum /var/lib/lxc/android/mount.sh)"
findmnt -no OPTIONS /run/a50-android | grep -qw noexec
lxc-info -n android -c lxc.hook.mount
# Start a tiny isolated root so liblxc itself executes both configured hooks.
rm -f /tmp/hook-order
lxc-start -n android -F -o /tmp/hook-lxc.log -l DEBUG -- /bin/busybox true
test "$(cat /tmp/hook-order)" = "$(printf 'upstream\na50')"
umount /var/lib/lxc/android/config
test "$config_before" = "$(sha256sum /var/lib/lxc/android/config)"
echo 'NATIVE_HOOK_ORDER_WITH_NOEXEC_RUNTIME=PASS'
