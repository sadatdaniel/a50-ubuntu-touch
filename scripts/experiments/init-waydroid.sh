#!/bin/sh
# Fresh A50 setup using the installed UBports initializer; no forced reset.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run through normal administrator authentication.' >&2; exit 1; }
if [ -e /var/lib/waydroid/waydroid.cfg ]; then
    [ -d /var/lib/waydroid/rootfs ] || { echo 'Incomplete initialization; inspect waydroid log before retrying.' >&2; exit 1; }
    echo 'Already initialized; leaving existing images and user data unchanged.'
    exec waydroid status
fi
[ "$(getprop ro.vndk.version)" = 30 ] || { echo 'Expected the A50 Android 11 vendor base.' >&2; exit 1; }
for node in binder hwbinder vndbinder; do
    [ -c "/dev/anbox-$node" ] || { echo "Missing /dev/anbox-$node" >&2; exit 1; }
done
python3 - <<'PY'
import os, shutil
assert os.stat('/var/lib/waydroid').st_dev == os.stat('/userdata').st_dev, 'Waydroid must use userdata storage'
assert shutil.disk_usage('/var/lib/waydroid').free > 8 * 1024**3, 'Need at least 8 GiB free in userdata'
PY
exec waydroid init
