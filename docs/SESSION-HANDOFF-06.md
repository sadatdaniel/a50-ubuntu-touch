# Session handoff 06 — Samsung A50 / Ubuntu Touch

**Written 2026-09-10 (late evening), same day as 05 but after substantial new
work — 05 was already pushed, so this is a new file per the house rule.**
Read this first, then [experiment 018](experiments/018-suspend-freezer-wifi-instability.md)
(which this session updated heavily), then 05 for the earlier framing.

Where handoffs disagree, **this file wins**:
… → [04](SESSION-HANDOFF-04.md) → [05](SESSION-HANDOFF-05.md) → 06.

---

## 0. Where things actually stand

**Suspend/resume is NOT solved.** Five PM cycles today, five deaths (A–E in
experiment 018). But the problem decomposed:

| sub-problem | state |
|---|---|
| Camera close-path wedge blocking the freezer | **trigger found & fixed** (gst-plugin-scan denied the fimc nodes; rule in git + boot unit on device) |
| Camera driver memory corruption | root cause narrowed to `fimc_is_group_close`'s `kthread_stop` wedge (crash D's full stack captured); **kernel fix not written** |
| Random kernel corruption after PM cycles | crashes A/E (kswapd, pagecache) — engine not fully identified; fimc close bug is the prime suspect, PM-notifier churn (ABOX power-cycle, TZ `-512`s) the other |
| Wi-Fi/BT (wlbt) across suspend | has a proper `.suspend/.resume` (mxman) that only runs at the devices phase — verified in source. The morning full-`mem` test suggests it powers down fine; **the interfaces don't come back on resume** — unfixed |
| Nothing triggers suspend | unchanged (no autosleep, HAL loop never enabled, repowerd legacy backend never fired) |
| Filesystem damage | **ruled out** — offline `e2fsck -fy` on sda32 from TWRP: all 5 passes clean |

## 1. What this session did, in order

1. Re-verified running kernel = race-fixed `2e5073f4` (partition-prefix hash).
2. Ran the PM ladder on it: freezer ×3, devices ×2 — all died within 10–120 s
   (details + evidence pointers in 018's table). Learned: **no pm_test level is
   safe**, because even freezer runs the full `PM_SUSPEND_PREPARE` notifier
   chain (ABOX powers off, firmware re-downloads, TZ workers get `-512`).
3. Caught crash D's **complete** freeze-failure + wedge in the fsynced kmsg
   capture: `gst-plugin-scan` stuck in `fimc_is_group_close → kthread_stop →
   wait_for_completion`, `Freezing of tasks failed`, abort, panic in the same
   stack 25 s later. This is the first fully-witnessed death.
4. Read the wlbt core source (`drivers/misc/samsung/scsc/`): suspend
   coordination exists but only runs at the devices phase; `slsi_suspend`
   (cfg80211 level) is a no-op; the driver registers no PM notifier.
5. Attempted wlbt unbind isolation — **invalidated**: the remove path leaves
   `mxmgmt_thread`/`mxlog_thread`/phy/netdev alive (half-torn state). Do not
   cite it.
6. Shipped the fimc node lock: overlay udev rule (`TAG-="uaccess"` is the
   load-bearing clause — logind's ACL overrides any mode; verified READABLE →
   BLOCKED on device) + temporary boot unit on the dev device
   (`/etc/systemd/system/a50-fimc-lock.service`, mode 0600 zeroes the ACL
   mask). **This should stop gst-plugin-scan from ever wedging again.**
7. Crash E (pagecache corruption, boot self-degraded before any rung) →
   suspected fs damage → rebooted to TWRP via the (usually unreliable)
   software path — it worked this once — and ran offline fsck: **clean**.
8. Rebooted; quiet-observation mode since. Watcher's first check: healthy,
   scans alternating, no wedge, no new failures.

## 2. Rules for the next session (on top of 05 §4/§6)

1. **Do not run PM cycles** until the fimc close-path kernel fix exists and
   the system has stayed quiet under the watcher. Every cycle today risked
   the fs and cost a dirty reset.
2. The next kernel work item is concrete: `fimc_is_group_close`'s
   `kthread_stop` — read `fimc-is-group.c`'s kthread lifecycle vs the HAL's
   concurrent use; disassemble the captured fault against `vmlinux` (crash D
   stack is in `a50-ut-out/suspend-018/kmsg-capture-crashDE.log`, line
   ~137878).
3. If corruption appears with NO PM activity under the watcher → suspect
   hardware next: plan a RAM test before more kernel archaeology.
4. When PM work resumes, the cleanest isolation remains unbind-based — but
   the scsc remove path doesn't tear down (see §1.5); a better isolation is a
   small kernel patch to fail the fimc probe (`-ENODEV`) for one test build.
5. `systemctl reboot --reboot-argument=recovery` worked 1/1 today after 3/7
   in an earlier session — still treat physical buttons as dependable.

## 3. Instruments on the device now

* `a50-kmsg-capture.service` (fsynced, filtered; `/userdata/kmsg-capture.log`)
  — **note: it freezes during PM cycles like any userspace; its own restart
  replays the boot buffer, so the file interleaves boots — timestamps, not
  position, define the boot boundaries.**
* `a50-fimc-lock.service` (temporary; the udev rule in git supersedes it at
  the next install).
* SSH key auth for root (host `~/.ssh/id_ed25519`).
* Host-side: 30-min watcher (automation-28cb90e6), state in
  `C:\Users\sadat\Development\.a50-watch-state.json`.
* Evidence on host: `a50-ut-out/suspend-018/` — `kmsg-capture-bootAB.log`
  (A+B), `kmsg-capture-crashC.log` (C), `kmsg-capture-crashDE.log` (D+E, the
  valuable one), `NOTES.md` (early session notes).

## 4. Ubports registration (goal 3) — unchanged

Parked behind a stable suspend and a boot-tested tools-path kernel, per the
plan. Nothing new needed from upstream docs yet.
