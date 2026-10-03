#!/bin/sh
# Reversible test of the standard missing-log setting on the immutable image.
set -eu
[ "$(id -u)" = 0 ]
target=/etc/logrotate.d/touch-syslog
[ "$(sha256sum "$target" | cut -d' ' -f1)" = b57bf95c313e0137946f47797d76d8bcb7084a114ecdaf30ca6f9683826c88e1 ]
! mountpoint -q "$target"
stage=$(mktemp -d /run/a50-logrotate.XXXXXX)
mounted=false
cleanup() {
    if [ "$mounted" = true ]; then umount "$target"; fi
    rm -f "$stage/touch-syslog" "$stage/debug.log"
    rmdir "$stage"
}
trap cleanup EXIT HUP INT TERM
sed '/^\/var\/log\/syslog {/a\    missingok
/^\/var\/log\/auth.log {/a\    missingok' "$target" > "$stage/touch-syslog"
[ "$(sha256sum "$stage/touch-syslog" | cut -d' ' -f1)" = 9705f696066c9bf19e455c16e129466b0799f45bb590f308c93596f52a543f33 ]
mount --bind "$stage/touch-syslog" "$target"
mounted=true
/usr/sbin/logrotate --debug /etc/logrotate.conf > "$stage/debug.log" 2>&1
systemctl reset-failed logrotate.service
systemctl start logrotate.service
[ "$(systemctl show logrotate.service -p Result --value)" = success ]
trap - EXIT HUP INT TERM
printf 'LOGROTATE_OPTIONAL_LOGS=PASS\nRuntime configuration: %s\nReboot restores the original; the image overlay carries the final setting.\n' "$stage"
