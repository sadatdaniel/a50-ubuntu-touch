# Passive overnight sleep and crash observation

10 October 2026. Temporary diagnostic collection on the installed aa17 / Ubuntu
Touch 26.04 phone, not a power-management fix or a stability result. aa18 remains
unflashed. Vendor, recovery, authentication and production power settings stay
unchanged. Root is read-only and AppArmor is enabled after setup.

## Native mechanisms and observation

Use the existing kernel PM messages, suspend statistics, native journal and
Android crash/event buffers. A temporary ordinary systemd service runs the
collector and resumes after an unexpected reboot. It creates no timer, wake
alarm, wake lock or suspend inhibitor. Its 120-second monotonic waits pause
during suspend; snapshots therefore measure awake intervals rather than waking
the phone every two minutes. PM timekeeping messages and the difference between
CLOCK_BOOTTIME and CLOCK_MONOTONIC provide actual suspend-duration evidence.

Snapshots retain boot IDs, suspend successes/failures, wakeup sources and locks,
USB/brightness, battery, memory/load, AppArmor, native system/user service
identities and restart counters, and read-only LXC state. Continuous streams
retain PM/wake/fault kernel messages, relevant service journal records and
native errors, and selected Android crash/ANR/process-death events. Ordinary
vendor polling noise is excluded. The existing kernel collector's default
filter is unchanged; the overnight service opts into its event filter.

Do not use periodic `waydroid shell`, `waydroid logcat` or `waydroid prop get`:
the installed helper unfreezes a frozen container. This recorder uses host
`lxc-info` and attaches Android logcat directly only while LXC reports RUNNING.
It never starts or unfreezes a stopped/frozen Android container. Stop signals
target only subprocess groups created by the observer.

Each of snapshots, journal and Android logs has four 4 MiB rotating files;
kernel logs have four 8 MiB files, approximately 80 MiB total. Files are private
under a root-only cohort in /userdata, with durable flushes. Baseline/final
snapshots and small private configuration files are additional. Logs can contain
private identifiers or app data; publish conclusions, not raw evidence.

