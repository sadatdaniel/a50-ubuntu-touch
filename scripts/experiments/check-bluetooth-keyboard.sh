#!/bin/sh
# Connection/input metadata only: never open an input event device.
set -eu
date -Is
python3 - <<'PY'
from pathlib import Path
import dbus
bus = dbus.SystemBus()
objects = dbus.Interface(bus.get_object('org.bluez', '/'),
                         'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
names = []
for interfaces in objects.values():
    adapter = interfaces.get('org.bluez.Adapter1')
    if adapter:
        print('Adapter:', {k: bool(adapter.get(k)) for k in ('Powered', 'Discovering')})
    device = interfaces.get('org.bluez.Device1')
    if device and any(str(u).startswith(('00001124-', '00001812-')) for u in device.get('UUIDs', [])):
        name = str(device.get('Name', 'unnamed HID device'))
        names.append(name)
        print('HID:', name, {k: bool(device.get(k)) for k in ('Paired', 'Connected', 'ServicesResolved')})
        print('ReconnectMode:', str(interfaces.get('org.bluez.Input1', {}).get('ReconnectMode', 'not exported')))
for block in Path('/proc/bus/input/devices').read_text().split('\n\n'):
    if any(f'N: Name="{name}"' in block for name in names):
        print('\n'.join(line for line in block.splitlines() if line.startswith(('N:', 'H:'))))
if not names:
    print('No discovered HID device; put the keyboard in pairing mode and open Bluetooth settings.')
PY
