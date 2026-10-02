# Wi-Fi preparation in the device overlay

October 2, 2026. The measured repowerd preparation from experiments 026/027 is
now represented by the normal device YAML and one Python standard-library
helper, `/usr/local/bin/a50-wifi-power.py`. It sends the existing Samsung SCSC
SETSUSPENDMODE private ioctl, using the same arm64 ABI exercised in the tests.
No new daemon, polling loop, package dependency or direct forced suspend.

## Upstream convention and ordering

https://docs.ubports.com/en/latest/porting/configure_test_fix/device_info/Repowerd.html
provides the ScriptPerformanceBooster hooks. Upstream repowerd main was checked
again on October 2 and remains f3bf63226cc8c348654f75af8fe4cd11ff49333f,
matching the installed package. The state machine calls low-power synchronously
before releasing its HIDL wake lock. Leaving suspend executes the sustained or
interactive hook synchronously. Both restore host mode 0. The helper leaves an
absent or administratively down swlan0 alone; NetworkManager owns radio state.

The ioctl definitions come from Samsung scsc/ioctl.h and ioctl.c. The aa12 kernel
notifier (a50-halium bb78a3b) preserves an already prepared mode. Keep this kernel
and overlay paired. Earlier notifier placement caused saved-wakeup-count aborts.
The configuration invokes the existing timeout utility with an eight-second
limit. An ioctl error remains an error and appears in repowerd's journal.

The script booster does not veto suspend when a hook fails. The aa12 kernel
prepare path remains present, but failure injection and restoration-failure
recovery are not yet validated. Do not call this a complete release solution.

## Hardware checks

USB remained connected, AppArmor enabled, and the runtime awake inhibitor held.
The experimental helper and then the packaged helper each passed:

- Wi-Fi gateway reachability as the normal phablet user.
- Radio disabled: mode 1 and mode 0 calls do not re-enable it.
- Radio enabled again: reconnect and gateway reachability.
- repowerd restart followed by restored runtime inhibition and working network.

The packaged helper also accepted mode 1 followed by mode 0 while held awake.
Syntax validation passed on the phone. The initial root ping probe was denied;
phablet's existing Android network groups allow it. No permission/security change
was needed. The root filesystem was briefly writable for helper installation
and immediately restored read-only. AppArmor stayed Y, both power services were
active, and suspend counters remained 35 successes / 3 earlier failures, with
zero resume failures. These awake checks add no new sleep-cycle evidence.

`check-wifi-overlay.sh` reproduces the guarded off/on/restart checks. It is an
experiment, not a boot service: stage the expected boot ID deliberately and keep
USB connected. It restores Wi-Fi on exit and uses the normal user's network
permissions. It requires Wi-Fi to be enabled initially.

## Current phone and remaining integration

The installed helper is at its final path. The YAML selection is still the
reversible runtime bind mount under `/run/a50-wifi-power-hooks`; reboot removes
that selection. The old experimental mode-marker file is no longer updated by
this helper. Do not reuse marker-dependent auto7 tests unchanged: restage their
experimental hook first, or update their detector deliberately.

Rollback: while retaining wake inhibition, run the packaged helper with mode 0,
then use `restore-wifi-power-hooks.sh` to restore the original device YAML and
restart repowerd and the inhibitor. The unused helper can remain inert on disk.
The original rootfs YAML has not been changed on this phone.

Automatic Android suspend activation is still manually staged. Current upstream
HidlSystemPowerControl manages wake locks but does not call enableAutosuspend;
its start_processing() is empty. A conventional startup/restart solution and
fresh-boot validation remain required. Also pending: packaged-hook deep sleep,
network after resume, screen-on inhibition, longer idle and battery drain.
The clean rootfs candidate predates this overlay and must be rebuilt later.
