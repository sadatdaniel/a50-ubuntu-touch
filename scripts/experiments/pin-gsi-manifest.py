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
    for project in list(root.findall('project')):
        path = project.get('path', project.get('name', ''))
        if path not in pins:
            root.remove(project)
            continue
        found.add(path)
        revision = project.get('revision', default_revision)
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
        print('PASS: manifest pinning and missing-source rejection')
    else:
        tree = ET.parse(sys.argv[1])
        pins = json.loads(Path(sys.argv[2]).read_text())
        pin_manifest(tree.getroot(), pins)
        tree.write(sys.argv[3], encoding='utf-8', xml_declaration=True)
        print(f'Pinned {len(pins)} projects to GSI 1542 revisions')
