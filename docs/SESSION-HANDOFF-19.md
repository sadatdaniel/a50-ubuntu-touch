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
