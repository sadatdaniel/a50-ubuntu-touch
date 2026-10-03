#!/bin/sh
# Remove only the duplicate HIDL helper argument supplied by the device overlay.
set -eu
test "$(id -u)" = 0
test -z "$(dpkg --audit)"
config=/etc/deviceinfo/devices/a50.yaml
test ! -L "$config"
grep -Fq "hidl_args='helper=false'" /etc/pulse/touch.pa
test "$(grep -c '^  PulseaudioModulesDroid_ExtraHidlArgs: helper=false$' "$config")" = 1
backup=/home/phablet/a50-validated-compatibility/audio-deviceinfo.before
test ! -e "$backup"
umask 077
cp "$config" "$backup"
mount -o remount,rw /
cleanup() {
    sync
    mount -o remount,ro / || echo 'Root remains writable; a controlled reboot is required.' >&2
}
trap cleanup EXIT
python3 - "$config" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
original = path.read_text()
line = '  PulseaudioModulesDroid_ExtraHidlArgs: helper=false\n'
assert original.count(line) == 1
updated = original.replace(line, '')
assert 'PulseaudioModulesDroid_ExtraHidlArgs:' not in updated
assert 'PulseaudioModulesDroid_ExtraCardArgs: use_legacy_stream_set_parameters=true' in updated
path.write_text(updated)
assert path.read_text() == updated
PY
echo 'Duplicate audio argument removed; private backup saved. Audio restart remains to be checked.'
