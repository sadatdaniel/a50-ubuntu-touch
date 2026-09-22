import importlib.util
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
import tempfile

spec = importlib.util.spec_from_file_location('capture', Path(__file__).with_name('capture-kmsg.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module.FILTER.search('sm5713: routine polling')
assert not module.FILTER.search('BUG: unable to handle kernel paging request')
with tempfile.TemporaryDirectory() as directory:
    log = Path(directory) / 'kmsg.log'
    handler = RotatingFileHandler(log, maxBytes=256, backupCount=3, encoding='utf-8')
    logger = logging.Logger('test')
    logger.addHandler(handler)
    for i in range(100):
        logger.warning('record %d %s', i, 'x' * 64)
    handler.close()
    files = list(Path(directory).iterdir())
    assert len(files) == 4
    assert all(p.stat().st_size <= 256 for p in files)
    assert 'record 99 ' in log.read_text()
print('Kernel capture filter and bounded rotation checks passed')
