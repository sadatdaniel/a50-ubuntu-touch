#!/usr/bin/python3
"""Repair only the verified stale hidden Terminal window state; no app data reset."""
import pathlib
import sqlite3
import subprocess
import time

path = pathlib.Path.home() / '.cache/lomiri/windowstatestorage.sqlite'
app_id = 'terminal.ubports_terminal'
with sqlite3.connect(f'file:{path}?mode=ro', uri=True) as source:
    assert source.execute('SELECT state FROM state WHERE windowId=?', (app_id,)).fetchone() == (13,)
    backup = path.with_name(f'windowstatestorage.before-hidden-repair-{time.time_ns()}.sqlite')
    with sqlite3.connect(backup) as target:
        source.backup(target)
    backup.chmod(0o600)
print('Private window-state backup created.', flush=True)
subprocess.run(['systemctl', '--user', 'stop', 'lomiri-app-launch--application-click--terminal.ubports_terminal_2.0.6--.service'], check=True, timeout=15)
with sqlite3.connect(path) as database:
    result = database.execute('UPDATE state SET state=1 WHERE windowId=? AND state=13', (app_id,))
    assert result.rowcount == 1
print('Only Terminal hidden state restored to normal.', flush=True)
