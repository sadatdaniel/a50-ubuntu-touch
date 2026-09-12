# Official recovery and OTA migration

Follow [UBports finalization](https://docs.ubports.com/en/latest/porting/finalize/index.html)
and [unified recovery/local OTA testing](https://docs.ubports.com/en/latest/porting/finalize/UBports_recovery.html).
GitHub development boot-image archives are recovery baselines, not update channels.

Verified on SM-A505F, 2026-09-12:

| Partition | Linux device | Bytes |
| --- | --- | --- |
| boot | sda14 | 57,671,680 |
| recovery | sda15 | 67,633,152 |
| system | sda25 | 5,557,452,800 |
| cache | sda28 | not yet recorded |
| userdata | sda32 | not yet recorded |

The phone currently boots a 16 GiB development rootfs image from ext4 userdata.
The repository's 6144M image setting also exceeds the physical system partition.
Neither image can simply be flashed to system. The installed root has local
changes; a fresh official rootfs plus committed device overlay must be measured
and tested before migration. Preserve user data separately from system artifacts.

The existing deviceinfo disables recovery. The upstream build.sh wrapper clones
an unpinned adaptation-tools branch. Before claiming reproducible OTA artifacts:

1. Pin and use the official halium-generic-adaptation-build-tools recipe; reconcile
   its kernel build with the boot-tested a50-halium source, config and firmware.
2. Enable `deviceinfo_use_unified_recovery`, `deviceinfo_has_recovery_partition`
   and the measured recovery size. Use the upstream density option; 420dpi vendor
   configuration suggests xxhdpi, subject to recovery visual testing.
3. Derive `ramdisk-recovery-overlay/system/etc/recovery.fstab` from vendor/recovery
   metadata. Include ext4 /data and correct boot/recovery/system mountpoints.
   Verify generated /etc/fstab against actual block devices in recovery.
4. Archive and checksum TWRP and known-working boot images. Build unified recovery,
   then verify display, ADB and data/cache mounts before an OTA test.
5. Use upstream prepare-fake-ota.sh and the documented local recovery procedure.
   Any signature-bypass helper is temporary test material and must be removed
   before publication. No bypass has been installed on this phone.
6. Test updater logs, resulting rootfs layout, reboot, retained user data and a
   second update. Validate recovery mode reboot and factory-reset behavior with
   disposable test data or complete recoverable backups.
7. Prepare the UBports installer configuration and request upstream channel/CI
   inclusion with artifact URLs and test evidence. Registration requires upstream
   coordination; changing channel.ini alone does not register this device.

Do not enlarge or overwrite partitions as a shortcut. TWRP and the current
userdata installation remain the recovery path until the new artifacts pass.
Camera/AppArmor and suspend tests retain priority while this migration is prepared.
