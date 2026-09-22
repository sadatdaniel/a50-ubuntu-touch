# Automatic suspend activation probe, aa12

22 September 2026, SM-A505F, running aa12 with AppArmor enabled.

Android 11's official ISuspendControlService AIDL declares enableAutosuspend()
as its first method, with no arguments and a boolean return. The device exposes
the suspend_control service. The normal suspend loop was absent before testing:
the system_suspend process had only its three Binder threads.

The bounded probe invokes `service call suspend_control 1` inside the Android
container. It does not invoke forceSuspend (method 3). The reply was
`Parcel(00000000 00000001)`, indicating no exception and true. A fourth thread
appeared, blocked in pm_get_wakeup_count, establishing that the automatic loop
started. Kernel suspend counters remained unchanged with the USB cable attached.

The kernel reported usb_notify and dwc3-otg wake sources continuously active
while connected. This explains why starting the loop alone cannot demonstrate
ordinary idle suspend with the cable connected. Prior direct sysfs sleep tests
do not establish normal wake-lock-aware behavior.

## Guard and scope

The test first takes a temporary kernel wake lock, then arms an independent
systemd timer with WakeSystem=yes and a 90-second deadline. Only after checking
the timer and activation result does it release the test lock. A worker restores
the lock after 60 seconds; the independent timer also restores it if the worker
has slept. Both capture evidence. The final a50-auto-test-hold lock deliberately
keeps the phone awake until controlled follow-up or reboot; it is not a release
configuration. Android 11's activation call has no corresponding disable method.

No boot-time activation hook has been installed. A real screen-off test with USB
disconnected, screen-on inhibition, wake and re-suspend, service restart handling,
and battery measurements remain required. Do not ship this diagnostic hold.

Source:
https://android.googlesource.com/platform/system/hardware/interfaces/+/refs/heads/android11-release/suspend/aidl/android/system/suspend/ISuspendControlService.aidl

The 60-second worker completed successfully and the recovery timer fired.
The a50-auto-test-hold lock was verified afterward. Counters remained success 5,
fail 1 (the earlier alarmtimer abort), with all resume failures zero. UI, Android
and repowerd remained active. No automatic-sleep reliability claim follows from
this USB-attached activation test.
