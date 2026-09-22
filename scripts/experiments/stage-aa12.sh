set -eu
B=/userdata/a50-session20-aa12
test "$(cat /proc/sys/kernel/random/boot_id)" = 6b93e24d-7f24-4774-ba15-4ecb8630581f
test "$(readlink -f /dev/disk/by-partlabel/boot)" = /dev/sda14
test "$(blockdev --getsize64 /dev/sda14)" = 57671680
test "$(sha256sum "$B/boot-aa12.img" | cut -d ' ' -f1)" = 795e8b7fffda6b46e318d1bccc542b3a7d807987a7787f5115f0dcb27b7b9dcb
test "$(stat -c %s "$B/boot-aa12.img")" = 55851008
test "$(sha256sum /userdata/boot-aa1.img | cut -d ' ' -f1)" = c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
test "$(head -c 55785472 /dev/sda14 | sha256sum | cut -d ' ' -f1)" = c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703
test -f /userdata/a50-session20-release/image-restored
mount -o remount,rw /
trap 'mount -o remount,ro /' EXIT
install -m 0644 "$B/aa12-restore.service" /etc/systemd/system/a50-test-restore-boot.service
systemctl daemon-reload
systemctl enable a50-test-restore-boot.service
systemctl is-enabled --quiet a50-test-restore-boot.service
dd if="$B/boot-aa12.img" of=/dev/sda14 bs=4M conv=fsync
test "$(head -c 55851008 /dev/sda14 | sha256sum | cut -d ' ' -f1)" = 795e8b7fffda6b46e318d1bccc542b3a7d807987a7787f5115f0dcb27b7b9dcb
mount -o remount,ro /
trap - EXIT
sync
echo 'aa12 read-back verified, fallback guard enabled; rebooting'
systemctl reboot
