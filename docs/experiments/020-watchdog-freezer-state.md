# Watchdog state across the freezer

## Evidence and focused change

The aa7 ABOX-isolation cycle returned after five seconds, then the phone
rebooted automatically. Recovered persistent logs confirm both ABOX callbacks
were skipped, yet storage, I2C, GPU, sensor-hub and Wi-Fi failures followed.
The final warning was a Wi-Fi confirmation timeout. Samsung's hardlockup hook
rewrote the reported PC; PC=0 did not establish a NULL function call.

The secondary watchdog was armed by the freezer at 124.004070s. Its programmed
count and clock imply about 21 seconds before expiration; the first storage
timeout appeared at 146.630060s. The paired freezer helpers always restarted
this timer, even when it had previously been inactive.

Kernel revision ba9b1083db656b0f8f5f5961c0095a045d3e59eb adds the opt-in
`--watchdog-freezer-fix`. The stop helper saves hardware ENABLE state under
the existing lock; start restores only a previously active timer. Existing
watchdog clients and panic/reset behavior are unchanged. Compiled helper tests
cover active and inactive timers, repeated pairs, an unmatched start and a
missing device. All pass.

## aa8 build and guarded boot

Recipe: full profile, UBports AppArmor, watchdog fix enabled, ABOX isolation
disabled. The separate ABOX uninitialized-log fix is not applied. The resolved
configuration is byte-identical to aa6; AppArmor and hardened usercopy remain
enabled.

- Image: 45,053,968 bytes; SHA256 `e197a4f9a02790fdf21278e33832720ff1cc42b3aab24cd62d0e4f173fbdbda6`.
- Boot image: 55,851,008 bytes; SHA256 `9f219dfa364fb5a0cf279ceaee7563f3371c930649ed528a7c457ce04ba02927`.
- Donor: `90c281f8da080f7bc1a9ec9aa822e0ae10bd19a77804717e0c3f6ea83cffd03b`.
- Unchanged ramdisk: `e78e8cb8d5269e81852a1b417d0b28c98f2c4bce8bcb035e2cab19bd9cfd9ac4`.

Build completed 2026-09-13 03:37:13 UTC. Normal boot succeeded at 08:02 CEST;
AppArmor Y, Android boot_completed=1, lightdm and persistent capture active.
The guard restored the known aa1 image at 08:02:55 CEST. The exact image-sized
partition prefix was verified, the temporary guard removed and root returned
read-only. Running kernel is aa8; on-disk boot remains aa1 for recovery.

## First freezer cycle

Waydroid was stopped normally. No new fault or camera-close blocked task was
present in the baseline. The single freezer-only cycle ran from 08:05:10 to
08:05:15 CEST. Both stop calls logged `was_enabled=0`; both start calls logged
`keeping inactive watchdog stopped`. ABOX powered off, restarted and reported
firmware ready normally. This directly verifies the inactive initial timer
state that previously had only been inferred.

The test service exited successfully, suspend statistics show success=1,
fail=0, and pm_test returned to none. USB and Wi-Fi SSH remained reachable
with unchanged boot identity beyond the old failure window. Longer observation
and repeated cycles remain in progress; do not infer full suspend support.

## Limits

This is evidence for a freezer watchdog-state bug. Device suspend/resume,
deep sleep, automatic suspend and power consumption remain unvalidated.
Waydroid reliability remains pending, camera video is deferred, and this is
not an OTA or stable release. Raw device logs remain local.

## Validation update, 2026-09-13 10:20 CEST

Two freezer-only cycles passed with normal ABOX behavior; the first was
observed for ten minutes before repetition. Both stages of both cycles
confirmed was_enabled=0 and kept the secondary watchdog stopped.

One devices-stage test ran08:19:30–08:19:36 and returned successfully
(success3/fail0 total). Windows then reported Device Descriptor Request
Failed, while the phone believed its USB gadget was configured. Wi-Fi
remained usable; the phone did not reboot. Unbinding/rebinding the existing
g1 UDC restored enumeration, but recreated rndis0 without its address.
Restoring its original10.15.19.82/24 address plus temporary169.254.68.82/16
allowed USB SSH using Windows' existing link-local subnet. Host address
change was denied by Windows administrator permissions; no host setting
was successfully changed. A gadget DCTL stop timeout occurred during the
manual reconnect, separate from the original watchdog failure cascade.

Same aa8 boot remained responsive over both Wi-Fi and recovered USB at
10:20 CEST, over two hours after the devices-stage test. No full deep sleep
attempted. Device-stage return does not establish complete driver resume:
USB still needs a fix. Watchdog correction stays opt-in pending broader
validation. Screen/touch response from user for aa8 remains pending.

## USB-detached comparison, 2026-09-13 10:25–10:27 CEST

One controlled devices-stage comparison detached the existing g1 gadget
before entering pm_test=devices, then reattached it and restored the same
phone USB addresses. Test ran10:25:28–10:25:36, service Result=success,
ExecMainStatus=0, total suspend statistics success4/fail0. Windows recreated
its RNDIS adapter successfully without Device Descriptor Request Failed;
USB SSH to169.254.68.82 worked at10:26:38. Same boot identity, AppArmorY,
Wi-Fi also remained usable. No timeout marker beyond the intentional5s
PM debug delay was present in the immediate post-test check.

This comparison supports active gadget state as the USB resume problem.
It is a diagnostic result, not a production reconnect hook or full sleep fix.
Raw evidence: local a50-ut-out/session-20-aa8/devices-usb-detached-after.dmesg;
remote /userdata/a50-session20-aa8/devices-usb-detached-1/.

Before writing an OTG callback patch, account for this exact tree's lock
hazard: core.c calls dwc3_gadget_suspend under dwc->lock; gadget_suspend calls
synchronize_irq; dwc3_interrupt acquires dwc->lock. Simply invoking the helper
in the OTG branch can deadlock. The IRQ wait must occur outside that lock.
Role-switch serialization, paired active-device state, unplug during sleep,
and propagation of resume failures also need explicit review/testing.
No USB kernel patch applied or new build started. No deeper PM test run.
