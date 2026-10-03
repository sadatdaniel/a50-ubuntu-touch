#!/bin/bash
set -euo pipefail
mkdir -p /tmp/probe-root/usr/libexec/lxc-android-config
cp /task/clean-mount-android-partitions /tmp/probe-root/usr/libexec/lxc-android-config/mount-android-partitions
python3 /repo/scripts/release/fix-partition-probe.py /tmp/probe-root
python3 /repo/scripts/release/fix-partition-probe.py /tmp/probe-root
python3 - <<'PY'
from pathlib import Path
import subprocess
s = Path('/tmp/probe-root/usr/libexec/lxc-android-config/mount-android-partitions').read_text()
block = s[s.index('if [ -d /sys/fs/cgroup/schedtune ]; then'):s.index('# Handle devices using binderfs.')]
# Exercise the actual block: emulate a kernel that refuses nested groups.
block = block.replace('/sys/fs/cgroup/schedtune', '/tmp/probe-cgroup')
Path('/tmp/probe-cgroup').mkdir(exist_ok=True)
fixture = 'mkdir() { return 1; }; umount() { echo UNMOUNTED; }; set -eu;\n' + block
result = subprocess.run(['bash', '-c', fixture], capture_output=True, text=True)
assert result.returncode == 0, result.stderr
assert result.stdout.strip() == 'UNMOUNTED', result.stdout
print('UNSUPPORTED_SCHEDTUNE_FALLBACK=PASS')
PY
