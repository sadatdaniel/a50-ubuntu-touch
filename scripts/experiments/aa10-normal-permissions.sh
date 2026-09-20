#!/bin/sh
set -eu
test "$(cat /sys/module/apparmor/parameters/enabled)" = Y
mkdir -p /run/systemd/system/biometryd.service.d /run/systemd/system/lomiri-location-service.service.d
printf '[Service]\nUnsetEnvironment=BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING\n' > /run/systemd/system/biometryd.service.d/99-a50-enforce.conf
printf '[Service]\nUnsetEnvironment=TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING\n' > /run/systemd/system/lomiri-location-service.service.d/99-a50-enforce.conf
systemctl daemon-reload
systemctl restart biometryd lomiri-location-service
systemctl is-active biometryd lomiri-location-service
python3 - <<'PY'
from pathlib import Path
import subprocess
for unit, key in [('biometryd', b'BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING='),
                  ('lomiri-location-service', b'TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING=')]:
    pid = subprocess.check_output(['systemctl', 'show', unit, '-p', 'MainPID', '--value']).decode().strip()
    entries = Path('/proc', pid, 'environ').read_bytes().split(b'\0')
    assert not any(e.startswith(key) for e in entries), unit + ' still bypasses permissions'
    print(unit + ': running with testing bypass absent')
PY
