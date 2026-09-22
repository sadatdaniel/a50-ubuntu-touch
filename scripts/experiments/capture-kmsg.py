#!/usr/bin/env python3
"""Private, bounded kernel capture for A50 development boots."""
import errno
import logging
from logging.handlers import RotatingFileHandler
import os
import re

FILTER = re.compile(r'(SUBSYSTEM|DEVICE)=|Could not set context|selinux_android_restorecon|'
                    r'sm5713|muic_debug_reg_log|usbpd_debug_reg_log|etspi_work_func_debug|'
                    r'sec_bat|^selinux: ?$|s3c2410-wdt')

def main():
    os.umask(0o077)
    handler = RotatingFileHandler('/userdata/kmsg-capture.log', maxBytes=8*1024*1024,
                                  backupCount=3, encoding='utf-8')
    handler.setFormatter(logging.Formatter('%(message)s'))
    logger = logging.getLogger('a50-kmsg')
    logger.setLevel(logging.INFO)
    logger.addHandler(handler)
    logger.propagate = False
    fd = os.open('/dev/kmsg', os.O_RDONLY)
    try:
        while True:
            try:
                record = os.read(fd, 65536)
            except OSError as error:
                if error.errno != errno.EPIPE:
                    raise
                logger.warning('A50 capture: kernel ring overrun; older records lost')
                continue
            if not record:
                break
            for line in record.decode('utf-8', errors='replace').splitlines():
                if not FILTER.search(line):
                    logger.info('%s', line)
                    os.fdatasync(handler.stream.fileno())
    finally:
        os.close(fd)
        handler.close()

if __name__ == '__main__':
    main()
