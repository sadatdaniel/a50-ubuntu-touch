# aa12: early Wi-Fi preparation, 22 September 2026

Development candidate, not a final-release suspend claim.

Source: a50-halium `bb78a3b`. Build completed successfully. Image SHA256:
`95aaa07b376e8b2f873742466e6527af142639fa61d1d4e922355dbc43148d61`.
Boot SHA256:
`795e8b7fffda6b46e318d1bccc542b3a7d807987a7787f5115f0dcb27b7b9dcb`.
Boot size 55,851,008 bytes, using the unchanged aa11 ramdisk.

The candidate booted with AppArmor enabled. The early boot guard restored the
verified aa1 fallback on disk. Recovery and userdata were not flashed. A temporary
AppArmor profile passed the allowed/denied read check and was unloaded. Runtime
overrides removed biometry/location testing bypasses; both services remained
active and their process environments were checked.

Freezer, devices, and core diagnostics passed. Wi-Fi preparation now executes
in PM_SUSPEND_PREPARE and restoration in PM_POST_SUSPEND, including the freezer
test. USB and Wi-Fi restoration reported result 0.

First full suspend: 0.011 seconds, MIF blocked, connection request 0x20000.
Second full suspend: **11.065 seconds with Wi-Fi connected**, MIF power-down count
increased to 80, wake status 0x80020000. No manual SETSUSPENDMODE command or fixed
delay was used. These observations demonstrate actual deep sleep in the second
attempt but do not establish that timing alone caused the difference; network
traffic differs between attempts. Packet-triggered wakes are not considered a
proven bug, and broader wake investigation is deferred at the user's request.

## Automatic screen-off suspend: separate integration gap

The installed repowerd binary contains HidlSystemPowerControl. Android's
suspend_control service reports a repowerd wake lock that became inactive, but
its service process had only three Binder threads and no autosuspend loop thread.
No spontaneous kernel suspend attempts were recorded between manual tests.

Current upstream repowerd HidlSystemPowerControl acquires/releases the HIDL wake
lock; start_processing and suspend are empty. Android 11 SystemSuspend creates
its automatic loop only when SuspendControlService::enableAutosuspend is called.
The device's system_suspend init service starts the daemon but has no enabling
command in the inspected system/vendor init configuration.

This supports a missing activation path, not proof that simply enabling the loop
is a complete fix. Investigate startup ownership, service restart handling,
screen-on inhibition and a bounded rollback before enabling automatic suspend.
No automatic-suspend enable command was issued in this checkpoint.

Sources inspected:

- https://gitlab.com/ubports/development/core/repowerd/-/raw/main/src/adapters/hidl_system_power_control.cpp
- https://android.googlesource.com/platform/system/hardware/interfaces/+/refs/heads/android11-release/suspend/1.0/default/SystemSuspend.cpp
- https://android.googlesource.com/platform/system/hardware/interfaces/+/refs/heads/android11-release/suspend/1.0/default/SuspendControlService.cpp

## Recovery packaging audit

TWRP's recovery-DTBO region is 8,388,608 bytes. Its table declares 656,572 bytes,
but 2,059 non-zero bytes remain beyond that declared size. Do not trim it as
zero padding. Its ramdisk load address is 0x11000000; preserve the recovery header
layout rather than applying boot-image assumptions. Unified recovery has no
device recovery.fstab in the inspected archive and uses RGBX_8888, while TWRP
uses ABGR_8888. Device configuration and image sizing remain unresolved.

The experiment scripts retain boot identity, fallback hash, AppArmor, gadget,
logging and RTC-alarm guards. Raw logs stay private because they include network
addresses and packet contents. TWRP remains the recovery fallback.

## Final hardware checkpoint

The third full-suspend attempt aborted at alarmtimer with -16. Wi-Fi and USB
restored with result 0 on this abort path. Final counters: success 5, fail 1
(alarmtimer), all resume failures 0. pm_test returned to none and the test RTC
alarm was cleared. AppArmor remained enabled, UI and Android services active,
and USB and Wi-Fi addresses present. Current boot ID:
06a64389-d7a5-4a11-9903-8c545004d130. No manual restart is needed.
