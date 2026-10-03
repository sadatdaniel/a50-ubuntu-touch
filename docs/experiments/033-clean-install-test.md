# Clean 26.04 installation test

Started October 2, 2026; installation continued October 3 CEST. The user
explicitly authorized erasing the existing installation and all personal data
to test the experience of a new user. This is not an OTA-enabled release or a
completed stability claim. No SD card is needed: transfer over USB into TWRP.

## Inputs

- Rootfs full-376, port overlay f0c4a7e, read-only 5,200 MiB candidate:
  `8408498e80eeca0c8f3fca251dfb57a94dc23c8ce6b5ca325cbce0854874510f`.
- Tested aa12 boot image:
  `795e8b7fffda6b46e318d1bccc542b3a7d807987a7787f5115f0dcb27b7b9dcb`.
- Existing TWRP 3.7.1_12-0 remains installed. The complete boot partition was
  backed up and verified on the computer before resetting userdata.
- Corrected clean-test ZIP: 1,272,844,557 bytes, SHA256
  `d9718ef979d725e18dedc02379bc6e11ae0db019dee6e986262ff0f154bf2a19`.

Build with make-installer-zip.sh --variant clean-test --version 2026-10-02
using the recorded images. The rootfs itself is the release variant: locked
root, no development password, no .writable_image and no forced development USB
mode. This onboarding test still uses /data/rootfs.img. Conventional system
layout, unified recovery hardware validation and signed local updates remain
separate gates in ota-finalization.md.

## Installer correction and preparation

The first TWRP dry run failed to parse SHA256SUMS. Toybox grep did not accept
the GNU basic-regex optional-character extension in the old pattern. sum_of()
now uses POSIX awk to compare the checksum filename field exactly, allowing
sha256sum's optional leading '*' and ignoring comments. The unchanged boot
and rootfs hashes remain mandatory; integrity checks were not bypassed.

The corrected parser passed that stage in TWRP. The next gate detected actual
stock Android packages.xml and system/users left on userdata. An old
/data/.writable_image was also present. Because the user requested a completely
clean installation, use TWRP's standard Format Data rather than maintaining
custom path-migration scripts. The proposed rename/rollback scripts were never
run and are removed from the current tree.

Verified partition mapping: userdata /dev/block/sda32, boot /dev/block/sda14
(57,671,680 bytes). TWRP's `format data` completed using mke2fs; /data remounted
as ext4 with about 110 GiB free. Old rootfs, stock Android package state and the
writable-image marker were absent. No system/vendor/boot/recovery partition was
formatted by this operation. The old personal data cannot now be restored from
the phone; no backup of it was requested or promised for this reset.

## Remaining execution

1. Transfer the corrected ZIP via ADB, verify its complete hash, and rerun the
   installer's A50_DRYRUN=1 path in TWRP.
2. Use `twrp install /data/ubuntu-touch-a50-clean-test-20261002.zip`. Check boot
   and rootfs read-back results before rebooting.
3. Verify setup wizard, user-chosen credentials, confinement, device services,
   second boot and suspend startup. Install Waydroid through the supported
   documented path and test launch/close/sleep without old Helper/Android state.
4. Record the outcome. One successful boot is insufficient release validation.

Recovery fallback is the still-installed TWRP plus the host's verified boot and
rootfs artifacts. Do not claim the erased development userdata remains available.

Upstream procedure: https://twrp.me/faq/openrecoveryscript.html

A second dry-run defect was 32-bit shell arithmetic overflowing rootfs_bytes.
The size calculation now uses awk and correctly reports 5,324,800 KiB instead
of 1,130,496 KiB. The corrected complete dry run passed in TWRP after Format
Data. Both findings were caught before writing boot or rootfs.

## Installation result

The final ZIP passed verification on the phone. TWRP installation completed and
both boot and rootfs read-back hashes matched the inputs above. The vendor
partition (838,860,800 bytes, /dev/block/sda26) retained SHA256
48f5e9bfb9ef2dfd032ec7c92986ac1c8886abe7d658430b57ccacb5e3cffe3b.
The full recovery partition hash also remained unchanged.

A final metadata check found TWRP's umask created rootfs.img as root:root/0666.
The installer now sets umask 077. Its equivalent was verified in TWRP and the
installed file corrected to root:root/0600 before boot. This last permission
fix is newer than the test ZIP hash above; rebuild from current source before
sharing an installer. No bytes inside the verified filesystem image changed.
First boot was then requested; onboarding and runtime results remain pending.

## First boot failure and corrections (3 October)

First boot panicked in USB configfs before onboarding. Persistent pstore and
journal were retained privately. Experiment 034 records the exact instruction
and the standard configfs replacement. Experiment 035 records the separate
image-layout failure, native LXC hook correction and upstream schedtune typo.
The userdata image now uses the supported self-contained /data/ubuntu.img name.
Fresh boot is pending the corrected kernel build; do not describe this as a
successful new-user installation or OTA-ready release.
