# Session handoff 05 — Samsung A50 / Ubuntu Touch

**Written 2026-09-10 (evening).** Read this first, then [`status.md`](status.md),
then [experiment 018](experiments/018-suspend-freezer-wifi-instability.md).
Where handoffs disagree, **this file wins**:
[01](SESSION-HANDOFF.md) → [02](SESSION-HANDOFF-02.md) → [03](SESSION-HANDOFF-03.md) →
[04](SESSION-HANDOFF-04.md) → 05.

---

## 0. Right now

**Every suspend experiment is paused pending a rethink** — see §1. The device
is up, healthy, Wi-Fi on, running the race-fixed kernel
(`boot 2e5073f4…`, partition read-back verified this session). A 30-minute
read-only stability watcher is armed (host-side ZCode automation; reports to
the session). A crash-hardened kernel-log capture runs on the device.

The big picture did not move this session: the port boots, calls, SMS, data,
GPS, audio, Bluetooth, Waydroid all work; the installer release is built but
untested on a stock phone. What moved is the **understanding of the suspend
bug** — three controlled tests, three deaths, and two handoff-04/017 claims
corrected.

## 1. What was learned (the short version)

1. **"Suspend doesn't resume" was half-wrong.** The morning full-`mem` test
   did *not* crash: `RSTCNT` never incremented and uptime stayed continuous
   across the incident. The kernel resumed — **USB RNDIS, Wi-Fi and the
   display are what die across suspend** and they make the phone look dead.
2. **`pm_test=freezer` is not a safe test rung here** (contrary to 017).
   The freezer level still runs the full `PM_SUSPEND_PREPARE` notifier chain —
   ABOX DSP powers off, firmware re-downloads on resume, TrustZone worker
   threads get `-ERESTARTSYS`. Three freezer cycles, three delayed deaths:
   a kswapd panic (+19 s), an SLSI Wi-Fi scan panic (+2 min), and a **silent
   whole-system lockup** (+10 s, with the Wi-Fi radio off). Scans alone
   (38 stressed, plus hours of routine background scans) never crash it.
3. **The one-variable Wi-Fi test was inconclusive** — `nmcli radio wifi off`
   leaves the scsc driver loaded, so wlbt is not exonerated. The decisive
   test is a freezer cycle with the driver unbound (costs a reboot to undo).
4. Nothing ever *triggers* suspend anyway: `/sys/power/autosleep` does not
   exist (`CONFIG_PM_AUTOSLEEP` off), the Android `ISystemSuspend` HAL loop
   is never `enableAutosuspend()`ed, and repowerd's libsuspend backend
   (would be `legacy` — direct `/sys/power/state` writes, source-verified)
   has never fired either.

Full evidence, timelines, and kernel-source citations: experiment 018.

## 2. Instruments this session left in place (all temporary)

| What | Where | Why / how to remove |
|---|---|---|
| Crash-hardened kmsg capture | `/etc/systemd/system/a50-kmsg-capture.service` → `/userdata/a50-kmsg-capture.sh` → appends filtered, `fdatasync`-per-line to `/userdata/kmsg-capture.log` | Survives crashes (per-line fsync); this is how the silent-lockup timeline was pinned. `systemctl disable --now a50-kmsg-capture.service` + delete both files when suspend is solved. Note: it freezes during suspend cycles like any userspace. |
| SSH pubkey for root | device `/root/.ssh/authorized_keys` ← host `~/.ssh/id_ed25519` | Password was only reachable via plink before. |
| 30-min watcher | host-side ZCode automation `automation-28cb90e6` (every `*/30`), state in `C:\Users\sadat\Development\.a50-watch-state.json` | Read-only checks: crashes, failed units, memory drift, reboots. Delete via CronDelete when the port is stable. |
| Evidence bundle | `a50-ut-out/suspend-018/` on the host: `NOTES.md`, `kmsg-capture-bootAB.log` (crashes A+B context), `kmsg-capture-crashC.log` (crash C, full silent-lockup tail) | Reference copies; the device file keeps growing. |

Known capture-filter gaps fixed this session: uevent lines have a **leading
space** in `/dev/kmsg` output (so `^SUBSYSTEM=` never matched), and the
`sm5713` fuel-gauge spam wasn't in the pattern list. Current pattern filters
both.

## 3. Corrections made to earlier docs

* `status.md` suspend row rewritten (this commit) — points at 018.
* 017's "freezer passes" is now recorded as misleading: it passes
  *interactively*; all three deaths were delayed by 10 s–2 min.
* Handoff 04 §0's "boot image inside both = the kernel this device is
  running" remains true for the *release*; the *dev device* now runs
  `2e5073f4` (fimc race fix), one commit newer than 04 knew about.

## 4. How to reach the device (updated)

* **USB RNDIS** (cable): `ssh root@10.15.19.82` — key auth installed; the
  dependable link; comes up by itself from any boot.
* **Wi-Fi**: `ssh root@192.168.179.8x` — DHCP varies (.85/.86 observed);
  check the router or try both.
* `plink -batch -hostkey "SHA256:BPpKdQdHCDAeDLdNFhWAXWN5Pfqxr9zNUb2gAiLk++4" -pw 1234`
  is the password fallback (host key fingerprint may change across reboots
  of the RNDIS MAC).
* **Never end a risky rung with Wi-Fi off** — see 018's test-safety rules.

## 5. Suggested next steps (in order)

1. **Driver-level isolation** (one variable each, accept a reboot after):
   a. unbind scsc/wlbt → freezer cycle → 5 min watch; b. if still deadly,
   unbind ABOX → freezer cycle. The survivor names the destabilizer.
2. **Read the stock kernel's suspend path for the same notifiers** — stock
   suspends daily with ABOX; what differs under UT is the task mix and the
   absence of Android's suspend coordination (wlbt gets no suspend notice
   at all — `slsi_suspend` is a no-op).
3. **Only after resume is safe**: figure out the trigger — either kernel
   `CONFIG_PM_AUTOSLEEP` (repowerd's preferred backend) or something that
   calls the HAL's `enableAutosuspend()`. Do not ship suspend that can't
   survive a freezer cycle.
4. Camera (Qt/AAL media-layer) and fingerprint remain parked as in 04 §5.

## 6. Traps added this session (on top of 04 §4)

* `pkill -f scanstress` from an SSH one-liner kills your own remote shell —
  the pattern matches the `sh -c` command line itself (04 §4 said `pkill -x`
  not `-f`; this is the same trap wearing a different hat). Kill by PID.
* Heredoc-scripted shell files written from Git Bash over SSH can arrive
  with CRLF and die with dash's `Syntax error: word unexpected`. Build
  scripts with `printf` lines + `sed -i "s/\r//g"`, and `sh -n` before use.
* `/usr` and `/etc` (except `/etc/systemd/system`) are **read-only** on this
   rootfs; temporary scripts belong on `/userdata`.
* Reading the boot partition hash must be prefix-sized to the image
  (`bs=512 count=… | head -c SIZE`), or stale tail bytes change the hash.
* The 30-minute watcher's SSH poll is itself a wakeup — negligible, but a
  *missed* snapshot likely means the phone finally suspended, not a crash.
