#!/usr/bin/env python3
"""Fail if Waydroid's foreground_pipe() leaks descriptors (waydroid/waydroid#2357).

Usage: test-waydroid-foreground-pipe-fds.py PATH/TO/tools/helpers/run_core.py
Runs the real function 200 times with the cyclic GC disabled, as in the idle
container daemon, and requires a stable open-descriptor count. Linux only.
"""
import gc
import importlib.util
import os
import sys
import types

# run_core imports tools.helpers.run; foreground_pipe does not use it.
for name in ('tools', 'tools.helpers', 'tools.helpers.run'):
    sys.modules.setdefault(name, types.ModuleType(name))
spec = importlib.util.spec_from_file_location('run_core', sys.argv[1])
run_core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run_core)

args = types.SimpleNamespace(timeout=10)
gc.disable()
before = len(os.listdir('/proc/self/fd'))
for _ in range(200):
    code, _ = run_core.foreground_pipe(args, ['true'])
    assert code == 0
after = len(os.listdir('/proc/self/fd'))
print(f'open fds before={before} after={after}')
if after - before > 2:
    sys.exit('FAIL: foreground_pipe leaks descriptors')
print('PASS: no descriptor growth')
