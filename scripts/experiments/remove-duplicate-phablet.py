#!/usr/bin/env python3
"""Remove stale local phablet records only when extrausers owns the same account."""
import ctypes
import os
from pathlib import Path
import shutil
import tempfile

backup = Path('/userdata/a50-session20-release/account-duplicate-backup')
libc = ctypes.CDLL(None, use_errno=True)
if libc.lckpwdf() != 0:
    raise SystemExit('Could not lock account database')
try:
    paths = [Path('/etc/passwd'), Path('/etc/shadow')]
    originals = {p: p.read_bytes() for p in paths}
    extras = {p.name: Path('/var/lib/extrausers', p.name).read_bytes() for p in paths}
    def entry(data):
        found = [line.split(b':') for line in data.splitlines() if line.startswith(b'phablet:')]
        if len(found) != 1:
            raise SystemExit('Expected exactly one phablet entry')
        return found[0]
    local = entry(originals[paths[0]])
    extra = entry(extras['passwd'])
    assert len(local) == len(extra) == 7
    assert all(local[i] == extra[i] for i in (2, 3, 5, 6))
    assert extra[2] == b'32011' and extra[5] == b'/home/phablet'
    assert len(entry(extras['shadow'])) == 9
    assert len(entry(originals[paths[1]])) == 9
    nss = Path('/etc/nsswitch.conf').read_text()
    for kind in ('passwd', 'shadow'):
        assert any(line.split('#')[0].split() == [kind + ':', 'files', 'extrausers']
                   for line in nss.splitlines())
    backup.mkdir(mode=0o700, exist_ok=False)
    for p in paths:
        shutil.copy2(p, backup / p.name)
        os.chmod(backup / p.name, 0o600)
    prepared = []
    for p in paths:
        st = p.stat()
        data = b''.join(line for line in originals[p].splitlines(keepends=True)
                        if not line.startswith(b'phablet:'))
        fd, name = tempfile.mkstemp(prefix='.a50-account-', dir=p.parent)
        with os.fdopen(fd, 'wb') as f:
            os.fchown(f.fileno(), st.st_uid, st.st_gid)
            os.fchmod(f.fileno(), st.st_mode & 0o7777)
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        prepared.append((p, name))
    for p in paths:
        assert p.read_bytes() == originals[p]
        assert Path('/var/lib/extrausers', p.name).read_bytes() == extras[p.name]
    for p, name in prepared:
        os.replace(name, p)
    os.sync()
    print('Removed duplicate local phablet records; writable account unchanged; backups retained')
finally:
    libc.ulckpwdf()
