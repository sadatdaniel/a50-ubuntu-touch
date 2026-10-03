#!/usr/bin/env python3
"""Check real startup links in a release device tarball or committed overlay."""
import io
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile

if len(sys.argv) > 1:
    archive = tarfile.open(sys.argv[1])
else:
    repo = Path(__file__).resolve().parents[2]
    archive = tarfile.open(fileobj=io.BytesIO(subprocess.check_output(
        ['git', 'archive', 'HEAD', 'overlay/system/etc/systemd'], cwd=repo)))
with archive:
    members = {m.name: m for m in archive.getmembers()}
    entries = [m for m in members.values() if '.wants/' in m.name and not m.isdir()]
    assert entries, 'No startup dependencies found'
    for m in entries:
        assert m.issym(), f'{m.name}: expected symlink, got ordinary file'
        # A relative link resolves from its containing directory.
        if '/system/multi-user.target.wants/a50-' in m.name:
            target = PurePosixPath(m.name).parent / m.linkname
            parts = []
            for part in target.parts:
                if part == '..':
                    parts.pop()
                elif part != '.':
                    parts.append(part)
            assert '/'.join(parts) in members, f'{m.name}: missing target {m.linkname}'
    configs = [m for m in members.values() if m.name.endswith(
        '/etc/systemd/user/pulseaudio.service.d/zz-a50-hybris.conf')]
    assert len(configs) == 1, 'Missing first-boot audio namespace configuration'
    with archive.extractfile(configs[0]) as config:
        assert b'UnsetEnvironment=HYBRIS_USE_VENDOR_NAMESPACE' in config.read()
    print(f'PASS: {len(entries)} startup links and first-boot audio configuration')
