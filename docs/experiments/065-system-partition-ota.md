# 065 — First OTA install: system-partition layout via system-image-upgrader

19 October 2026, owner present. Method: UBports "Testing local OTA"
(`docs.ubports.com/.../finalize/UBports_recovery.html`).

## Result

The phone moved from the legacy `/userdata/ubuntu.img` layout to the
**system-partition layout** with UBports' own `system-image-upgrader`:
`/` is `/dev/disk/by-partlabel/system` (ext4, RO; 5.1 GiB, 1.6 GiB free),
`systempart=` is on the kernel command line, GSI 1585 is installed, the
validated cohort is present (e.g. Lomiri `+a50state.4`, tar `+a50openat2.1`),
the variant is release, AppArmor Y, and the channel is
`26.04-1.x/arm64/android9plus/daily` with device `a50`. Home data survived. The
updater flashed boot and the normal recovery from the device tarball, ending
with `Done upgrading...`.

## Inputs (all pinned)

| Component | Identity |
|---|---|
| `rootfs.tar.xz` | `build-ota-rootfs.sh` on official rootfs `809e340e` + 18-package bundle → `6865fad1…` |
| GSI | Jenkins 1585 `d08a92e4…` |
| `device_a50.tar.xz` | `build-device-tarball.sh --boot boot-rf2sp.img --recovery recovery-rf2-h14-572d.img` → `ced1a258…` |
| boot | rf2 + `--systempart` (a50-halium CI 39228141141), boot `dc71ee9c…` |
| recovery | unified recovery `b2c75255…` (experiment 064) |
| keyrings | system-image.ubports.com image-master/image-signing |

`prepare-local-ota.sh` (with `FORMAT=1`) wrote the ubuntu_command in UBports'
`prepare-fake-ota.sh` order. As the docs prescribe for local tests, a
test-only recovery bypassed `verify_signature` (`build-unified-recovery.py
--test-upgrader`, image `36cc0fd6…`). The OTA replaced it with the normal
recovery. Never ship a `--test-upgrader` image; real channels sign every file.

## Why the kernel changed

S-Boot drops the boot header command line, so `systempart=` is compiled into
`CONFIG_CMDLINE` (`build-kernel.sh --systempart`). The initramfs prefers
`systempart=` over `ubuntu.img`, so this kernel is only for the partition layout.

## Rollback

Hash-checked backup: `/userdata/a50-ota-test/ubuntu.img.bak` (`8de4062e…`). The
updater also left `/userdata/ubuntu.img` in place. From recovery (root ADB):
flash `boot-aa17rf2.img` with `flash-boot-image.sh` (current `dc71ee9c…`); the
image file then wins again.

## Second OTA, 19 October: user data retained, camera restored

The first install lost the camera app's Qt5 `Lomiri.Action`. On the old system
it had been installed by hand (experiment 042), while the 26.04 rootfs ships
only the Qt6 module. Two official, pool-identical archives
(`lomiri-action-api` 1.2.2) joined the lock, which now holds 20 packages. A
package-list comparison against the old system found nothing else ours
missing; the 7 evolution-data-server libraries left upstream between the
2 Oct and 11 Oct rootfs.

The second OTA used the same method: rootfs `ad4b0313…` (20 packages), GSI
1585, and device tarball `e924c055…` (expanded cutouts 147px). As system-image
does for full images, `ubuntu_command` starts with `format system`, which
formats only the system partition. Updater: `Done upgrading...`; it flashed
only recovery (test → normal) because boot was already identical. **User data
survived**: 88 home entries and 10 camera recordings, as before. The owner
confirms camera record/Stop/playback, apps and Wi-Fi. Two OTA installs on the
system-partition layout have now succeeded with retained userdata (unsigned,
local test method).

## Third OTA, 19 October: clean boot

Rootfs `266d1fb8…` (lock with Waydroid `+fdclose.1`; console-setup cache
marked one second newer than its config in `finalize-rootfs.sh`), device
tarball `9bbce934…` (expanded corners 40px), GSI 1585. `Done upgrading...`;
only recovery was flashed (test → normal). **Zero failed units**: the
console-setup failure is gone. Waydroid fdclose.1 is installed. User data
retained (90 home entries, 11 recordings, 3 screenshots, unchanged). Three
consecutive OTA installs have now retained userdata.

## Open

- console-setup root cause is upstream: the rootfs stores cache and config with
  identical whole-second mtimes. Worth reporting to rootfs-builder-debos.
- Signed channel (real signatures) for distribution; installer config.
