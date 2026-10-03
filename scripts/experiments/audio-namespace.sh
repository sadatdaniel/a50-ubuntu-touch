#!/bin/sh
# Restore the earlier A50 HIDL wrapper's system namespace in the user service.
set -eu
[ "$(id -u)" = 32011 ] || { echo 'Run as phablet, without sudo'; exit 1; }
export XDG_RUNTIME_DIR=/run/user/32011
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus
dir=/home/phablet/.config/systemd/user/pulseaudio.service.d
file=$dir/zz-a50-hybris.conf
mkdir -p "$dir"
[ ! -L "$file" ]
if [ -e "$file" ]; then
    echo 'Existing override found; review before replacing it.'
    exit 1
fi
umask 077
printf '[Service]\nUnsetEnvironment=HYBRIS_USE_VENDOR_NAMESPACE\n' > "$file"
systemctl --user daemon-reload
systemctl --user restart pulseaudio.service
sleep 3
pactl list short sinks
pactl set-default-sink sink.primary-out
for stream in $(pactl list short sink-inputs | awk '{print $1}'); do
    pactl move-sink-input "$stream" sink.primary-out
done
pid=$(pidof pulseaudio)
grep -E 'audio.hidl_compat|libaudiohal' /proc/"$pid"/maps | head -n 12
ls -l /proc/"$pid"/fd | grep hwbinder
echo 'Please reopen YouTube and test sound.'
