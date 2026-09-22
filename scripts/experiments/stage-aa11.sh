set -eu
B=/userdata/a50-session20-aa11
test "$(cat /proc/sys/kernel/random/boot_id)" = 5d40be8b-a600-4c14-b504-7dec6b31b327
test "$(readlink -f /dev/disk/by-partlabel/boot)" = /dev/sda14
test "$(blockdev --getsize64 /dev/sda14)" = 57671680
test "$(sha256sum "$B/boot-aa11.img" | cut -d ' ' -f1)" = 0b227f579e6cb2a64d24753d7c7236103a1159769f3fc355f8e7f52f2bd29e06
test "$(stat -c %s "$B/boot-aa11.img")" = 55851008
test "$(sha256sum /userdata/boot-aa1.img | cut -d ' ' -f1)" = c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
test "$(head -c 55785472 /dev/sda14 | sha256sum | cut -d ' ' -f1)" = c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
test -f /userdata/a50-session20-release/image-restored
mount -o remount,rw /
trap 'mount -o remount,ro /' EXIT
install -m 0644 "$B/aa11-restore.service" /etc/systemd/system/a50-test-restore-boot.service
systemctl daemon-reload
systemctl enable a50-test-restore-boot.service
systemctl is-enabled --quiet a50-test-restore-boot.service
dd if="$B/boot-aa11.img" of=/dev/sda14 bs=4M conv=fsync
test "$(head -c 55851008 /dev/sda14 | sha256sum | cut -d ' ' -f1)" = 0b227f579e6cb2a64d24753d7c7236103a1159769f3fc355f8e7f52f2bd29e06
mount -o remount,ro /
trap - EXIT
sync
echo 'aa11 read-back verified, fallback guard enabled; rebooting'
systemctl reboot
