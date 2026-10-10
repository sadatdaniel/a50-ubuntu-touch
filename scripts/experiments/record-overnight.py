#!/usr/bin/env python3
"""Bounded private observation; ordinary waits never arm a suspend wake alarm."""
import datetime
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import pwd
import selectors
import signal
import subprocess
import sys
import time

SYSTEM_UNITS = ["repowerd.service", "a50-enable-autosuspend.service",
                "waydroid-container.service", "usb-moded.service",
                "NetworkManager.service", "NetworkManager-dispatcher.service",
                "bluetooth.service", "bluebinder.service"]
USER_UNITS = ["lomiri-full-greeter.service",
              "lomiri-app-launch--application-legacy--Waydroid--.service"]


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError as error:
        return f"unavailable: {error.errno}"


def command(args):
    try:
        result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=5)
        return {"rc": result.returncode, "text": result.stdout[-16384:]}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"error": str(error)}


def snapshot():
    uid = pwd.getpwnam("phablet").pw_uid
    props = ["-p", "Id", "-p", "MainPID", "-p", "InvocationID", "-p", "NRestarts",
             "-p", "ActiveState", "-p", "Result"]
    return {
        "utc": utc(), "boot_id": read("/proc/sys/kernel/random/boot_id"),
        "boottime_s": time.clock_gettime(time.CLOCK_BOOTTIME),
        "monotonic_s": time.monotonic(),
        "suspend_stats": read("/sys/kernel/debug/suspend_stats"),
        "wake_locks": read("/sys/power/wake_lock"),
        "wakeup_sources": read("/sys/kernel/debug/wakeup_sources"),
        "usb_online": read("/sys/class/power_supply/usb/online"),
        "brightness": read("/sys/class/backlight/panel/brightness"),
        "apparmor": read("/sys/module/apparmor/parameters/enabled"),
        "memory": read("/proc/meminfo"), "load": read("/proc/loadavg"),
        "battery": {key: read("/sys/class/power_supply/battery/" + key)
                    for key in ["capacity", "status", "voltage_now", "current_now", "temp"]},
        "system_units": command(["systemctl", "show"] + SYSTEM_UNITS + props),
        "user_units": command(["runuser", "-u", "phablet", "--", "env",
                               f"XDG_RUNTIME_DIR=/run/user/{uid}",
                               f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus",
                               "systemctl", "--user", "show"] + USER_UNITS + props),
        "android_state": command(["lxc-info", "-P", "/var/lib/waydroid/lxc",
                                  "-n", "waydroid", "-sH", "-pH"]),
    }


def logger(path, size):
    handler = RotatingFileHandler(path, maxBytes=size, backupCount=3, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(message)s"))
    log = logging.Logger(str(path), level=logging.INFO)
    log.addHandler(handler)
    return log


def emit(log, value):
    log.info(json.dumps(value, ensure_ascii=True, separators=(",", ":")))
    for handler in log.handlers:
        handler.flush()
        os.fdatasync(handler.stream.fileno())


def main(directory):
    os.umask(0o077)
    directory = Path(directory).resolve()
    until = float(json.loads((directory / "config.json").read_text())["until_epoch"])
    if time.time() >= until:
        return
    logs = {name: logger(directory / (name + ".log"), 4 * 1024 * 1024)
            for name in ["snapshots", "journal", "android-crash"]}
    selector = selectors.DefaultSelector()
    children = {}
    buffers = {}
    running = True

    def stop(signum, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def start(name, args):
        proc = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, start_new_session=True, bufsize=0)
        children[name] = proc
        os.set_blocking(proc.stdout.fileno(), False)
        selector.register(proc.stdout, selectors.EVENT_READ, name)
        buffers[name] = b""

    try:
        start("kernel", [sys.executable, str(Path(__file__).with_name("capture-kmsg.py")),
                         "--events-only", "--output", str(directory / "kernel.log")])
        journal = ["journalctl", "--follow", "--lines=0", "--output=json", "--no-pager"]
        journal += ["_SYSTEMD_UNIT=" + unit for unit in SYSTEM_UNITS]
        journal += ["+"] + ["_SYSTEMD_USER_UNIT=" + unit for unit in USER_UNITS]
        for transport in ["stdout", "journal", "syslog", "driver"]:
            journal += ["+", "_TRANSPORT=" + transport] + ["PRIORITY=" + str(p) for p in range(4)]
        start("journal", journal)
        next_sample = 0.0
        while running and time.time() < until:
            if time.monotonic() >= next_sample:
                data = snapshot()
                emit(logs["snapshots"], data)
                if not (directory / "before.json").exists():
                    (directory / "before.json").write_text(json.dumps(data))
                # Direct attach does not call Waydroid shell's unfreeze helper.
                # A frozen/stopped container is observed without being started.
                if "android" not in children and "RUNNING" in data["android_state"].get("text", ""):
                    start("android", ["lxc-attach", "-P", "/var/lib/waydroid/lxc", "-n", "waydroid",
                                      "--clear-env", "--", "/system/bin/logcat", "-b", "crash", "-b", "events",
                                      "-v", "epoch", "-T", "1", "AndroidRuntime:V", "DEBUG:V", "libc:V",
                                      "am_crash:V", "am_anr:V", "am_kill:V", "am_proc_died:V", "*:S"])
                (directory / "ready").write_text(data["boot_id"] + "\n")
                next_sample = time.monotonic() + 120
            for key, _ in selector.select(timeout=min(120, max(0, next_sample - time.monotonic()))):
                name = key.data
                chunk = os.read(key.fileobj.fileno(), 16384)
                if not chunk:
                    selector.unregister(key.fileobj)
                    proc = children.pop(name)
                    proc.wait(timeout=5)
                    emit(logs["snapshots"], {"utc": utc(), "reader_exit": name, "rc": proc.returncode})
                    if name != "android":
                        raise RuntimeError(name + " reader stopped")
                    continue
                lines = (buffers[name] + chunk).split(b"\n")
                buffers[name] = lines.pop()
                if len(buffers[name]) > 65536:
                    emit(logs["snapshots"], {"utc": utc(), "oversized_line": name})
                    buffers[name] = b""
                for line in lines:
                    value = line.decode("utf-8", errors="replace")[:65536]
                    if name == "journal":
                        try:
                            data = json.loads(value)
                        except ValueError:
                            data = {"unparsed": value}
                        emit(logs["journal"], {"utc": utc(), "record": data})
                    elif name == "android":
                        emit(logs["android-crash"], {"utc": utc(), "record": value})
                    else:
                        emit(logs["snapshots"], {"utc": utc(), "kernel_reader_message": value})
    finally:
        for proc in children.values():
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        for proc in children.values():
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=3)
        selector.close()
        data = snapshot()
        emit(logs["snapshots"], {"event": "observer-stop", **data})
        (directory / "after.json").write_text(json.dumps(data))
        for log in logs.values():
            for handler in log.handlers:
                handler.close()


if __name__ == "__main__":
    main(sys.argv[1])
