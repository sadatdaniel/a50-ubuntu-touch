# aa11 Wi-Fi sleep bridge: hardware results, 22 September 2026

Status: experimental; not release-ready suspend support.

Kernel source: a50-halium `9726a20`. Includes AppArmor, hardened usercopy,
watchdog state preservation, USB OTG core restoration, and the Wi-Fi PM bridge.
Image SHA256: `c61a6d51b7f239813dfac6fcde5b1464acb1fbdc212835b14685910937fe12b2`.
Boot SHA256: `0b227f579e6cb2a64d24753d7c7236103a1159769f3fc355f8e7f52f2bd29e06`.
Boot size: 55,851,008 bytes. Hardware: SM-A505F.

The candidate booted successfully. The early restore guard verified and restored
the known-good aa1 image to the boot partition; aa11 remains running in memory.
Recovery/TWRP and userdata were not flashed.

## Security checks

AppArmor enabled. A temporary enforcing profile allowed its permitted file read
and rejected its forbidden read, then was unloaded. Biometry and location services
were restarted with runtime-only UnsetEnvironment overrides; both were active
and their process environments contained neither old testing bypass. Persistent
fallback-era bypass configuration still needs removal from the final image.

## Suspend results

Freezer, devices, and core diagnostic stages passed. The Wi-Fi bridge logged
automatic preparation and restoration with result 0. USB OTG restoration also
reported result 0. No resume failure was counted.

Two full suspend attempts with Wi-Fi enabled each slept only 0.011 seconds.
Both reported MIF blocked, previous connection request 0x20000, with no MIF
power-down count increase. The first logged an incoming IPv6 TCP data frame at
wake-up. These are not successful long-idle tests despite the success counter.

A comparison used the existing vendor SETSUSPENDMODE command three seconds
before full suspend. It slept 0.970 seconds, with MIF down count increasing to 4,
then woke with an incoming IPv4 TCP frame. The temporary vendor mode was restored
to 0 afterward. This supports investigating preparation timing; it does not prove
that a fixed delay is the correct production solution or that network wakes are
unwanted. Notifications must remain functional.

Final counters after these six tests: success 6, fail 0, all resume failures 0.
USB SSH worked immediately after tests but a later connection timed out/aborted;
Wi-Fi SSH remained usable and the gadget reported configured. Delayed USB
reliability remains unproven and must not be described as fixed.

## Reproduction and next steps

The aa11 experiment scripts retain boot identity, fallback hash, AppArmor, USB,
logging, and alarm checks. Run stages individually and inspect their results
before advancing. Full-sleep accepts cycle 1, 2, or 3 and refuses to overwrite
evidence. Early-preparation comparison uses cycle 3 and the existing diagnostic
helper staged beside it. These are laboratory scripts, not production hooks.
The staging script is deliberately tied to the observed predecessor boot ID.
Do not reuse it without independently verifying the phone and image hashes.

Raw kernel logs remain private because they include network packet/address data.
Next: inspect firmware readiness and workqueue ordering around the Linux PM
callback, characterize delayed USB access, then validate automatic screen-off
suspend/resuspend and battery drain. Conventional recovery/OTA integration and
fresh-install validation remain required. Fingerprint remains deferred.
