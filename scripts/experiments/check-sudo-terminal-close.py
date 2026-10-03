"""Close a synthetic password prompt without entering any credential."""
import fcntl
import os
import pty
import select
import signal
import termios
import time

for binary in ('/usr/bin/sudo-rs', '/usr/bin/sudo.ws'):
    master, slave = pty.openpty()
    child = os.fork()
    if child == 0:
        os.close(master)
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        for target in (0, 1, 2):
            os.dup2(slave, target)
        if slave > 2:
            os.close(slave)
        os.execv(binary, [binary, '-k', '-p', 'A50 diagnostic prompt: ', '-v'])
    os.close(slave)
    output = b''
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline and b'A50 diagnostic prompt: ' not in output:
        if select.select([master], [], [], 0.1)[0]:
            try:
                data = os.read(master, 4096)
            except OSError:
                break
            if not data:
                break
            output += data
    prompt = b'A50 diagnostic prompt: ' in output
    os.close(master)
    deadline = time.monotonic() + 3
    result = None
    while time.monotonic() < deadline:
        pid, status, usage = os.wait4(child, os.WNOHANG)
        if pid:
            result = (status, usage)
            break
        time.sleep(0.1)
    if result is None:
        os.kill(child, signal.SIGKILL)
        _, status, usage = os.wait4(child, 0)
        result = (status, usage)
        hung = True
    else:
        hung = False
    status, usage = result
    print(binary, 'prompt_seen=', prompt, 'hung_after_close=', hung,
          'exit=', os.waitstatus_to_exitcode(status),
          'cpu_seconds=', round(usage.ru_utime + usage.ru_stime, 3))
    assert prompt, 'The intended prompt was not reached'
