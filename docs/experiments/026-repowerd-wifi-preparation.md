# Wi-Fi preparation through supported repowerd hooks

29 September 2026. Experimental, not enabled in the release overlay.

## Existing implementations checked first

- [UBports documents the low-power and interactive/sustained script hooks](https://docs.ubports.com/en/latest/porting/configure_test_fix/device_info/Repowerd.html).
- [Android documents the wake-count handshake](https://source.android.com/docs/core/power/systemsuspend): new events after the saved count must cancel suspend.
- [AOSP's Wi-Fi implementation uses SETSUSPENDMODE from userspace](https://android.googlesource.com/platform/frameworks/base/+/a59b1dacd7e7c7494692c79c31b22243e45a0ec4/wifi/java/android/net/wifi/WifiNative.java).
- Current upstream [repowerd source](https://gitlab.com/ubports/development/core/repowerd/-/tree/f3bf63226cc8c348654f75af8fe4cd11ff49333f) matches the installed package revision f3bf63. In `default_state_machine.cpp`, the suspend performance mode runs before `allow_automatic_suspend`. In `script_performance_booster.cpp`, the low-power command is synchronous; restoration when leaving suspend mode is also synchronous.

These are existing mechanisms, not proof of a tested A50-specific fix. Hardware
validation is required. The phone previously used NullPerformanceBooster, so the
script configuration does not displace an active vendor performance backend.

## Candidate

Use RepowerdScriptPerfBoostLowPower to send the vendor Wi-Fi suspend command 1.
Use RepowerdScriptPerfBoostSustained and Interactive to send command 0. This puts
preparation before repowerd releases its HIDL suspend lock. A stale wake-count
read may cause one retry, but the firmware exchange is no longer repeated inside
each kernel suspend attempt. aa12 preserves a prior user_suspend_mode=1, so its
PM notifier skips the firmware transaction and does not own its restoration.

The existing diagnostic ioctl helper is reused because Ubuntu's installed
wpa_cli has no DRIVER command. The wrapper checks that swlan0 exists and is up,
and bounds the helper with timeout. It does not turn a disabled radio on.

`stage-wifi-power-hooks.sh` copies the original device YAML to /run, appends the
three keys to a second copy, and bind-mounts it over the original. A reboot
removes this configuration. `restore-wifi-power-hooks.sh` verifies the copies,
restores normal Wi-Fi mode, unmounts the test configuration, and restarts
repowerd while retaining the test inhibition. No package or kernel replacement
is involved.

Run only on the pinned aa12 test boot, with the existing fallback-boot guard and
AppArmor enabled. Stage the scripts and the existing a50-wifi-suspend-mode.py in
/userdata/a50-session29-aa12. The auto6 scripts retain USB/screen checks and
bounded cleanup and explicitly restore Wi-Fi mode 0 after taking the hold.

## Release limitations to validate

Upstream logs script failure but does not veto suspend on nonzero exit status.
Do not ship this candidate until command failures, Wi-Fi off/on/reconnection,
power-manager restart, screen-on restoration, network wake and repeated idle
cycles are checked. The normal auto-enable path also still needs integration.
No unbounded automatic-suspend enablement or boot-time hook is installed here.

The September 29 auto6 attempt stopped before releasing its safety hold:
Android returned false because its suspend loop had already been started by
auto5. Counters remained unchanged at success 0/fail 9. This does not test the
candidate. The source explicitly returns false for repeated enableAutosuspend.

On October 2 the phone was rebooted back into guarded aa12 after arriving on the
fallback kernel. Actual AppArmor allow/deny enforcement passed. The auto7 script
requires the hook's success marker before releasing the test hold. It accepts a
false activation result only if the Android SystemSuspend process has a worker
blocked in pm_get_wakeup_count under the test hold. Otherwise it aborts. This
keeps failed activation distinguishable from an already-running loop.

Automatic-sleep hardware results remain pending.
