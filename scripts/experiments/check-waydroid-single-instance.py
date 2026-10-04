"""Check the actual launcher generator twice, without importing Waydroid services."""
import ast
import configparser
import logging
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace

source = Path(sys.argv[1])
tree = ast.parse(source.read_text(encoding='utf-8'))
function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'makeWaydroidDesktopFile')
# The check uses ordinary temporary files, without administrator ownership changes.
file_ops = SimpleNamespace(path=os.path, access=os.access, W_OK=os.W_OK,
                           remove=os.remove, chown=lambda *args: None, chmod=os.chmod)
namespace = {'os': file_ops, 'logging': logging}
exec(compile(ast.Module(body=[function], type_ignores=[]), str(source), 'exec'), namespace)
with tempfile.TemporaryDirectory() as folder:
    for hide in (False, True, False):
        namespace['makeWaydroidDesktopFile'](folder, hide)
        cfg = configparser.ConfigParser()
        cfg.read(Path(folder) / 'Waydroid.desktop', encoding='utf-8')
        desktop = cfg['Desktop Entry']
        assert desktop.getboolean('X-Lomiri-Single-Instance', fallback=False), 'Native launcher must remain single-instance after regeneration'
        assert desktop['Exec'] == 'waydroid show-full-ui'
        assert desktop.getboolean('NoDisplay') == hide
print('PASS: native command, single-instance identity and visibility survive regeneration.')
