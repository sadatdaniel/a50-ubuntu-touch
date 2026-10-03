#!/bin/sh
# Test the upstream source correction until reboot; original image files stay intact.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run: sudo.ws sh fix'; exit 1; }
bundle=/home/phablet/a50-recording-test
cd "$bundle"
sha256sum -c SHA256SUMS
check() { printf '%s  %s\n' "$1" "$2" | sha256sum -c -; }
check 10d7fa4bdb95005f855520aa797d2ae31e68c231df94d9de9f2fd6714ee9a719 lib/libaudioclient.so
check 3851b31f6c254f91a97e6b2c3a3aae71559abf2b83c3a78ebc19abb9b4b456fe lib64/libaudioclient.so
test "$(timeout 8 lxc-attach -n android -- /system/bin/getprop ro.build.version.sdk)" = 30
timeout 8 lxc-attach -n android -- /system/bin/sha256sum /system/lib/libaudioclient.so /system/lib64/libaudioclient.so > "$bundle/original.sha256"
grep -qx '61ccb6554dcef9fdc30099a88d3c7773901e616aeefccc1845d8045d56d1e89d  /system/lib/libaudioclient.so' "$bundle/original.sha256"
grep -qx 'ddcdf2a8e68eae5a01f91f1ab92e4175205ed38f31f0aec76e513e0992fa91f6  /system/lib64/libaudioclient.so' "$bundle/original.sha256"
umask 077
stage=$(mktemp -d /android/data/local/tmp/a50-recording-lib.XXXXXX)
android_stage=/data/local/tmp/${stage##*/}
lib_bound=0
lib64_bound=0
keep=0
cleanup() {
    if [ "$keep" = 0 ]; then
        if [ "$lib64_bound" = 1 ]; then timeout 8 lxc-attach -n android -- /system/bin/umount /system/lib64/libaudioclient.so; fi
        if [ "$lib_bound" = 1 ]; then timeout 8 lxc-attach -n android -- /system/bin/umount /system/lib/libaudioclient.so; fi
        rm -rf "$stage"
    fi
}
trap cleanup EXIT
mkdir "$stage/lib" "$stage/lib64"
install -m 0644 lib/libaudioclient.so "$stage/lib/"
install -m 0644 lib64/libaudioclient.so "$stage/lib64/"
timeout 8 lxc-attach -n android -- /system/bin/mount --bind "$android_stage/lib/libaudioclient.so" /system/lib/libaudioclient.so
lib_bound=1
timeout 8 lxc-attach -n android -- /system/bin/mount --bind "$android_stage/lib64/libaudioclient.so" /system/lib64/libaudioclient.so
lib64_bound=1
timeout 8 lxc-attach -n android -- /system/bin/sha256sum /system/lib/libaudioclient.so /system/lib64/libaudioclient.so > "$bundle/active.sha256"
grep -qx '10d7fa4bdb95005f855520aa797d2ae31e68c231df94d9de9f2fd6714ee9a719  /system/lib/libaudioclient.so' "$bundle/active.sha256"
grep -qx '3851b31f6c254f91a97e6b2c3a3aae71559abf2b83c3a78ebc19abb9b4b456fe  /system/lib64/libaudioclient.so' "$bundle/active.sha256"
timeout 8 lxc-attach -n android -- /system/bin/setprop ctl.restart camera_service
count=0
while [ "$(timeout 8 lxc-attach -n android -- /system/bin/getprop init.svc.camera_service)" != running ]; do
    count=$((count + 1)); test "$count" -lt 10; sleep 1
done
keep=1
printf '%s\n' "$stage" > "$bundle/staging-path.txt"
echo 'Recording library test ready. Reboot removes this temporary test; original image files are intact.'
