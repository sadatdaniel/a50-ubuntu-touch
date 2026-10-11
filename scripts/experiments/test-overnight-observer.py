"""Linux integration regression: service stop versus unexpected reader exit."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).with_name('record-overnight.py')
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    (root / 'record-overnight.py').write_bytes(source.read_bytes())
    reader = '''#!/usr/bin/env python3
import os, sys, time
from pathlib import Path
Path(os.environ['TEST_DIR'], 'reader-' + str(os.getpid())).write_text(str(os.getpid()))
while True:
    time.sleep(60)
'''
    (root / 'capture-kmsg.py').write_text(reader)
    (root / 'journalctl').write_text(reader)
    (root / 'journalctl').chmod(0o700)
    runner = '''import importlib.util,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('observer',Path(sys.argv[1])/'record-overnight.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.snapshot=lambda: {'boot_id':'test', 'android_state':{'text':'FROZEN'}}
m.main(sys.argv[1])
'''
    for deliberate in (True, False):
        (root / 'config.json').write_text(json.dumps({'until_epoch': time.time() + 60}))
        env = {**os.environ, 'TEST_DIR': str(root), 'PATH': str(root) + ':' + os.environ['PATH']}
        proc = subprocess.Popen([sys.executable, '-c', runner, str(root)], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 5
            while not (root / 'ready').exists() or len(list(root.glob('reader-*'))) != 2:
                assert proc.poll() is None, proc.communicate()[0].decode()
                assert time.monotonic() < deadline, 'observer did not become ready'
                time.sleep(0.01)
            pids = [int(p.read_text()) for p in root.glob('reader-*')]
            if deliberate:
                proc.send_signal(signal.SIGTERM)
                time.sleep(0.05)
                for pid in pids:
                    os.kill(pid, signal.SIGTERM)
            else:
                os.kill(pids[0], signal.SIGTERM)
            output, _ = proc.communicate(timeout=5)
            assert proc.returncode == (0 if deliberate else 1), output.decode()
            assert (root / 'after.json').exists()
            for pid in pids:
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    continue
                raise AssertionError('reader leaked after cleanup')
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.communicate(timeout=5)
            for path in root.glob('reader-*'):
                path.unlink()
            (root / 'ready').unlink(missing_ok=True)
print('Observer deliberate stop, unexpected reader failure and cleanup passed')
