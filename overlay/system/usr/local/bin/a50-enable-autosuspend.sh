#!/bin/sh
# Android 11 activation only. SystemSuspend retains wake-lock/count arbitration.
# Run after repowerd has connected to the HIDL SystemSuspend service.
set -eu
sdk=$(timeout 8 lxc-attach -n android -- /system/bin/getprop ro.build.version.sdk)
[ "$sdk" = 30 ] || { echo "Unsupported Android suspend-control ABI: SDK $sdk" >&2; exit 1; }
reply=$(timeout 8 lxc-attach -n android -- /system/bin/service call suspend_control 1)
case "$reply" in
    "Result: Parcel(00000000 00000001"*) echo "Android automatic suspend activated" ;;
    "Result: Parcel(00000000 00000000"*) echo "Android automatic suspend already active" ;;
    *) printf 'Unexpected suspend-control reply: %s\n' "$reply" >&2; exit 1 ;;
esac
