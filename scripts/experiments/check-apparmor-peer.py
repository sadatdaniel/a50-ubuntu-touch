#!/usr/bin/env python3
"""Read-only AppArmor socket-label probe; run on the phone before camera tests."""
import json
from pathlib import Path
import socket
import sys

result = {}
for name, path in {
    "enabled": "/sys/module/apparmor/parameters/enabled",
    "unix_mediation": "/sys/kernel/security/apparmor/features/network/af_unix",
    "caller_label": "/proc/self/attr/current",
}.items():
    try:
        result[name] = Path(path).read_text().strip()
    except OSError as error:
        result[name] = {"error": str(error)}

try:
    left, right = socket.socketpair()
    with left, right:
        # Linux SO_PEERSEC; 256 is below Python's getsockopt buffer limit.
        peer = left.getsockopt(socket.SOL_SOCKET, getattr(socket, "SO_PEERSEC", 31), 256)
        result["peer_label"] = peer.rstrip(b"\0").decode()
except OSError as error:
    result["peer_error"] = {"errno": error.errno, "message": str(error)}

print(json.dumps(result, indent=2))
sys.exit(0 if result.get("peer_label") and result.get("unix_mediation") == "yes" else 1)
