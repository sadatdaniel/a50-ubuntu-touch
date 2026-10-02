# Clean 26.04 installation test

Started October 2, 2026; installation preparation continued October 3 CEST.
The user explicitly authorized replacing the existing installation and discarding
its data to test the experience of a new user. The old installation can still be
moved aside cheaply on the same filesystem; no SD card or partition formatting
is necessary. This is not an OTA-enabled release or completed stability claim.

## Inputs

- Rootfs full-376, port overlay f0c4a7e, read-only 5,200 MiB candidate:
  `8408498e80eeca0c8f3fca251dfb57a94dc23c8ce6b5ca325cbce0854874510f`.
- Tested aa12 boot image:
  `795e8b7fffda6b46e318d1bccc542b3a7d807987a7787f5115f0dcb27b7b9dcb`.
- Existing TWRP 3.7.1_12-0, full recovery partition SHA256:
  `8535a9d9193243412fcefc0e6f1ba585d60e1533e65069867444a49d0287e51f`.

The package uses the committed make-installer-zip.sh with --variant clean-test
and --version 2026-10-02. The rootfs itself is the release variant: locked root,
no development password, no .writable_image, and no forced development USB mode.
The installed filesystem still uses /data/rootfs.img for this onboarding test.
Conventional system layout, unified recovery hardware validation and signed
local updates remain separate gates in ota-finalization.md.

## Procedure

1. Check the two image hashes, build the ZIP, run unzip integrity validation,
   transfer via ADB to TWRP's internal storage and verify its complete hash.
2. Verify the A50 partition paths, /data mount and free space in recovery.
3. Run prepare-clean-install-twrp.sh only in TWRP. It saves the boot partition
   and moves rootfs.img, user-data, system-data, android-data, writable-image/overlay state and any force-USB
   markers under /data/a50-before-clean-20261002. It refuses nested /data mounts
   and symlinked source paths. It neither formats partitions nor changes TWRP.
4. Install the verified ZIP using TWRP's existing install command. Check its
   boot/rootfs read-back results before rebooting.
5. Verify setup wizard, user-chosen credentials, confinement, device services,
   second boot and suspend startup. Install Waydroid through the documented
   supported path and reproduce launch/close/sleep tests without old Helper or
   Android state. Do not treat one successful boot as release validation.

Rollback in TWRP: rollback-clean-install-twrp.sh verifies the saved boot image,
moves fresh test state under /data/a50-clean-test-failed-20261002, restores the
old paths and boot partition, and verifies boot read-back. It is an experiment
script tied to these literal staging paths, not a general public installer.

At preparation time: TWRP ADB connected, /data on /dev/block/sda32 had 72 GiB
available, boot mapped to /dev/block/sda14 and measured 57,671,680 bytes. Script
syntax checks passed in the build container and TWRP. Data migration and actual
installation results must be appended after execution.

Upstream procedure: https://twrp.me/faq/openrecoveryscript.html
