# Offline release candidates, 23 September 2026

Neither image below has been flashed. They are not an installation release.
TWRP and the phone's boot/userdata partitions remain unchanged by this work.

## Clean user filesystem

Built from port commit `abddbe3`, the aa12 boot image, pinned Halium 11 GSI build
1542, and the current official 26.04-1.x daily rootfs (FP5 full-image index 352).
The rootfs is device independent; the A50 device tarball supplies the adaptation.

- Upstream rootfs: `rootfs-b26cd107267a3e7a66c901b72fb9ea5a66d81e30613e22f3721c1a7bb2558e7b.tar.xz`
- Download SHA256: `049d51eda576609e3c44aba7e87b05270b8527f3b55dfd8b5cf94527d7c1305a`, matching the official HTTPS index; 684,661,152 bytes.
- Candidate rootfs: 5,452,595,200 bytes (5,200 MiB), below the measured 5,557,452,800-byte system partition.
- Candidate SHA256: `fd944b2196983621a265e51fb6c47e51ec3c4c5cd36e9c1e82fc682a3286c13b`.
- Device tarball SHA256: `0e66a8d90f646b3561b6bb20335da5597a4699056f6b46013daa3389844c3dc0`.

The build omitted `--devel`. Read-only audit passed e2fsck, image sizing, the
release marker, absence of the development SSH override, polkit helper
root:root/4755 and socket mask, and the normal AppArmor permission overrides.
Filesystem usage was approximately 3.5 GiB with 1.3 GiB available. The root
account is locked. There is exactly one phablet entry, in extrausers; no duplicate
local entry. The upstream phablet credential is empty and neither inspected
setup-completed marker exists. Do not replace this with development credentials.
The setup wizard and user-chosen authentication still need hardware validation.

Installed packages include polkit 127-2ubuntu1.1, repowerd 2026.06 (August 19
UBports build), and lomiri-push-service 0.100.3 (September 7 UBports build).

Reproduce with the existing scripts, a pinned ROOTFS_URL as above, and:

```sh
bash scripts/release/build-device-tarball.sh --boot /artifacts/boot-aa12.img --out /work/out
bash scripts/release/build-rootfs-image.sh --device-tarball /work/out/device_a50.tar.xz \
  --size 5200M --cache /work/cache --out /work/out
```

Record rootfs-source.txt and image hashes. Filesystem UUID/timestamps and the
compatibility-library downloads are not yet normalized/pinned, so a byte-identical
rootfs rebuild is not claimed. The isolated Docker volume used for this build is
`a50-release-aa12-rootfs`, with artifacts under `/w/out`.

## Unified recovery candidate

Built from official unified recovery archive build 545, aa12's kernel, and the
verified private TWRP backup as a device-header/DTBO donor. The builder pins the
input hashes, refuses overwrites, preserves the complete 8 MiB DTBO region,
updates its offset and the header digest, and checks the partition limit.
The compiled aa12 kernel has CONFIG_RD_XZ=y; the ramdisk uses XZ/CRC32.

- Recovery size: 62,095,360 bytes, below the 67,633,152-byte recovery partition.
- SHA256: `a640c1557da7f51501ebfad969a12fbb092e12c96a5aad7153c33222c9039abb`.
- Compressed ramdisk: 8,648,284 bytes; all donor DTBO bytes preserved.
- Ramdisk load address: 0x11000000, matching TWRP, not the normal boot image.
- Overlay supplies ext4 /data and non-A/B system/boot/recovery/misc mappings.
- Physical /cache is omitted in favor of unified recovery's userdata-backed cache.
- ABGR_8888 follows the working TWRP configuration; display/ADB still need testing.

```sh
python3 scripts/release/build-unified-recovery.py \
  --donor /private/recovery-twrp-backup.img \
  --kernel /artifacts/Image \
  --kernel-sha256 95aaa07b376e8b2f873742466e6527af142639fa61d1d4e922355dbc43148d61 \
  --base-ramdisk /artifacts/unified-recovery-545.img \
  --overlay ramdisk-recovery-overlay --out /work/recovery-aa12.img
python3 scripts/tests/check-recovery-candidate.py /work/recovery-aa12.img \
  /private/recovery-twrp-backup.img /artifacts/unified-recovery-545.img
```

The independent check passed header addresses/SHA1, full DTBO equality, XZ
decompression, both concatenated initramfs archives, final fstab/properties,
ownership and partition sizing. No signature-check bypass was added to recovery.
These checks cannot establish bootloader acceptance, screen/ADB operation, OTA
or factory reset behavior. Do not overwrite TWRP while unattended.

## Still required

The current boot ramdisk still follows the existing userdata rootfs layout;
sizing a rootfs for system does not itself migrate that boot path. The legacy
builder also adds `.writable_image` and performs some first-boot filesystem
changes. Move those adaptations into the build/appropriate writable paths before
claiming a conventional read-only user image. The generated A50 channel config
does not create an OTA service: no public A50 channel has been registered here.

Validate recovery hardware, rootfs-on-system boot, first-run setup and a signed
local OTA followed by a second update preserving data. Ensure the polkit legacy
configuration survives an upstream rootfs update, not only an initial image build.
Pin the current adaptation tools and reconcile their recovery-header parameters
before enabling shared CI. Automatic suspend testing remains gated on access to
the phone for a cable-disconnected test; fingerprint remains last.
