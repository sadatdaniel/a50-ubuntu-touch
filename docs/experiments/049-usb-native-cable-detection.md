# Replace the old always-connected USB setting with native detection

4 October 2026. Fresh aa13 passed two real deep-suspend cycles, but ADB returned
offline after physical reconnect and required a Developer Mode toggle.

The installed USB manager command line contained both -r (rescue) and -f
(always connected). The device-specific configuration introduced -f on
September 8 to recover boot-time USB on an older kernel/image. Its comment
claimed cable detection was unavailable. That statement requires revalidation
on aa13: the actual /sys/devices/platform/battery/power_supply/usb exposes
POWER_SUPPLY_ONLINE=1 for the connected PC, and the manager already finds it.

## Existing upstream behavior

Installed package: usb-moded 0.86.0+mer69, UBports packaging 098e3a.
The package's debian/ubports.source_location pins upstream
[dd4f9303bd8c48c35071accfd046bb1b7b171771](https://github.com/sailfishos/usb-moded/tree/dd4f9303bd8c48c35071accfd046bb1b7b171771).
Its src/usb_moded-udev.c reads POWER_SUPPLY_PRESENT or ONLINE. Missing TYPE
fallbacks to PC-connected when ONLINE=1; ONLINE=0 is disconnected. Default
charger tracking is enabled on /sys/class/power_supply/usb, power_supply
subsystem; Android tracking defaults off. UBports packaging patches do not
replace this detector. No guessed configuration keys or udev rules are needed.

The [UBports configuration guide](https://docs.ubports.com/en/latest/porting/configure_test_fix/USBModed.html)
also recommends clearing USB_MODED_ARGS to disable rescue mode for release.
The exact upstream usb_moded.c initializes the udev listener even with -f,
then forces the initial control state to PC-connected. Later udev events still
reach control_set_cable_state. Therefore -f does not itself disable later
cable events, and its removal is not a proven reconnect fix. Inspect actual
power-supply event delivery and daemon lifecycle before assigning the cause.

## Reversible runtime test

usb-cable-detection-test.sh uses the existing service's /run/usb-moded/*.conf
EnvironmentFile interface to clear the hardware adaptation flag and replace
rescue mode with diagnostic logging. It keeps the saved rndis_adb mode and
normal host authorization. A native timed kernel hold excludes deep sleep,
so the first physical test isolates cable detection and daemon lifecycle.
An independent six-minute calendar timer runs the hash-guarded rollback script
which removes only the test file and restarts the manager with its old settings.
Nothing is written to vendor, system image or global authentication policy.

Stage both scripts in /userdata/a50-usb-detection-20261004, record the verified
boot ID in expected-boot-id, and run the test through a detached oneshot service.
Preconditions are root, expected boot, AppArmor Y, connected USB, saved mode
rndis_adb, and no existing test EnvironmentFile. Reconnect maintenance forwarding
after the daemon restart. Inspect its candidate command line and active rollback
timer, then ask for an awake 15-second cable disconnect/reconnect without any
Developer Mode toggle. Collect bounded manager/adbd/udev evidence, confirm the
unchanged boot ID, and run rollback unless proceeding to a separately guarded
sleep test.

Initial manager restart passed: normal authorized ADB and localhost maintenance
returned, mode remained rndis_adb, and the command line is --systemd
--force-syslog -D, with neither -f nor -r. The physical reconnect was not confirmed within this candidate's six-minute
window. Its timer restored the original -r -f command line at 03:43:51 UTC,
and authorized ADB returned again. No reconnect fix is claimed. The temporary
hold and event collector ended, with the same boot and suspend counters 2/0.
Clean boot, repeated cable operations, deep sleep, charging/MTP/tethering and
actual release USB IDs remain distinct validation requirements.

A separate bounded 120-second udevadm monitor --kernel --udev --property
--subsystem-match=power_supply trace is staged through a runtime oneshot unit,
writing only private power-supply-events.log. It is needed to distinguish a
changed sysfs value from delivery of the corresponding kernel/udev event.

## Source lead and existing alternative detector

The preserved Samsung drivers/battery_v2/sec_battery.c calls
power_supply_changed for psy_bat, but inspection found no equivalent USB-supply
notification. USB ONLINE can therefore change when read directly without
notifying a daemon watching the USB supply. The 120-second trace contained
ordinary battery events only, but no confirmed physical disconnect took place
in that capture: it does not prove the behavior during cable removal.

A conventional alternative already exists in the exact installed manager:
[android_tracking in usb_moded-config.h](https://github.com/sailfishos/usb-moded/blob/dd4f9303bd8c48c35071accfd046bb1b7b171771/src/usb_moded-config.h).
It tracks /sys/class/android_usb/android0 state and USB_STATE events, then
refreshes charger properties before evaluating connectivity. The A50 exposes
that node and currently reports CONFIGURED. This upstream option is preferable
to inventing a watcher or patching the battery driver before event evidence.
Next: capture both android_usb and power_supply events around a confirmed
physical unplug/reconnect, then test [udev] android_tracking=1 with a guarded
runtime configuration and rollback. No new kernel patch or permanent USB
configuration was applied in this experiment.

## Confirmed Android-detector cable test: failed

The second phase used --android-tracking and a separate android-1 private
output directory. The updated scripts schedule rollback after ten minutes
and bound the awake hold to eleven minutes. A bind-mounted runtime INI enabled
only [udev] android_tracking=1; root stayed read-only. Hash guards restore the
placeholder INI and remove only this experiment's runtime EnvironmentFile.
An EXIT trap also rolls back unsuccessful setup. Stage both scripts and the
expected-boot-id file in /userdata/a50-usb-detection-20261004/android-1 and invoke
the detached test with --android-tracking. The timer uses the same argument.
Do not install this failed detector configuration in the image.

Startup passed at 03:59:17 UTC: saved rndis_adb, normal authorized ADB, and
CONFIGURED state returned with the candidate command line. The confirmed
awake physical cable removal was recorded at 04:00:04 UTC; battery events
show reinsertion about 46 seconds later. The ten-minute trace contains battery
ONLINE 4 -> 1 -> 4 and Android DISCONNECTED on removal, but zero
POWER_SUPPLY_NAME=usb events. The manager read online=0 and stopped adbd on
removal. There was no Android return event to re-evaluate the reinserted cable.
USB remained unavailable. This isolates the problem from deep sleep: the boot
ID stayed the same and suspend counters stayed success=2/fail=0.

Rollback completed at 04:09:16 UTC and restored the original INI and flags,
but a Developer Mode toggle was still required to restore ADB. At collection,
USB ONLINE=1 and android0 CONFIGURED, AppArmor Y, read-only root and no test
wake hold remained. The bounded collector's expected timeout status 124 was
cleared from systemd's failed list after preserving the evidence. Future
collector units should set SuccessExitStatus=124. Private logs stay private.

The matching conventional correction is documented in the
[Sailfish porting guide](https://sailfishos.wiki/books/hardware/page/hadk-hot)
and implemented in this [Samsung Exynos5433 cable-work commit](https://github.com/edp17/android_kernel_samsung_exynos5433/commit/b57dfff88bb9149de5e5966e08543442a8207909).
It notifies the USB power supply once after cable changes rather than during
periodic battery polling. The A50 adaptation is a single existing Linux helper
call. Kernel candidate aa16 compiled and packed from the guarded aa15 cache. Its
config is unchanged and the boot image fits; a verified working aa13 fallback
and guarded test scripts are staged. No flash has occurred. See a50-halium/docs/usb-supply-cable-events.md. Hardware validation
and the graphical Restart/other release blockers remain separate work.

## aa16 notifications passed; controller reconnect remained broken

Controlled aa16 boot passed. The awake test kept the user's charging_only_adb
mode; standard mtp_adb and rndis_adb are also accepted without forcing a mode.
No Android tracking or -r/-f was enabled. A confirmed removal at 09:04:51 and
reinsertion at 09:05:21 Berlin produced two USB kernel and two USB udev events,
ONLINE 1 -> 0 -> 1, manager detection and adbd stop/start. Suspend stayed 0/0.
Reinserted DWC3 skipped pullup(1) as "already on": its earlier off request had
returned before updating cached state while runtime-suspended. Developer Mode
restored USB. Runtime test files/hold were removed at 09:12:13; collector exit
143 from intentional stop was inspected and cleared. New collectors accept
124 and 143 as expected statuses rather than appearing as health failures.

aa17 adapts upstream DWC3 ordering to preserve pull-up intent before the
powered-off return. The actual-function regression fails on the original and
passes on the patch. Compilation, header/partition checks and controlled boot
passed; user confirms display/touch. Existing test/rollback scripts now support
--aa17 with exact boot-image guards. Physical USB recovery is still being tested.
Kernel source/provenance and guarded reproduction are documented in the kernel
repository's docs/usb-pullup-state.md. Do not ship a daemon-reset workaround or
advertise sleep/USB stability before real hardware validation.

## aa17 hardware result: awake reconnect and real sleep passed

4 October: three awake cable removal/reinsert cycles returned authorized ADB
automatically, without Developer Mode toggles. Native power-supply detection
reported every ONLINE transition; adbd stopped on removal and produced a new
FUNCTIONFS_ENABLE on reinsert. The first removal/reinsert was 09:32:40/09:33:10,
then 09:36:09/09:36:32 and 09:36:54/09:37:18 Berlin. All used the same kernel
boot. This supersedes the pending hardware result above.

The established native automatic-suspend test then completed four deep cycles,
success 0 -> 4, with zero suspend or resume failures. The current-boot sleep
durations were 2.267, 14.621, 14.578 and 55.943 seconds: 87.409 seconds total.
Ignore the earlier boot's two records in the append-only private logger. Wi-Fi
data wakes were followed by automatic resuspend; the calendar wake deadline was
07:42:42 UTC and cleanup began one second later. No forced mem write was used.
The owner confirmed screen/touch. Wi-Fi association returned; USB reinsert at
09:44:14 produced FUNCTIONFS_ENABLE immediately and authorized host transport,
with no Developer Mode toggle. Internet routing and longer drain/soak checks
are separate. AppArmor's real allow/deny probe and RFCOMM/L2CAP socket creation
passed after this test; root read-only, same boot, protected hashes unchanged
and no failed system units.

The USB manager still sometimes reports a charging-mode UDC write failure
after the controller has powered off on removal, followed by fallback to
undefined. Reconnect now succeeds despite that message. This remaining mode
transition warning and MTP/wall-charger behavior are recorded for validation;
do not claim every USB mode is stable from ADB tests.

At 09:47:30 Berlin, the exact tested native settings were installed through the
packaged device EnvironmentFile interface. USB_MODED_ARGS and hardware adaptation
args are empty, removing old rescue/always-connected flags. No Android tracking,
polling daemon, automatic adbd restart hook or debug flag ships. The generated
daemon command is /usr/sbin/usb_moded --systemd --force-syslog. Temporary files,
timers, collectors and test wake holds were removed; read-only root and normal
authorized debugging returned. The root filesystem overlay and guarded
scripts/experiments/apply-aa17-native-usb.sh reproduce this configuration.
Backup configuration remains private in /userdata/a50-aa17-test; restoring its
original-usb-config.conf and restarting USB is the configuration rollback.
The boot fallback is independent. Final normal-configuration cable check and
clean-image/first-boot/OTA regression remain distinct validation steps.

Final normal-configuration cable cycle passed at 09:48:22/09:48:59 Berlin,
with FUNCTIONFS_ENABLE at 09:49:00 and host transport authorized. No -r/-f/-D,
runtime overrides or test wake holds remained; same boot, root read-only,
suspend counters still 4/0 and no failed system units. Four awake reconnects
and one bounded multi-cycle sleep test are verified; longer soak is pending.
