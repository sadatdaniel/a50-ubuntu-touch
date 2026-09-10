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
| Crash D | 17:45:31, `pm_test=devices` | +25 s | **full freeze-failure captured**: `gst-plugin-scan` wedged in `fimc_is_group_close → kthread_stop → wait_for_completion` (D-state) → `Freezing of tasks failed` → `Abort: One or more tasks refusing to freeze` → fatal exception in that same stack in `__switch_to` |
| Crash E | 17:54:52, `pm_test=devices`, gst absent this boot | +32 s | `pagecache_get_page:filemap_fault:ext4_filemap_fault` fatal — **random page-cache corruption**. That boot had *already* self-degraded pre-rung: SLSI self-recovery tore the WLAN service down, `EXT4-fs (sda32): errors=remount-ro` |

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

## The gst-plugin-scan trigger (crash D, fully captured)

Every user session starts `clean-gstreamer-cache.service` → media-hub →
`gst-plugin-scan`, which probes **every** `/dev/video*` node for the v4l2
plugin. The session even SIGKILLed it 15 s before the rung — useless against
a D-state task. Two fimc users contend (the container's camera HAL holds the
pipeline; the scanner opens/closes), the scanner wedges in
`fimc_is_group_close`'s `kthread_stop`, and it stays wedged for as long as
the boot lives — any later PM attempt fails to freeze on it. The wedge is
probabilistic: other boots' scans completed.

**Fix shipped:** `overlay/system/usr/lib/udev/rules.d/99-a50-fimc-scan-block.rules`
— host userspace loses access to the fimc nodes entirely (`TAG-="uaccess"` is
the load-bearing clause; logind's ACL overrides any mode). The container's HAL
is unaffected — it applies its own `cameraserver:camera` permissions inside
the container. On the dev device, `/etc/systemd/system/a50-fimc-lock.service`
does the same at boot (mode 0600 zeroes the ACL mask) until the next install.

## wlbt does have a suspend path — it runs at the devices phase

Source reading (`drivers/misc/samsung/scsc/`): the `scsc_wlbt` platform
driver has `.suspend/.resume` (`platform_mif_module.c`) → `mxman_suspend`/
`mxman_resume` (`suspendmon.c`) — the MX140 WiFi/BT core is properly powered
down and restored **only when the devices phase runs**. At freezer level the
chip stays fully powered while its kthreads freeze — a state stock Android
never creates, because stock always suspends through the full path. The
morning full-`mem` test (kernel survived, network died) is consistent: the
chip *was* suspended properly, but the resume half did not bring the
interfaces back.

## Filesystem ruled out

After crash E's `EXT4-fs (sda32): errors=remount-ro`, a full offline
`e2fsck -fy` on `/dev/block/sda32` from TWRP came back **completely clean**
(all 5 passes, nothing fixed). The ext4 error was transient kernel-side
state, not media damage. What remains as the corruption engine: the fimc
close-path bug (crash D), whatever the PM notifiers disturb, or hardware
(RAM untested).

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

## The kernel fix for crash D — written, built, flashed, verified

a50-halium `fimc-is-group-stop-semaphore` (commit `3471956`): the hang was a
race in `fimc_is_group_task_stop()` — it released `gtask->smp_resource` only
when the semaphore's wait list was already non-empty, but
`fimc_is_group_shot()` downs that semaphore *after* passing its first
REQUEST_STOP check, so a stop racing that window sees an empty list, skips
the release, and `kthread_stop()` waits forever on a `down()` nothing will
complete. The fix ups both that semaphore and the closing group's
`smp_trigger` unconditionally; a spurious up is harmless because the
worker's next REQUEST_STOP check bails and both semaphores are re-initialised
on the next start. No public fix exists to lift — LineageOS exynos9820
(lineage-23.2) still carries the conditional up().

**Verified** on boot image `fe4e753a` (flash read-back match): close-path
storms of 8×30 and 16×50 concurrent open/close rounds across the ISP
(`video121`), 3AA (`video111`) and sensor (`video101`) nodes — 2,160 node
operations under contention with the container's camera HAL — completed
with uptime continuous, zero wedged D-state processes, zero kernel fault
markers. PM-cycle testing stays paused until the system proves quiet under
the watcher.

## The media-hub crashes are the missing-AppArmor bug (symbolized)

The recurring `media-hub-server` SIGSEGVs (45 on the 2026-09-09 boot, more
today) symbolized cleanly via the published `media-hub-dbgsym` ddeb +
`addr2line`:

```
operator+(QString const&, QString const&)            qstring.h:1528
Context::profile_name()                              apparmor/lomiri.cpp:143
ExistingAuthenticator::authenticate_open_uri_request lomiri.cpp:349
PlayerSkeletonPrivate::openUri() lambda#1            player_skeleton.cpp:191
main                                                 server.cpp:162
```

Every app-initiated `openUri` walks the AppArmor context path, and without
kernel AppArmor the `Context`'s QString is garbage — QString arithmetic on
it segfaults. Not patchable from this port (the 26.07 build's source is not
on the public refs and no `*_RUNNING_UNDER_TESTING`-style hook exists in
the reachable code); the fix is the **AppArmor ladder** (a50-halium
`apply-apparmor-step1.py`, prepared per 008's appendix).

## Next steps

1. **Quiet observation.** All PM testing is stopped — five deaths today, and
   crash E's boot degraded before any rung. Let the watcher run; if the
   system corrupts itself with no PM activity at all, the suspect list
   shifts to hardware (RAM test) and the fimc close bug alone.
2. Kernel: `fimc_is_group_close`'s `kthread_stop` wedge (crash D) is a real
   driver bug with the full stack captured — disassemble against `vmlinux`
   and read `fimc-is-group.c`'s kthread lifecycle against the HAL's
   concurrent use.
3. The PM-notifier churn (ABOX power-cycle at every PREPARE, TZ `-512`s)
   remains unexonerated for the corruption; the one-variable unbind tests
   (wlbt: attempted, invalidated by the half-torn remove path; ABOX: not
   attempted) are still the cleanest isolation if PM work resumes.
4. Userspace (orthogonal, needed regardless): nothing ever *triggers*
   suspend today — `/sys/power/autosleep` does not exist and the Android
   suspend HAL loop is never enabled; repowerd's libsuspend would fall back
   to the legacy direct-write backend, which has also never fired.
