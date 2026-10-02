# Native Android suspend activation lifecycle

October 2, 2026. Repowerd upstream f3bf632 has an empty HIDL start_processing()
and only manages wake locks; it never starts Android 11's automatic loop.
AOSP Android 11's ISuspendControlService method 1 activates that loop. Method 3
forces suspend and must not be used here. The old libsuspend implementation
starts a separate sysfs loop and is not a substitute for this HIDL-managed loop.

The experimental a50-enable-autosuspend.service uses the existing Android service
client after repowerd is ready. Requires/After/WantedBy connect startup, and
PartOf reruns it after a repowerd restart. A failed activation unit does not tear
down repowerd. The helper rejects a different Android SDK or unexpected Binder
reply and bounds each client call. It does not bypass wake locks or wake counts.

Source checked: Android 11 suspend/1.0/default/main.cpp registers suspend_control,
constructs SystemSuspend (which sets the control service's weak pointer), then
registers the HIDL service. Therefore after repowerd connects to HIDL, the control
pointer exists. enableAutosuspend returns true on first initialization and false
when already initialized. The lifecycle experiment additionally verified the
repowerd wake lock in dumpsys before running either call.

https://android.googlesource.com/platform/system/hardware/interfaces/+/refs/heads/android11-release/suspend/1.0/default/main.cpp
https://android.googlesource.com/platform/system/hardware/interfaces/+/refs/heads/android11-release/suspend/1.0/default/SystemSuspend.cpp
https://gitlab.com/ubports/development/core/repowerd/-/blob/f3bf63226cc8c348654f75af8fe4cd11ff49333f/src/adapters/hidl_system_power_control.cpp

On the current aa12 boot, with USB and explicit inhibition, initial unit start
reported already active. Restarting repowerd generated a new activation-unit
InvocationID and another successful already-active result. Both power services
and the activation unit stayed active. This verifies lifecycle wiring and
idempotent calls, not first activation after a fresh boot or additional sleep.

Only runtime units were installed under /run/systemd/system. The helper is in
/userdata/a50-session29-aa12; there is no persistent boot enablement. Rollback:
`systemctl disable --runtime --now a50-enable-autosuspend.service`. Stopping this
unit cannot disable Android's already running loop; retain the awake inhibitor
until a guarded sleep test or reboot. The user is currently away from the phone,
so fresh-boot validation is deferred and no reboot was performed.

Container/SystemSuspend crash recovery remains unvalidated. Current upstream
repowerd does not reconnect its HIDL client after service death. Do not claim a
fully restart-safe release based only on this power-daemon restart test.
