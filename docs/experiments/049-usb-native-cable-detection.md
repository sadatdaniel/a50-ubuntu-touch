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
