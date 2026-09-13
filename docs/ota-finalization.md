# Galaxy A50: suspend and updates

Verified 13 September 2026. Device: SM-A505F.

## Current result

The aa8 watchdog fix survived two freezer-only cycles, a devices-stage cycle,
and more than two hours on the same boot. A separate devices-stage comparison
with USB detached also returned normally and restored USB connectivity.
The user confirmed screen and touch work after these tests.

Full suspend/resume is not validated. An active USB gadget fails to resume
correctly: Windows reports a descriptor failure. Software reconnection recovers
it. The next kernel change must handle gadget quiescing and IRQ locking, then
pass repeated device-stage tests before deeper sleep/wake and battery testing.

## What blocks system updates

| Item | Verified state | Required work |
| --- | --- | --- |
| Installed updater | system-image CLI, service and common packages installed; config.d empty | Supply valid device/channel configuration through the finalized image |
| Root filesystem | /userdata/rootfs.img, 16 GiB image, roughly 4 GiB used | Build a fresh, measured system image with committed adaptations |
| System partition | 5,557,452,800 bytes = 5,300 MiB | Fit the image and update growth allowance within this limit |
| Repository image size | 6,144 MiB | Add a correctly sized finalization build profile; retain the development profile |
| Recovery | Build disabled; physical recovery is 67,633,152 bytes | Build and test unified UBports recovery while preserving TWRP backup |
| Cache | Physical cache is 419,430,400 bytes; live /cache resolves onto userdata | Verify recovery's staging path and capacity rather than assuming it uses physical cache |
| Published aa8 release | Development boot image and symbols | Not an OTA channel; integrate signed update artifacts and metadata |

The existing 16 GiB image cannot be flashed to the 5.18 GiB system partition.
Approximately 4 GiB used makes a fresh image plausible, not yet proven. Keep
Waydroid images and user data outside the system image; measure actual paths
when Waydroid work resumes. No partition resize, migration, recovery replacement
or updater configuration change was performed during this audit.

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
