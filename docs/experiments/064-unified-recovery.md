# 064 — Unified UBports recovery on the A50

19 October 2026, owner present. Recovery partition: 67,633,152 bytes.

## Result

The **unified UBports recovery now runs on the A50 with our own kernel** (rf2,
runtime firmware). The display is clear, uses xxhdpi assets and sits below the
notch. ADB runs as root, `/cache` is userdata-backed, and `mount /data` gives
ext4 `/dev/block/sda32` as UBports requires. Reboot to the system works;
the system stays healthy (root RO, AppArmor Y, zero failed units).

Installed image: `recovery-rf2-h14-572d.img`, SHA256 `b2c75255…`, 60,893,184
bytes, archived in release `inputs-20261017`. Inputs:

| Input | Identity |
|---|---|
| Kernel | rf2 Image `6d000a98…` (a50-halium CI 39158814601) |
| Base ramdisk | Jenkins `generic_arm64/halium-14.0` 572 `ramdisk-recovery.img` `88e15027…` (archived) |
| Header/DTBO donor | TWRP 3.7.1 dump `8535a9d9…` (archived; also `/userdata/a50-recovery-test/`) |
| Overlay | `ramdisk-recovery-overlay` (`recovery.fstab`, `prop.halium`) |
| UI assets | `halium_bootable_recovery` `9cdb4a98` `res-xxhdpi/images` via `scripts/release/fetch-recovery-res.sh` |

Build and offline check:

```sh
bash scripts/release/fetch-recovery-res.sh /w/res-xxhdpi
python3 scripts/release/build-unified-recovery.py --donor recovery-twrp.img \
  --kernel Image --kernel-sha256 6d000a98… --base-ramdisk ramdisk-recovery-h14-572.img \
  --base-sha256 88e15027… --overlay ramdisk-recovery-overlay --res-images /w/res-xxhdpi --out recovery.img
python3 scripts/tests/check-recovery-candidate.py recovery.img recovery-twrp.img ramdisk-recovery-h14-572.img
```

Flash with `scripts/experiments/flash-recovery-image.sh` (current-image, boot
and vendor guards). A running recovery can rewrite itself from `/tmp`.

## Blank screen: two causes, both fixed

1. The panel stays dark under the Android 14 recovery UI until it is blanked
   and unblanked. The standard AOSP property
   `ro.recovery.ui.blank_unblank_on_init=true`, in `prop.halium` (the UBports
   place for recovery props), fixes it. Writing to `fb0` or unblanking by hand
   did not.
2. `res-xxhdpi/images/font.png` is a **symlink** upstream (`../../fonts/18x32.png`).
   A raw download stored the link text, so the font failed (`-3`) and recovery
   fell back to a stub UI. `fetch-recovery-res.sh` resolves links like `cp` and
   verifies pinned hashes.

A detour wrongly blamed the kernel. The rf2-kernel test image happened to
include the broken font. TWRP's kernel image also works, but it is not needed.
`ro.recovery.ui.margin_height=120` clears the waterdrop notch.

## deviceinfo

`deviceinfo_has_recovery_partition="true"`, partition size 67633152,
`deviceinfo_use_unified_recovery="true"`, `deviceinfo_unified_recovery_ui_density="xxhdpi"`.
The conventional `build.sh` still builds its own (currently hanging) kernel,
so use the builder above until that is solved.

## Restore TWRP

From the system: `sudo sh flash-recovery-image.sh /userdata/a50-recovery-test/recovery-twrp.img 8535a9d9… b2c75255… 60893184`.

## Next

Local OTA test (UBports `prepare-fake-ota.sh` / `system-image-upgrader`)
needs the conventional layout migration (rootfs on the system partition, a
one-time, data-affecting step) and a factory-reset test on disposable data.
Both need owner decisions.
