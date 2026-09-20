#!/usr/bin/env python3
"""Diagnostic only: send the A50 vendor Wi-Fi suspend command (0 or 1)."""
import ctypes
import fcntl
import socket
import struct
import sys

if len(sys.argv) != 2 or sys.argv[1] not in ('0', '1'):
    raise SystemExit('usage: a50-wifi-suspend-mode.py 0|1')
if ctypes.sizeof(ctypes.c_void_p) != 8:
    raise SystemExit('This checked layout requires 64-bit userspace')
class Command(ctypes.Structure):
    _fields_ = [('buf', ctypes.c_void_p), ('used_len', ctypes.c_int), ('total_len', ctypes.c_int)]
payload = ctypes.create_string_buffer(('SETSUSPENDMODE ' + sys.argv[1]).encode())
command = Command(ctypes.addressof(payload), 0, ctypes.sizeof(payload))
request = struct.pack('16sQ16x', b'swlan0', ctypes.addressof(command))
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    fcntl.ioctl(sock.fileno(), 0x89f2, request)
print('Vendor Wi-Fi suspend mode accepted:', sys.argv[1])
