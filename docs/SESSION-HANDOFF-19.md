# Session 19 — aa6 freezer test loses connectivity

2026-09-12, times CEST. Previous handoffs preserved.

Waydroid icon is now USER-CONFIRMED visible after refreshing the drawer.
The existing repository launcher hook was installed and verified in session 18.
Do not equate icon visibility or one successful launch with full reliability.

## Suspend diagnostic

Read the exact aa6 kernel's Documentation/power/basic-pm-debugging.txt and
the earlier docs/experiments/018 suspend record before testing. No deep-sleep
test was attempted. AppArmor/socket fixes are now present, but their effect
on the earlier delayed freezer failures was unknown.

Before the single test: verified the aa6 boot ID
`3cc1346a-73e9-4ca9-803e-4494c2fbb8a1`, AppArmor enabled, USB CONFIGURED,
boot partition resolves to sda14 and its aa1 image-sized prefix matches
`c57250fa3d27daa3fc4888b1ab90d2cb94f00f6c7a9afaa264afd85e7333a703`.
Wi-Fi was up at 192.168.179.86, USB at 10.15.19.82, RTC wakeup enabled.
Stopped the Waydroid user session and container through their normal commands.
Captured health and full dmesg to userdata, then synced.

Transient `a50-freezer-test.service` ran `/userdata/a50-session18/freezer-test.sh`:
set `/sys/power/pm_test` to freezer, write mem to `/sys/power/state`, then
restore pm_test=none. An EXIT trap also restores none. No image was flashed.

12:42:42: started with success=0, fail=0.
12:42:47: returned after five seconds, success=1, fail=0, all failure fields 0.
12:42:51: SSH still worked, uptime 31 min; pm_test confirmed [none].
The next post-test SSH read aborted. Both USB and Wi-Fi then failed. Windows
no longer showed a Samsung/Android/RNDIS USB device; ADB listed no devices.
Wi-Fi SSH timed out. This is a failed stability test, NOT verified suspend.
Exact kernel fault or loss-of-connectivity cause is not yet recovered.

Asked user whether display/touch responds or phone is frozen/rebooting;
response pending. Stop further PM tests until evidence is recovered. It
resembles the prior delayed post-freezer failures despite the aa6 fixes.

## Recover next

Phone files to preserve before another test:
`/userdata/a50-session18/before-freezer.dmesg`, `after-freezer.dmesg`,
`freezer-result.txt`, `/userdata/a50-health/sample-21.log`, and the existing
a50-kmsg-capture output (locate via its original unit/script). Also collect
journal from the failed boot and pstore if present. Local test/read scripts
are in `a50-ut-out/session-18`; raw logs are not published.

If a forced reboot is needed, boot partition still contains aa1 fallback,
so normal recovery boot will not have aa6 AppArmor. Do not confuse that
kernel with the failed aa6 boot. TWRP can recover userdata logs if normal
boot does not return. Do not wipe or reinstall. The temporary health timer
does not survive reboot.

Next investigation: compare the saved PM notifier sequence and any final
kernel fault with experiment 018 (ABOX/TrustZone and fimc lifetime evidence).
Avoid another identical freezer test without new evidence or a focused fix.
Official recovery/OTA/installer finalization remains queued after stability;
video recording remains explicitly broken and deferred.

## Recovery confirmed

User confirmed frozen/black screen and manually restarted. USB SSH recovered
by 12:45 CEST. New boot ID `f8a80a98-56ab-477d-bd96-207cf49b6cdb`, AppArmor
parameter N, consistent with the preserved aa1 fallback. User subsequently
reported Waydroid not working again; leave unresolved and return after suspend.

Recovered locally to a50-ut-out/session-18: after-freezer.dmesg,
sec_log-prev.txt and kmsg-tail-recovered.log. The Samsung sec_log-prev file
ends in early boot messages and is not a trustworthy final-fault witness here.
Copying the growing kmsg-capture.log caused a PuTTY assertion; a fixed
25,000-line snapshot at /userdata/a50-session18/kmsg-tail-recovered.log copied
successfully. The snapshot contains the failed boot's final messages.

The persistent capture ends the aa6 boot at timestamp 1889.423627 immediately
after suspend exit and ABOX messages: Calliope ready, abox_restore_data,
abox_boot_done_work_func releasing wake lock. It then jumps to the next
boot's early timestamps. No panic/Oops was captured in that final sequence.
An ABOX QoS log reports req=1636958208kHz, ret=1180000kHz; inspect the exact
source before interpreting that value (it might be logging, units or state).
These observations identify an investigation point, not proven causation.

Next exact-source inspection of sound/soc/samsung/abox/abox.c was rejected by
automatic approval review due usage limit, with retry indicated at 15:40.
No attempt to bypass the rejection, no additional PM test, no kernel fix
applied. Commit 95d3ada contains the initial test handoff; this recovery
addendum and CHANGELOG.md record the subsequent recovery findings.
