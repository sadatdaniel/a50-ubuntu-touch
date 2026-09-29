# aa12 automatic suspend: wake-count handshake abort

29 September 2026, SM-A505F, aa12 kernel bb78a3b, AppArmor enabled.

The USB-disconnected automatic test successfully activated Android 11
ISuspendControlService.enableAutosuspend (method 1, return true). It started at
20:30:06 CEST. The worker restored inhibition at 20:31:07; the independent
WakeSystem timer also completed at 20:31:56. These are observed times, not a
claim that the timer executed exactly at its nominal 90-second deadline.

Counters changed from success 0/fail 0 to success 0/fail 9, all in freeze with
errno -16. No device-suspend or resume failures were recorded. There was no
reboot, USB SSH returned, AppArmor remained Y, and repowerd, biometryd and
lomiri-location-service were active. This is a failed automatic-sleep test,
not evidence of nine successful sleep/resume cycles.

Every attempt logged Wi-Fi preparation and rollback. Eight aborts named Wi-Fi
wake sources (hip4_wake_lock, wlan or wlan_ma); one named bt_read_wake_lock.
The freezer aborted almost immediately, rather than timing out on a task.

## Cause and next change

The aa12 PM_SUSPEND_PREPARE notifier calls slsi_set_host_suspend_mode(), which
calls slsi_mlme_set_host_state(). The shared MLME transaction path takes wlan_wl
(drivers/net/wireless/scsc/mlme.c). Firmware responses also use HIP wake locks.
Normal Android SystemSuspend saves the wakeup count before requesting sleep;
these new events then invalidate that saved count. pm_wakeup_pending() correctly
aborts when the event count changes, even if the new lock has already expired.

The source and observed immediate aborts establish a self-generated wake-event
problem in the current placement. Background network/Bluetooth traffic can also
contribute; the last named wake source is not a complete event trace. Direct
sysfs sleep success on September 22 did not validate this handshake.

Next: move Wi-Fi host preparation ahead of the wake-count handshake, with paired
restoration, and repeat the bounded automatic test. Do not reset the saved
count, suppress wake sources, or disable AppArmor to make this test pass.

## Test corrections

Samsung kernel/power/wakelock.c uses a **500 ms** timeout when a write to
/sys/power/wake_lock omits the duration. Earlier documentation incorrectly called
this hold indefinite. The corrected scripts use explicit nanoseconds: ten
minutes during setup and one hour during cleanup. Cleanup also runs a transient
repowerd-cli active service (a50-test-awake) to retain inhibition. Neither is a
release configuration. Keep the runtime inhibitor until a controlled test or
reboot; Android's activation API has no disable counterpart.

The UDC state remained configured during a real 126-second cable removal, so
USB disconnection is detected with /sys/class/power_supply/usb/online instead.
Cable removal can wake the lock screen: allow up to 45 seconds for brightness
to return to zero, aborting if USB is reconnected. The final test used these
corrections. Earlier runs stopped before enabling suspend and are not kernel
sleep failures.

The scripts retain exact boot-ID, fallback-boot hash, AppArmor, logger and timer
checks. They are session-specific experiments: update the staging directory,
unique unit names and expected boot ID deliberately before reuse. For this run,
allow three minutes disconnected to cover screen timeout plus the test window.
Raw logs remain private because they contain device/network identifiers.