# Updating and preserving A50 fixes

Updated 4 October 2026. Ubuntu Touch 26.04 only; this port is still a
development build. [OTA finalization](ota-finalization.md) and the
[release backlog](release-validation-backlog.md) track the current evidence.

## Current update support

Settings OTA is not enabled. A channel.ini naming A50 does not create a hosted
device channel. Unified recovery and the system-layout candidate are only
offline-checked; the currently booted clean installation uses /userdata/ubuntu.img.
A release needs hardware-tested recovery, correctly packaged device/rootfs
components, signature trust, maintained channel metadata and an installer flow.

The next test installation is intended to validate every fix automatically from
first boot. Preserve vendor and the known working recovery fallback. The user
has authorized wiping this development installation, but retained userdata
across subsequent OTA updates remains a separate release requirement. Do not
promise either data preservation or routine destructive reflashing before the
actual update path has been tested.

## Where fixes must live

- Shared application and middleware bugs: upstream fixes in matching native
  packages or the Android image. Pending merges require explicit source
  backports, versioned packages/images and recorded dependencies.
- Kernel corrections: normal reproducible kernel profile and configuration,
  included in the device build and update payload.
- Device settings: supported DeviceInfo fields, packaged configuration and
  native startup hooks in the device tarball. Keep file modes and startup
  symlinks correct in Git and generated archives.

A rebuilt rootfs can replace live edits, runtime mounts and temporary units.
Every required fix therefore needs a build-time home and an update component
that reinstalls it. Temporary USB maintenance SSH and diagnostic mounts are
for development; they are not release prerequisites. Permission bypasses and
unsigned recovery-updater overrides must not ship.

## Reproducibility and regression checks

The scripts and pinned fix sources are reproducible development inputs, not
proof that the current release-image builder includes every tested correction.
Native compatibility package builds exist, including the Waydroid .2 launcher
candidate; explicit rootfs build-time package integration and first-boot/OTA
checks remain. A runtime test, an installed package and a clean-image result
must be recorded as separate milestones. The archived ZIP predates recent fixes.

For Waydroid, .1 passed the first three runtime reopens but failed the next
post-reboot user test. Candidate .2 preserves the main desktop file during
regeneration, passed its stronger regression/build/install and survives reboot.
All three post-reboot user drawer close/reopens and icon persistence pass.
Wider sleep/audio/network and extended-use validation remains open. See
[the complete record](experiments/050-fresh-waydroid.md). This is not evidence
that every upstream update requires redoing every fix; it is an incomplete
fix exposed by an additional required test.

Record the Ubuntu rootfs URL/checksum, kernel source/configuration/patches and
compiler, Android manifest/patches/image checksum, package versions and recovery
inputs. Moving dependencies is a deliberate candidate build, followed by
verification; never silently replace a tested input with lastSuccessfulBuild.

The baseline gsi.lock is still build 1542. The exact Halium PR 84 backport has
passed three temporary camera recording/playback tests, and its complete pinned
image ran out of runner disk space in [run 37172560900](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37172560900).
It must pass filesystem/interface checks and boot/reboot tests before replacing
the baseline. The rootfs builder still consumes the Jenkins pin, and the ZIP
manifest still reads that pin; candidate input/provenance integration is required
before packaging the corrected image. Installing replacement libraries only
on the test phone does not complete this work. The aa15 scheduling correction and Bluetooth protocol availability pass on
aa16/aa17. K380 pairing/typing is user-confirmed; idle/reconnect/sleep checks remain.

Use a testing channel to check clean install, authentication, confinement,
media, app lifecycle, sleep/network recovery and updates before promotion.
Apply a second update and confirm userdata and fixes survive. Review each new
upstream rootfs against the supported device/package interfaces; do not claim
that source pinning prevents every future regression. Remove backports when
the compatible upstream release contains them, instead of maintaining stale
file replacements or freezing all packages indefinitely.

## Conventional OTA path

Follow [UBports unified recovery and OTA finalization](https://docs.ubports.com/en/latest/porting/finalize/UBports_recovery.html).
Validate actual A50 partition mappings, display, USB, staging, reset and reboot
modes. The documented fake-OTA bypass is isolated test material and must never
be included in a published recovery; release updates retain signature checking.
Then validate signed local updates, a maintained system-image channel and the
[installer configuration](https://github.com/ubports/installer-configs).
Samsung requires its supported Download Mode transport rather than assuming
the guide's fastboot examples work. Official UBports hosting/registration
requires coordination; a GitHub artifact alone is not an update channel.
