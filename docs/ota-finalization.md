# Galaxy A50: suspend and updates

Updated 3 October 2026. Device: SM-A505F. Ubuntu Touch 26.04 only.

## Current result

The aa12 kernel and supported repowerd Wi-Fi hooks completed 35 automatic
suspend/resume cycles with zero resume failures. Screen/touch recovered in user
checks. Permanent startup, fresh-boot behavior, service-crash recovery and long
idle/battery validation remain release blockers. The native Android activation
unit has passed an inhibited repowerd restart test, not a fresh boot.
See [the release backlog](release-validation-backlog.md) and
[activation lifecycle](experiments/032-native-suspend-startup.md).

## Enabling OTA on this phone

The clean test installation uses /userdata/ubuntu.img, the existing Halium
layout for an embedded Android image. Its initial rootfs.img filename selected
the separate-image layout and failed; see experiment 035. Fresh boot remains
pending the USB kernel correction in experiment 034. It does not yet have
a working A50 update channel. A newer rootfs alone cannot enable OTA.

The planned one-time migration needs a compatible boot image and system layout,
tested UBports recovery, and a signed update channel. Back up and verify user
data and recovery before performing it. After migration and validation, ordinary
updates should use System Settings rather than manual flashing. Data preservation
is a test requirement, not a promise based on the offline build.

| Item | Verified state | Required work |
| --- | --- | --- |
| Root filesystem | Current boot still uses userdata image; clean 26.04 full-376 candidate built read-only | Validate fresh boot/onboarding and boot from the final layout |
| Image size | Candidate 5,452,595,200 bytes (5,200 MiB); measured system 5,557,452,800 bytes (5,300 MiB) | Validate on hardware and retain growth allowance inside the filesystem |
| Recovery | Unified recovery candidate built and checked offline; 62,095,360 bytes fits 67,633,152-byte partition | Test display, ADB, mounts, reboot modes; preserve TWRP fallback |
| Cache | Unified recovery candidate uses userdata-backed cache | Verify actual recovery staging and available capacity |
| Image adaptations | Audio uses upstream DeviceInfo; container files generated under /run; polkit fallback baked into candidate | Verify clean boot and survival across rootfs OTA, especially helper ownership/mode |
| Update service | Generated channel config is not a registered/hosted A50 channel | Signed artifacts, metadata, key trust and UBports integration or maintained hosting |
| Installer | Samsung transport must be validated | Verified downloads and A50 installer configuration; do not assume fastboot |

Latest offline rootfs SHA256:
`a92dbb720e5523b74703e1bd9444205f0e5a21756e7835c44e572181f014295d`.
This candidate now includes the native LXC hook and partition-probe corrections.
Runtime suspend experiments are not permanent release configuration. A clean
userdata image was installed with TWRP; no candidate system-partition or unified
recovery image has been flashed. The original ZIP predates these fixes and must
be rebuilt before sharing.

## Implementation sequence

1. Finish USB resume and validate full suspend/wake, including repeated cycles,
   networking, display/touch and delayed stability. Automatic screen-off sleep
   and battery behavior require their own checks.
2. Pin the adaptation build tools and reconcile their kernel build with the
   tested a50-halium source, configuration, patches and firmware. Build a fresh
   system image with room for updates; preserve userdata and recovery backups.
3. Enable unified UBports recovery in the finalization build. Derive the fstab
   from this device's metadata and verify data, cache, system, boot and recovery
   mappings on the phone. Validate display, ADB, mounts and reboot modes before
   any update. The initial density candidate is xxhdpi, subject to visual tests.
   Additional UI properties belong in prop.halium; add only verified needs.
4. Run the documented local OTA procedure with an isolated test build. Verify
   logs, resulting boot, retained user data and a second update. The documented
   fake-OTA signature bypass is temporary test material and must not ship.
   Published updates must retain signature verification.
5. Coordinate device/channel and build integration with UBports. A local OTA
   proves the updater path, not official channel registration. Merely writing
   channel.ini or publishing a GitHub boot image cannot provide ongoing OTAs.
6. Prepare the A50 installer YAML against the actual installer schema. Verify
   Samsung Download Mode/Heimdall transport and partition names; do not copy the
   guide's fastboot commands blindly. Use recovery verification, validate the
   schema and downloads, test the local config and then submit it upstream.
7. Later, establish Waydroid reliability with repeated launch/stop cycles,
   compositor restarts, sleep/wake, networking, sound, updates and extended use.
   One successful launch is insufficient; an absolute stability guarantee would
   be unsupported. Camera video remains deferred.

Recovery and OTA preparation can proceed while suspend is being fixed. Daily-use
readiness and update readiness are separate validation targets.

## Sources

- [UBports finalization](https://docs.ubports.com/en/latest/porting/finalize/index.html)
- [Unified recovery, additional configuration and local OTA](https://docs.ubports.com/en/latest/porting/finalize/UBports_recovery.html)
- [Installer documentation (currently a placeholder)](https://docs.ubports.com/en/latest/porting/finalize/UBports_installer.html)
- [Installer configuration and local validation](https://github.com/ubports/installer-configs)
- [Installer actions: Heimdall and recovery verification](https://github.com/ubports/installer-configs/blob/master/v2/schema/action.schema.yml)
- [aa8 development release](https://github.com/sadatdaniel/a50-halium/releases/tag/a50-ubports-halium-2026-09-13-aa8)
