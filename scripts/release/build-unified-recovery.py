#!/usr/bin/env python3
"""Build an OFFLINE A50 recovery candidate; never flashes a device."""
import argparse
import gzip
import hashlib
import lzma
from pathlib import Path
import os
import struct
import subprocess
import tempfile

LIMIT = 67633152
DONOR_SHA = '8535a9d9193243412fcefc0e6f1ba585d60e1533e65069867444a49d0287e51f'
BASE_SHA = '054faa7a0cbc8792bdbdb91fb1ed9eafcfbacf9f35b4171cc9d4d98ac958da56'

def checked(path, expected):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError(f'hash mismatch: {path}')
    return data

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--donor', type=Path, required=True)
    p.add_argument('--kernel', type=Path, required=True)
    p.add_argument('--kernel-sha256', required=True)
    p.add_argument('--base-ramdisk', type=Path, required=True)
    p.add_argument('--overlay', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if a.out.exists():
        raise ValueError('refusing to overwrite an existing image')
    donor = checked(a.donor, DONOR_SHA)
    kernel = checked(a.kernel, a.kernel_sha256)
    archive = gzip.decompress(checked(a.base_ramdisk, BASE_SHA))
    if donor[:8] != b'ANDROID!':
        raise ValueError('not an Android boot image')
    ks, ka, rs, ra, ss, sa, ta, page, version, osv = struct.unpack_from('<10I', donor, 8)
    if (version, page, ss, ka, ra, ta) != (1, 2048, 0, 0x10008000, 0x11000000, 0x10000100):
        raise ValueError('unexpected recovery header layout')
    ds, do, hs = struct.unpack_from('<IQI', donor, 1632)
    if hs != 1648 or do + ds > len(donor) or any(donor[do+ds:]):
        raise ValueError('unknown recovery extension or nonzero trailing payload')
    dtbo = donor[do:do+ds]  # Preserve the entire region, including its nonzero tail.
    if dtbo[:4] != bytes.fromhex('d7b7ab1e'):
        raise ValueError('missing recovery DTBO table')
    original_props = subprocess.check_output(
        ['cpio', '-i', '--to-stdout', '--quiet', 'prop.default'], input=archive).decode()
    props = {
        'ro.product.brand': 'Samsung', 'ro.product.device': 'a50',
        'ro.product.manufacturer': 'Samsung', 'ro.product.model': 'Galaxy A50',
        'ro.product.name': 'halium_a50', 'ro.build.version.release': '11',
        'ro.build.ab_update': 'false', 'ro.recovery.usb.vid': '18D1',
        'ro.recovery.usb.adb.pid': 'D001', 'ro.recovery.usb.fastboot.pid': '4EE0',
        'service.adb.root': '1', 'ro.minui.pixel_format': 'ABGR_8888',
    }
    with tempfile.TemporaryDirectory(prefix='a50-recovery-') as tmp:
        root = Path(tmp)
        # Only device configuration is copied. The upstream archive is not extracted.
        for rel in ('system/etc/recovery.fstab', 'prop.halium'):
            dst = root/rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes((a.overlay/rel).read_bytes())
        lines = [line for line in original_props.splitlines() if line.split('=', 1)[0] not in props]
        (root/'prop.default').write_text('\n'.join(lines + [f'{k}={v}' for k, v in props.items()])+'\n')
        paths = sorted(root.rglob('*'))
        for path in paths:
            path.chmod(0o755 if path.is_dir() else 0o644)
            os.utime(path, (0, 0))
        names = b''.join(str(path.relative_to(root)).encode()+b'\0' for path in paths)
        overlay = subprocess.check_output(
            ['cpio', '--null', '-o', '-H', 'newc', '--reproducible', '--owner=0:0', '--quiet'],
            input=names, cwd=root)
    # Linux's initramfs unpacker consumes successive newc archives; later files win.
    merged = archive + overlay
    ramdisk = lzma.compress(merged, format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC32, preset=9)
    if lzma.decompress(ramdisk) != merged:
        raise ValueError('ramdisk round-trip failed')
    def pad(data):
        return data + bytes((-len(data)) % page)
    header = bytearray(donor[:page])
    new_do = page + len(pad(kernel)) + len(pad(ramdisk))
    struct.pack_into('<I', header, 8, len(kernel))
    struct.pack_into('<I', header, 16, len(ramdisk))
    struct.pack_into('<Q', header, 1636, new_do)
    digest = hashlib.sha1()
    for blob in (kernel, ramdisk, b'', dtbo):
        digest.update(blob)
        digest.update(struct.pack('<I', len(blob)))
    header[576:608] = digest.digest() + bytes(12)
    image = bytes(header) + pad(kernel) + pad(ramdisk) + pad(dtbo)
    if len(image) > LIMIT:
        raise ValueError(f'recovery exceeds partition: {len(image)} > {LIMIT}')
    a.out.parent.mkdir(parents=True, exist_ok=True)
    with a.out.open('xb') as f:
        f.write(image)
    written = a.out.read_bytes()
    if written != image or written[new_do:new_do+ds] != dtbo:
        raise ValueError('output verification failed')
    manifest = (f'status=OFFLINE_UNTESTED_RECOVERY_CANDIDATE\n'
                f'donor_sha256={DONOR_SHA}\nbase_ramdisk_sha256={BASE_SHA}\n'
                f'kernel_sha256={a.kernel_sha256}\nramdisk_compression=xz-crc32\n'
                f'ramdisk_bytes={len(ramdisk)}\nrecovery_dtbo_bytes={ds}\n'
                f'partition_bytes={LIMIT}\nimage_bytes={len(image)}\n'
                f'image_sha256={hashlib.sha256(image).hexdigest()}\n')
    a.out.with_suffix('.manifest.txt').write_text(manifest)
    print(manifest)

if __name__ == '__main__':
    main()
