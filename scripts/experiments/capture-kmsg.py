#!/usr/bin/env python3
"""Private, bounded kernel capture for A50 development boots."""
import argparse
import errno
import logging
from logging.handlers import RotatingFileHandler
import os
import re
import time

FILTER = re.compile(r'(SUBSYSTEM|DEVICE)=|Could not set context|selinux_android_restorecon|'
                    r'sm5713|muic_debug_reg_log|usbpd_debug_reg_log|etspi_work_func_debug|'
                    r'sec_bat|^selinux: ?$|s3c2410-wdt')
EVENTS = re.compile(r'PM:|EXYNOS-PM|[Ww]ake(?:up| |_reason)|Freezing|freezing|'
                    r'BUG:|Oops:|panic|Out of memory|oom-kill|oom_reaper|Killed process|'
                    r'blocked for more|I/O error|EXT4-fs (?:error|warning)|'
                    r'apparmor=.*DENIED|SETSUSPENDMODE|'
                    r'watchdog.*(?:expired|timeout|reset|panic)', re.IGNORECASE)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='/userdata/kmsg-capture.log')
    parser.add_argument('--events-only', action='store_true')
    args = parser.parse_args()
    os.umask(0o077)
    handler = RotatingFileHandler(args.output, maxBytes=8*1024*1024,
                                  backupCount=3, encoding='utf-8')
    formatter = logging.Formatter('%(asctime)s UTC %(message)s' if args.events_only else '%(message)s')
    formatter.converter = time.gmtime
    handler.setFormatter(formatter)
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
                keep = EVENTS.search(line) if args.events_only else not FILTER.search(line)
                if keep:
                    logger.info('%s', line)
                    os.fdatasync(handler.stream.fileno())
    finally:
        os.close(fd)
        handler.close()

if __name__ == '__main__':
    main()
