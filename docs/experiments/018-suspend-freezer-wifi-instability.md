# Experiment 018 — suspend freezes destabilize wlbt (Wi-Fi/BT), panics follow

**Date:** 2026-09-10 · **Status:** 🔴 4-for-4: every PM cycle so far — even
`pm_test=freezer`, even with Wi-Fi off — takes the device down within ~2 min ·
**Device needed:** yes

## What this experiment is about

017 left two claims: "the device suspends but does not resume", and "the
camera open() race is fixed" (a50-halium `fimc-is-sensor-open-race`, verified).
This session re-tested suspend on the race-fixed kernel (`boot 2e5073f4…`,
partition read-back match) and found **both claims need correction**.

## Correction 1 — the kernel DOES resume; the network does not

The morning full-`mem` test (previous session, Wi-Fi disabled) was read as
"phone dead, needs hard reset". The evidence says otherwise:

* `RSTCNT` in `/proc/reset_reason_extra_info` incremented **exactly once per
  real kernel panic** today (17→18, two KPs, both mine — see below). The
  morning incident did not increment it.
* Uptime was continuous across the whole incident (22 h 40 m, no boot
  boundary in the journal).

So the system resumed from `mem` without crashing. What did not come back was
**everything the user can see**: display stayed black, USB RNDIS and Wi-Fi
stayed down. "Suspend doesn't resume" really means **USB/Wi-Fi/display do not
survive suspend/resume.**

## Correction 2 — even `pm_test=freezer` is not safe

Two controlled freezer cycles today (the gentlest rung — no device suspend,
no power-down), each followed by a delayed kernel panic:

| | freezer cycle | panic | signature |
|---|---|---|---|
| Crash A | 16:57:30–35, clean entry/exit | +19 s | `super_cache_count:shrink_slab:shrink_node:kswapd`, "Fatal exception" |
| Crash B | 17:03:11–16, clean entry/exit | +~120 s | `(null):slsi_mlme_add_scan:slsi_scan:rdev_scan:nl80211_trigger_scan:…:SyS_sendmsg`, "Fatal exception **in interrupt**" |
| Crash C | 17:20:49–54, clean entry/exit, **Wi-Fi radio off** | +~10 s | **no panic text at all** — kernel printk and the userspace journal both stop within the same ~20 s window; silent whole-system lockup, recovered only by the owner's forced reset ~8 min later |

Between them: a 22 h 40 m boot and a fresh 5 min boot, both with periodic
NetworkManager scans, **zero panics** until the freezer cycle.

The `pm_test=freezer` rung runs the full `PM_SUSPEND_PREPARE` notifier chain
first (verified in the kmsg capture: rcu, cpu_hotplug, thermal, gpu, mmc,
abox…) — the ABOX DSP is powered off and reloaded even at this level, and the
freezer disturbs the TrustZone worker threads
(`tz_uiwsock_recv … ret=-512`, i.e. `-ERESTARTSYS`).

## Why wlbt is the prime suspect

* Crash B's stack is *inside* the SLSI Wi-Fi driver. Crash A's stack
  (kswapd faulting on a superblock shrinker) is what memory corruption looks
  like when it lands somewhere random.
* The previous session had already seen `slsi_mlme_add_scan` fatal-in-interrupt
  "after resume".
* At crash A's resume, `bluetoothd` was restarting its sockets — Bluetooth
  lives on the **same wlbt combo chip** as Wi-Fi.
* `slsi_suspend`/`slsi_resume` (`drivers/net/wireless/scsc/cfg80211_ops.c:1892`)
  are **no-ops**, the driver registers **no PM notifier**, and nothing in
  Ubuntu Touch/NetworkManager coordinates Wi-Fi around suspend the way
  Android's framework does on the stock ROM.
* A scan even started *during* the 5 s freeze window (SLSI uses non-freezable
  workqueues): `slsi_mlme_add_scan` at 303.99 s, freeze wait 300.19–305.32 s.

## Controls

* **Scan stress without any suspend:** 38 consecutive `nmcli dev wifi list`
  scans over ~9 min on an untouched boot — zero faults.
* Upstream (FreshROMs mint) has no later fix touching `scsc` after our pinned
  commit, so there is no ready-made patch to lift.

## Instruments installed for this (temporary)

* `/etc/systemd/system/a50-kmsg-capture.service` + `/userdata/a50-kmsg-capture.sh`
  — filtered, fdatasync-per-line `/dev/kmsg` tail to
  `/userdata/kmsg-capture.log`. The unfiltered first version lost the final
  ~2 min before each crash to page cache; this one is built to keep the tail.
* Evidence preserved at `a50-ut-out/suspend-018/` (host side).

## What is NOT yet proven

* **Crash C does not exonerate wlbt**: `nmcli radio wifi off` stops the
  interface but leaves the scsc driver loaded and the chip initialized. The
  one-variable test that would actually isolate wlbt is a freezer cycle with
  the driver *unbound*, and that has not been run.
* The actual faulting instruction of any of the three crashes (no pstore;
  crash C printed nothing at all — consistent with a bus-level lockup, which
  no software witness can catch).
* Whether the ABOX power-cycle at `PM_SUSPEND_PREPARE` (present in every
  cycle, including freezer level) is itself the destabilizer — it powers the
  DSP off and re-downloads firmware (`Calliope is ready to sing`) on every
  resume, and a race there corrupting memory would explain crashes A and B
  landing in unrelated subsystems.
* Anything about full `mem` resume beyond "kernel survives, network dies".

## Test-safety rules learned the hard way

1. `pm_test=freezer` is **not** a safe rung on this device: it runs the full
   `PM_SUSPEND_PREPARE` notifier chain (ABOX poweroff, TrustZone
   disturbance) and has killed the phone 3/3 times within ~2 min.
2. Never disable the fallback network link before a risky rung — this
   session turned Wi-Fi off with only USB left, and USB died with the box,
   leaving no remote way in for ~8 minutes.
3. The 30-minute watcher and any future unattended testing must treat
   "freezer passes interactively" as meaningless — the failure is delayed.

## Next steps

1. Isolate the destabilizer with the driver-level one-variable test:
   unbind `scsc`/wlbt (or ABOX) before a freezer cycle. Each unbind costs
   the corresponding feature until reboot — run when a reboot is cheap.
2. Kernel-side: instrument or diff the vendor `abox_pm_notifier` and the
   scsc driver's freeze handling (it has none) against a tree where
   suspend works (stock Samsung — the same notifier runs there, which
   argues the race needs UT's task mix to trigger).
3. Userspace (orthogonal, needed regardless): nothing ever *triggers*
   suspend today — `/sys/power/autosleep` does not exist and the Android
   suspend HAL loop is never enabled; repowerd's libsuspend would fall back
   to the legacy direct-write backend, which has also never fired.
