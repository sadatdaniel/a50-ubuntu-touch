#!/usr/bin/python3
"""Prepare/restore Samsung SCSC Wi-Fi through repowerd's power-mode hooks."""
import ctypes
import fcntl
from pathlib import Path
import socket
import struct
import sys

if len(sys.argv) != 2 or sys.argv[1] not in ("0", "1"):
    raise SystemExit("usage: a50-wifi-power.py 0|1")
if ctypes.sizeof(ctypes.c_void_p) != 8:
    raise SystemExit("The A50 private ioctl layout requires 64-bit userspace")

# Never enable a disabled radio; NetworkManager owns interface state.
try:
    flags = int(Path("/sys/class/net/swlan0/flags").read_text().strip(), 16)
except FileNotFoundError:
    raise SystemExit(0)
if not flags & 1:  # IFF_UP
    raise SystemExit(0)


class Command(ctypes.Structure):
    _fields_ = [("buf", ctypes.c_void_p), ("used_len", ctypes.c_int),
                ("total_len", ctypes.c_int)]


# Samsung android_wifi_priv_cmd and arm64 struct ifreq, as in scsc/ioctl.h.
payload = ctypes.create_string_buffer(("SETSUSPENDMODE " + sys.argv[1]).encode())
command = Command(ctypes.addressof(payload), 0, ctypes.sizeof(payload))
request = struct.pack("16sQ16x", b"swlan0", ctypes.addressof(command))
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    fcntl.ioctl(sock.fileno(), 0x89f2, request)
