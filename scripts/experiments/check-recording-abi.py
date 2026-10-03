from pathlib import Path
import hashlib
import re
import subprocess
import sys

old, new = map(Path, sys.argv[1:3])
expected = {'lib': '61ccb6554dcef9fdc30099a88d3c7773901e616aeefccc1845d8045d56d1e89d',
            'lib64': 'ddcdf2a8e68eae5a01f91f1ab92e4175205ed38f31f0aec76e513e0992fa91f6'}

def inspect(file):
    symbols = subprocess.check_output(['readelf', '--dyn-syms', '--wide', str(file)], text=True)
    exports, imports = set(), set()
    for line in symbols.splitlines():
        fields = line.split()
        if len(fields) < 8 or fields[4] not in ('GLOBAL', 'WEAK'):
            continue
        (imports if fields[6] == 'UND' else exports).add(fields[7])
    dynamic = subprocess.check_output(['readelf', '-d', str(file)], text=True)
    dependencies = re.findall(r'\(NEEDED\).*?\[(.*?)\]', dynamic)
    soname = re.findall(r'\(SONAME\).*?\[(.*?)\]', dynamic)
    header = subprocess.check_output(['readelf', '-h', str(file)], text=True)
    return exports, imports, dependencies, soname, header

for arch, machine in [('lib', 'ARM'), ('lib64', 'AArch64')]:
    original = old / arch / 'libaudioclient.so'
    candidate = new / arch / 'libaudioclient.so'
    assert hashlib.sha256(original.read_bytes()).hexdigest() == expected[arch]
    first, second = inspect(original), inspect(candidate)
    assert first[:4] == second[:4], f'{arch}: dynamic ABI differs'
    assert f'Machine:                           {machine}' in second[4]
    assert second[3] == ['libaudioclient.so']
    print(f'{arch}: exact dynamic exports ({len(second[0])}), imports ({len(second[1])}), NEEDED and SONAME match; {machine}.')
for line in (new / 'SHA256SUMS').read_text().splitlines():
    digest, filename = line.split()
    assert hashlib.sha256((new / filename).read_bytes()).hexdigest() == digest
print('Original fingerprints and candidate SHA256SUMS verified. Phone behavior remains untested.')
