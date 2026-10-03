#!/bin/sh
# Check the actual users that allocate buffers, without reading GPU devices.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run as root.' >&2; exit 1; }
for user in phablet lightdm; do
    runuser -u "$user" -- python3 -c '
import os
fd = os.open("/dev/ion", os.O_RDWR | os.O_CLOEXEC)
os.close(fd)
print(os.getuid(), "ION open passed")
'
done
