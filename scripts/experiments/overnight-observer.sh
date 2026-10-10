#!/bin/sh
# Temporary native startup; private evidence is always retained on stop.
set -eu
umask 077
unit=a50-overnight-observer.service
unit_file=/etc/systemd/system/$unit
test "$(id -u)" = 0
case "${1:-}" in
    start)
        base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
        case "$base" in /userdata/a50-overnight/[0-9]*Z) ;; *) exit 2 ;; esac
        test -f "$base/record-overnight.py"
        test -f "$base/capture-kmsg.py"
        test -f "$base/config.json"
        test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
        test ! -e "$unit_file"
        findmnt -no OPTIONS / | grep -q '^ro,'
        cat > "$base/observer.service" <<EOF
[Unit]
Description=Temporary A50 overnight sleep and crash observation
After=local-fs.target systemd-journald.service
ConditionPathExists=$base/config.json

[Service]
Type=simple
ExecStart=/usr/bin/python3 $base/record-overnight.py $base
Restart=on-failure
RestartSec=30
TimeoutStopSec=45
KillMode=control-group
UMask=0077
Nice=10
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF
        trap 'mount -o remount,ro /' EXIT
        mount -o remount,rw /
        install -o root -g root -m 0644 "$base/observer.service" "$unit_file"
        systemctl daemon-reload
        systemctl enable "$unit"
        mount -o remount,ro /
        trap - EXIT
        systemctl start "$unit"
        count=0
        while ! test -s "$base/ready"; do
            test "$count" -lt 30 || exit 1
            systemctl is-active --quiet "$unit"
            sleep 1
            count=$((count + 1))
        done
        systemctl is-active --quiet "$unit"
        findmnt -no OPTIONS / | grep -q '^ro,'
        echo "Recorder ready: $base"
        ;;
    stop)
        grep -q '^Description=Temporary A50 overnight sleep and crash observation$' "$unit_file"
        systemctl stop "$unit"
        findmnt -no OPTIONS / | grep -q '^ro,'
        trap 'mount -o remount,ro /' EXIT
        mount -o remount,rw /
        systemctl disable "$unit"
        rm -- "$unit_file"
        systemctl daemon-reload
        mount -o remount,ro /
        trap - EXIT
        echo 'Observer removed; private evidence retained.'
        ;;
    status) systemctl show "$unit" -p ActiveState -p SubState -p MainPID -p NRestarts -p Result ;;
    *) exit 2 ;;
esac
