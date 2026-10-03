#!/bin/sh
# Read-only camera stop diagnostics. No media contents or credentials collected.
set -eu
test "$(id -u)" = 0
umask 077
exec 3>&1
out=/home/phablet/cam.log
test ! -L "$out"
exec > "$out" 2>&1
date -Is
echo '=== camera threads ==='
pid=$(pgrep -x lomiri-camera-a || true)
if [ -n "$pid" ]; then
    ps -L -p "$pid" -o pid,tid,stat,comm,wchan:40
    for task in /proc/"$pid"/task/*; do
        printf '\n%s\n' "$task"
        cat "$task/stack" 2>/dev/null || true
    done
fi
echo '=== Android camera/recorder/audio logs ==='
timeout 12 lxc-attach -n android -- /system/bin/logcat -d -v threadtime -t 1800 \
    CameraService:V CameraClient:V MediaRecorder:V StagefrightRecorder:V \
    MPEG4Writer:V ACodec:V OMXNodeInstance:V AudioRecord:V AudioFlinger:V \
    AudioPolicyManager:V ExynosCamera:V AudioRecordHybris:V MediaRecorderClient:V '*:S' || true
echo '=== Android recording helper native backtrace ==='
timeout 12 lxc-attach -n android -- /system/bin/sh -c 'pid=$(pidof camera_service); test -n "$pid" && debuggerd -b "$pid"' || true
echo '=== Android media and camera state ==='
for service in media.camera media.player media.audio_flinger; do
    echo "$service"
    timeout 8 lxc-attach -n android -- /system/bin/dumpsys "$service" || true
done
echo '=== Android media service native backtrace ==='
timeout 12 lxc-attach -n android -- /system/bin/sh -c 'pid=$(pidof minimediaservice); test -n "$pid" && debuggerd -b "$pid"' || true
echo '=== recent kernel camera, binder and policy warnings ==='
dmesg | tail -n 1200 | grep -Ei 'camera|fimc|binder|apparmor.*DENIED|mfc|codec|audio|abox' | tail -n 150 || true
chown phablet:phablet "$out"
chmod 600 "$out"
echo 'Camera diagnostics complete.' >&3
