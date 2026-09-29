"""Inspect both concatenated initramfs archives and the A50 recovery header."""
import gzip
import hashlib
import lzma
from pathlib import Path
import struct
import sys

image, donor, base = (Path(p).read_bytes() for p in sys.argv[1:4])
ks, ka, rs, ra, ss, sa, ta, page, version, osv = struct.unpack_from('<10I', image, 8)
assert (version, page, ka, ra, ta, ss) == (1, 2048, 0x10008000, 0x11000000, 0x10000100, 0)
ro = page + ((ks + page - 1) // page) * page
ds, do, hs = struct.unpack_from('<IQI', image, 1632)
ods, odo, ohs = struct.unpack_from('<IQI', donor, 1632)
assert image[do:do+ds] == donor[odo:odo+ods]
assert len(image) <= 67633152 and do == ro + ((rs+page-1)//page)*page
archive = lzma.decompress(image[ro:ro+rs])
assert archive.startswith(gzip.decompress(base))

files = {}
trailers = 0
pos = 0
while pos < len(archive):
    while pos < len(archive) and archive[pos] == 0:
        pos += 1
    if pos == len(archive):
        break
    assert archive[pos:pos+6] in (b'070701', b'070702'), pos
    fields = [int(archive[pos+6+i*8:pos+14+i*8], 16) for i in range(13)]
    mode, uid, gid, size, namesize = fields[1], fields[2], fields[3], fields[6], fields[11]
    name = archive[pos+110:pos+110+namesize-1].decode()
    start = (pos+110+namesize+3) & ~3
    data = archive[start:start+size]
    assert len(data) == size
    if name == 'TRAILER!!!':
        trailers += 1
    else:
        files[name.removeprefix('./')] = (mode, uid, gid, data)
    pos = (start+size+3) & ~3
assert trailers == 2, trailers
fstab = files['system/etc/recovery.fstab'][3].decode()
for partition in ('userdata', 'system', 'boot', 'recovery', 'misc'):
    assert '/by-name/' + partition + ' ' in fstab
assert ' /data ext4 ' in fstab and not any(' /cache ' in x for x in fstab.splitlines() if not x.startswith('#'))
props = dict(x.split('=', 1) for x in files['prop.default'][3].decode().splitlines() if '=' in x and not x.startswith('#'))
assert props['ro.product.device'] == 'a50'
assert props['ro.minui.pixel_format'] == 'ABGR_8888'
assert props['ro.build.ab_update'] == 'false'
assert files['system/etc/recovery.fstab'][:3] == (0o100644, 0, 0)
digest = hashlib.sha1()
for blob in (image[page:page+ks], image[ro:ro+rs], b'', image[do:do+ds]):
    digest.update(blob)
    digest.update(struct.pack('<I', len(blob)))
assert image[576:608] == digest.digest() + bytes(12)
print('PASS: header addresses and SHA1, full DTBO, XZ round trip, both initramfs archives, final fstab/properties, ownership and partition size')
