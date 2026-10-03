#!/usr/bin/env python3
"""Pin a repo-resolved manifest to the public GSI 1542 source record."""
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


def pin_manifest(root, pins):
    assert pins and all(re.fullmatch(r'[0-9a-f]{40}', v) for v in pins.values())
    found = set()
    default = root.find('default')
    default_revision = default.get('revision', '') if default is not None else ''
    default_remote = default.get('remote', '') if default is not None else ''
    remote_revisions = {r.get('name'): r.get('revision', default_revision)
                        for r in root.findall('remote')}
    for project in list(root.findall('project')):
        path = project.get('path', project.get('name', ''))
        if path not in pins:
            root.remove(project)
            continue
        found.add(path)
        revision = project.get('revision', remote_revisions.get(
            project.get('remote', default_remote), default_revision))
        if revision.startswith('refs/'):
            project.set('upstream', revision)
        project.set('revision', pins[path])
    assert found == set(pins), f'Missing recorded projects: {sorted(set(pins) - found)}'
    return root


if __name__ == '__main__':
    if sys.argv[1:] == ['--self-test']:
        root = ET.fromstring('<manifest><default revision="refs/heads/main"/><project path="frameworks/av" name="av"/><project path="extra" name="extra"/></manifest>')
        pin_manifest(root, {'frameworks/av': '1' * 40})
        assert len(root.findall('project')) == 1
        assert root.find('project').get('revision') == '1' * 40
        assert root.find('project').get('upstream') == 'refs/heads/main'
        try:
            pin_manifest(root, {'missing': '2' * 40})
        except AssertionError:
            pass
        else:
            raise AssertionError('Missing project was accepted')
        root = ET.fromstring('<manifest><remote name="aosp" revision="refs/tags/android-11.0.0_r46"/><default remote="github" revision="refs/heads/lineage-18.1"/><project path="aosp-project" name="platform/example" remote="aosp"/></manifest>')
        pin_manifest(root, {'aosp-project': '3' * 40})
        assert root.find('project').get('upstream') == 'refs/tags/android-11.0.0_r46'
        print('PASS: manifest pinning, remote revisions and missing-source rejection')
    else:
        tree = ET.parse(sys.argv[1])
        pins = json.loads(Path(sys.argv[2]).read_text())
        pin_manifest(tree.getroot(), pins)
        tree.write(sys.argv[3], encoding='utf-8', xml_declaration=True)
        print(f'Pinned {len(pins)} projects to GSI 1542 revisions')