The phone already has working archive output from native systemd-pstore:
console/pmsg/dmesg ramoops records in /var/lib/systemd/pstore. Preserve these
before and after the night; existing archive files can be overwritten. This
uses the [upstream pstore archive service](https://github.com/systemd/systemd/blob/main/man/systemd-pstore.service.xml)
without changing its configuration. No panic test is performed. It may preserve
kernel-crash evidence, but abrupt power loss or a hardware hang can still lose
the last messages. The native service may clear pstore after archiving; inspect
both /sys/fs/pstore and /var/lib/systemd/pstore in the morning.

## Reproduction

Use normal administrator authentication. Stage record-overnight.py,
capture-kmsg.py and overnight-observer.sh from scripts/experiments in a new
cohort. Do not put passwords or developer connection keys in these scripts.

```sh
umask 077
base=/userdata/a50-overnight/$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$base"
# Copy the three published scripts into this directory before continuing.
python3 - "$base" <<'PY'
import json, sys, time
from pathlib import Path
now = time.time()
(Path(sys.argv[1]) / 'config.json').write_text(json.dumps({
    'started_epoch': now, 'until_epoch': now + 14 * 3600,
}))
PY
mkdir "$base/before-pstore"
find /sys/fs/pstore /var/lib/systemd/pstore -maxdepth 1 -type f -ls \
    > "$base/pstore-before-list.txt"
cp -p /var/lib/systemd/pstore/* "$base/before-pstore/" 2>/dev/null || true
sh "$base/overnight-observer.sh" start
sh "$base/overnight-observer.sh" status
```

The script installs a clearly named temporary native service and boot link,
restoring root read-only before starting it. It refuses an existing observer
unit. Use a fresh cohort, and remove the previous service before another night.
Expiry uses an ordinary awake-time check, not an alarm: if the phone is asleep
at the deadline, collection ends when it next wakes and checks its deadline.
The enabled diagnostic unit still needs the stop/removal step after expiry.

Leave Waydroid in Recents, switch to Settings, turn the screen off and unplug
USB. Leave the phone unplugged overnight. The PC can be off. Do not relaunch
Waydroid, restart it or reboot before inspecting a suspected failure, if the
phone remains usable. This is observation of ordinary operation, not forced
suspend or an exact battery benchmark: diagnostic I/O has some awake overhead.

## Current cohort and baseline

Private phone directory: /userdata/a50-overnight/20261010T213834Z.
Initial snapshot: 23:39:14 CEST on 10 October; expiry 13:38:34 CEST on 11 October.
Boot ID ffb91172-1f4e-4bba-9135-e374b0a8f959; suspend success=10, fail=1,
failed_freeze=1; other suspend/resume failure categories zero. Battery 100%,
Full, temperature 22.9 C. Android init PID 17064, user launcher PID 16925,
InvocationID 252d73d96bd745a3a7ceba1a2ea4e33d.

The existing failure predates this cohort: at 23:25:18 CEST the kernel aborted
freezing immediately because sec-battery-vbus/sec-battery-cable wake sources
were pending. It then completed a real 2.435-second deep cycle at 23:25:33-36,
woken by sm5713 IRQ 268. This is a cable/charging wake-event abort, not a proven
freezer task failure or crash. Compare morning counter deltas to 10/1; do not
count that old abort as a new overnight failure.

Setup/start passed with root RO, AppArmor Y, no observer timer or kernel wake
lock. A normal observer stop/restart removed its prior Android logcat child,
kept both original Waydroid process identities and restarted collection. The
observer is active with NRestarts=0. Native pstore is active/exited; its existing
three archive files were copied and hashed privately before unplug.

Existing filter/rotation regression passes, Python compilation and shell syntax
pass in the cached Linux build image with no network/downloads. Overnight sleep,
battery, Android-window response and crash conclusions remain pending.

## Morning collection and removal

Reconnect USB, wake/unlock the phone, and report whether its existing Waydroid
Recents tile is present and responsive. If it fails, preserve that state. Read
the host-side LXC/unit identities before any diagnostic Waydroid CLI command.
Capture suspend stats, current boot ID, wakeup sources, battery and service
states, journal errors, and both native pstore locations. Preserve new pstore
files privately and compare their timestamps/hashes with before-pstore.

Stop/remove the observer with the exact cohort's script:

```sh
sh /userdata/a50-overnight/20261010T213834Z/overnight-observer.sh stop
```

This writes a final snapshot, removes the diagnostic unit and boot link, restores
root read-only and retains all private evidence. Copy the entire cohort to
private host storage afterwards; verify AppArmor, root RO, no diagnostic unit
or child processes, and normal Android state. Do not delete evidence as part
of cleanup. Review kernel entry/exit pairs and durations, counter deltas,
wake reasons, boot changes, launcher/init identity changes, native/Android
crash/ANR/OOM records and battery changes. Missing evidence is not a pass;
process survival alone is not proof the Android window is responsive.

## Morning result, 11 October 2026

Evidence collected at 07:41 CEST before any Waydroid relaunch or diagnostic
shell command. The verified private archive SHA256 is
9c7236cd0c4a65f16aeb9210c6e8b4a654155cb47e74be735eb0db7a2b29f404;
post-cleanup evidence SHA256 is
aa934e85405793726023b0fa034e99be45654bc4300f9204f69ede5caf16203f.
Host private evidence: this task's work/private/overnight-20261011. Raw archives
and Android/native logs are not published.

The full recorded window is 8h01m52s; physical USB removal is logged at
23:50:46 CEST and reinsertion at 07:40:06. Counters change from 10/1 to 190/19:
180 additional successful suspend cycles and 18 wake-event aborts. Deduplicated
kernel entry/exit records agree with these 198 attempts. Successful cycles
account for 28036.028 seconds, approximately 7h47m16s, or 96.55% of the full
recorded window, including its initial USB-connected preparation. Longest
successful cycle is 599.658 seconds. CLOCK_BOOTTIME minus CLOCK_MONOTONIC
increases by 28047.696 seconds; the extra 11.563 seconds of kernel timekeeping
reported in aborted attempts must not be counted as successful deep cycles.
Timekeeping messages alone therefore overcount successful suspend attempts.

All 18 aborts have matching wake-event evidence: 14 hip4_wake_lock (Wi-Fi),
one muic_wake at cable removal, one umts_ipc0 (modem), and two alarmtimer
EBUSY returns. The latter two correctly defer suspend for an imminent native
alarm; no observer alarm exists. Later normal attempts succeed; all resume
failure categories remain zero. Successful wake traces include 134 Wi-Fi,
45 PMIC/RTC and one other event. Network and timer wake activity remains a
power-characterization topic, not proof of a screen-on event or hardware crash.
Sparse brightness samples are zero during the observed night; they cannot rule
out every brief display activation.

Battery changes from 100% to 97%, temperature 22.9 to 22.8 C. Morning sampling
occurs just after USB charging resumes; this is an observed percentage change,
not a calibrated energy measurement. The kernel boot ID, Lomiri PID 5596 and
Waydroid launcher/init PIDs 16925/17064 retain their original identities.
Shell and observer NRestarts remain zero. The three pstore archive hashes are
unchanged. There is no captured kernel panic/Oops/OOM or Android crash/ANR.
Android's only selected process-death event is normal reclamation of an empty
printspooler process, explicitly logged as empty for 22171 seconds. Android is
RUNNING after reconnection. The owner confirms the existing Recents window responds normally after
wake/unlock, without relaunching from the drawer. The functional background-sleep check passes.

Native errors include a USB charging-mode transition failure at unplug, two
existing pam_fscrypt group-permission warnings at unlock, and the known
midnight dpkg-db-backup failure on read-only /var/backups. Authorized USB access
returns on the first reconnection, without a Developer Mode toggle. These
warnings are retained for follow-up rather than described as Waydroid crashes.
The existing check-readonly-backup.sh passes again: ConditionResult=no,
Result=success. Its guard is already in the image overlay; this restored live
drop-in is under /run and must not be described as permanent image integration.

The observer and its startup link are removed, evidence retained, root RO and
AppArmor Y. Removal exposed a diagnostic-only shutdown bug: systemd deliberately
terminates reader children, and EOF was incorrectly treated as a fault even
after the parent's stop signal. The collector now raises that error only while
still running. The Linux process integration regression fails on the original
code, passes on the corrected code, preserves failure on unexpected reader
exit, and verifies child cleanup. The removed unit's failure metadata is saved
privately then reset; final failed-unit count is zero. This did not interrupt
overnight collection or cause a phone/Android restart. aa18 remains unflashed.

This establishes repeated ordinary suspend/resume and overnight process
survival on the installed aa17 system. It does not complete clean-image/OTA,
Bluetooth idle, camera-image integration or all Waydroid functional testing.
