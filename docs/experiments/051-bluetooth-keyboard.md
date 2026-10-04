# Bluetooth keyboard: aa17 first input validation

4 October 2026. The user initially saw no devices in Bluetooth Settings, then
successfully paired the K380 and confirmed that keyboard input works. Before
this fresh kernel, the user reported spontaneous keyboard disconnections.
This is a first input check, not a completed idle/sleep/reconnect validation.

## Evidence

BlueZ remained running with zero service restarts. A bounded, private system-bus
observer recorded Settings' successful StartDiscovery calls and discovery
signals. No discovery error was captured. Settings stopped its discovery
sessions between scans; `Discovering=false` after leaving that page is not
alone a failed scan. The earlier transient empty list has no proven cause.

Pairing began at 10:39:24 Berlin; Connected=true followed at 10:39:25. The
observer captured no subsequent keyboard Connected=false before its seven-minute
deadline. It was then stopped and its expected timeout failure state cleared.
No key events or typed content were read. Raw Bluetooth addresses/logs stay private.
After that observer ended, the keyboard input device disappeared at 10:43:36.
The user confirmed switching the keyboard off or changing its selected device;
this event is explained and is not counted as a spontaneous disconnect. The
keyboard later reconnected and its Linux input device returned. Further user
typing/idle validation is still required.

The resulting device has Paired=true, Connected=true, ServicesResolved=true,
the standard HID UUID and Input1 ReconnectMode=device. `/proc/bus/input/devices`
contains Keyboard K380 with keyboard/LED handlers and event9. The user confirms
typing works. aa16/aa17 include the conventional RFCOMM/BNEP/HIDP build correction;
this successful input test follows that correction, but does not establish that
missing RFCOMM alone caused the old keyboard failures.

BlueZ also logged an unsupported device-flags command and a HIDP connection-info
warning. Neither prevented this observed pairing/input. Do not hide these or
apply a speculative driver change; correlate them with any actual failure.

## Reproduction and upstream comparison

Use Settings → Bluetooth to scan and pair a keyboard in pairing mode. In
Terminal, type a harmless line without executing it. Leave the keyboard idle
for two minutes and type again; then test keyboard power-off/on reconnection,
phone suspend/resume, and a full phone reboot. Confirm input after each event.

`scripts/experiments/check-bluetooth-keyboard.sh` reads only BlueZ state and
input-device metadata. It does not pair devices, restart services, collect keys,
change permissions, or force scans. Save diagnostic output privately.

The [BlueZ Adapter API](https://github.com/bluez/bluez/blob/master/doc/org.bluez.Adapter.rst)
documents discovery sessions and their client lifetime. Existing UBports
[pairing-agent issue 2238](https://gitlab.com/ubports/development/ubuntu-touch/-/issues/2238)
was checked: it concerns older Settings pairing-agent behavior. This attempt
paired successfully, so that issue is not evidence to deploy an unrelated fix.

The original idle disconnect problem, the initial empty-list observation, and
reconnect/suspend/reboot behavior remain open. No Bluetooth configuration or
package change was made during this test. The previously published kernel
build/flash/protocol tests reproduce the source correction.
