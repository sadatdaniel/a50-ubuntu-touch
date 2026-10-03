#!/usr/bin/env python3
"""Correct the known upstream NBSP before the schedtune fallback command."""
from pathlib import Path
import sys

p = Path(sys.argv[1]) / 'usr/libexec/lxc-android-config/mount-android-partitions'
s = p.read_text()
bad = 'mkdir /sys/fs/cgroup/schedtune/probe0 ||\u00a0true'
good = 'mkdir /sys/fs/cgroup/schedtune/probe0 || true'
if bad in s:
    assert s.count(bad) == 1, 'Unexpected duplicate schedtune probe'
    p.write_text(s.replace(bad, good))
    print('Corrected upstream schedtune fallback whitespace')
else:
    assert good in s, 'Partition probe changed; review before building'
    print('Upstream schedtune fallback already corrected')
