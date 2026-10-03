#!/bin/sh
# Test the image drop-in reversibly without changing the root mount or timer.
set -eu
[ "$(id -u)" = 0 ]
[ "$(findmnt -T /var/backups -n -o OPTIONS | cut -d, -f1)" = ro ]
p=/run/systemd/system/dpkg-db-backup.service.d/a50-readonly.conf
[ ! -e "$p" ]
install -d -m 0755 "${p%/*}"
printf '[Unit]\nConditionPathIsReadWrite=/var/backups\n' > "$p"
systemctl daemon-reload
systemctl reset-failed dpkg-db-backup.service
systemctl start dpkg-db-backup.service
[ "$(systemctl show dpkg-db-backup.service -p ConditionResult --value)" = no ]
[ "$(systemctl show dpkg-db-backup.service -p Result --value)" = success ]
printf 'READONLY_BACKUP_SKIP=PASS\nRuntime test only; image overlay carries the final drop-in.\n'
