set -eu
D=/userdata/a50-session20-release
test -f "$D/capture-kmsg.py"
test ! -e "$D/kmsg-capture-before-20260922.log"
python3 -m py_compile "$D/capture-kmsg.py"
cp -p /userdata/a50-kmsg-capture.sh "$D/a50-kmsg-capture.sh.before-rotation"
systemctl stop a50-kmsg-capture.service
mv /userdata/kmsg-capture.log "$D/kmsg-capture-before-20260922.log"
chmod 0600 "$D/kmsg-capture-before-20260922.log"
printf '#!/bin/sh\nexec /usr/bin/python3 /userdata/a50-session20-release/capture-kmsg.py\n' > /userdata/a50-kmsg-capture.sh
chmod 0755 /userdata/a50-kmsg-capture.sh
systemctl start a50-kmsg-capture.service
systemctl is-active a50-kmsg-capture.service
for attempt in 1 2 3 4 5; do
  test ! -f /userdata/kmsg-capture.log || break
  sleep 1
done
ls -lh /userdata/kmsg-capture.log "$D/kmsg-capture-before-20260922.log"
