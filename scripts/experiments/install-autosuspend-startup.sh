#!/bin/sh
# Install the exact already tested device-overlay startup files on the test phone.
set -eu
test "$(id -u)" = 0
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
test "$(cat /sys/class/power_supply/usb/online)" = 1
stage=/userdata/a50-20261010-check
cd "$stage"
sha256sum -c <<'HASHES'
6dc44a3feddbbcedb5fe9775b598bbaf8b83a8c5f64ee5c04defe45792fba6a4  a50-enable-autosuspend.sh
49727b196b553c2ae97f76c0f48ed03c6980717d0aa1fcb676946f2be8731763  a50-enable-autosuspend.service
HASHES
test ! -e /usr/local/bin/a50-enable-autosuspend.sh
test ! -e /etc/systemd/system/a50-enable-autosuspend.service
test ! -e /run/systemd/system/a50-enable-autosuspend.service
test ! -e /etc/systemd/system/repowerd.service.wants/a50-enable-autosuspend.service
test "$(timeout 8 lxc-attach -n android -- /system/bin/getprop ro.build.version.sdk)" = 30
systemctl is-active --quiet repowerd.service
mount -o remount,rw /
finish() {
    sync
    mount -o remount,ro / || echo 'A full reboot is needed to restore read-only root.' >&2
}
trap finish EXIT
install -o root -g root -m 0755 a50-enable-autosuspend.sh /usr/local/bin/a50-enable-autosuspend.sh
install -o root -g root -m 0644 a50-enable-autosuspend.service /etc/systemd/system/a50-enable-autosuspend.service
install -d -o root -g root -m 0755 /etc/systemd/system/repowerd.service.wants
ln -s ../a50-enable-autosuspend.service /etc/systemd/system/repowerd.service.wants/a50-enable-autosuspend.service
systemd-analyze verify /etc/systemd/system/a50-enable-autosuspend.service
systemctl daemon-reload
systemctl start a50-enable-autosuspend.service
systemctl is-active --quiet a50-enable-autosuspend.service
systemctl show a50-enable-autosuspend.service -p ActiveState -p Result -p ExecMainStatus
echo 'Published startup files installed; cold-boot and unplugged validation remain.'
