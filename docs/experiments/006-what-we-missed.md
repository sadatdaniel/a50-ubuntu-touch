# Experiment 006 — the display blocker, solved

**Date:** 2026-09-03 · **Status:** ✅ resolved — the device boots to the
Ubuntu Touch first-boot wizard · **Device needed:** yes

## TL;DR

The two-day "`mali0` open hangs" blocker was **misc device list corruption**,
caused by an unguarded double `misc_register()` on a *static* `miscdevice` in
Samsung's USB gadget code. It was never CMA, and never a flaw in the
mutex-across-open design itself — that only set the blast radius.

A second, independent blocker sat behind it: `/dev/hwbinder` was `0600`, so
the greeter could not reach the graphics mapper HAL.

Both are fixed. Mir drives the panel at 1080x2340 and the wizard renders.

---

## 1. Root cause — circular `misc_list`

`drivers/usb/gadget/function/f_conn_gadget.c` registers a **single static**
`miscdevice`:

```c
static struct miscdevice conn_gadget_device = {
	.minor = MISC_DYNAMIC_MINOR,
	.name  = conn_gadget_shortname,
	.fops  = &conn_gadget_fops,
};
```

and `conn_gadget_setup()` calls `misc_register(&conn_gadget_device)` with **no
already-registered check**, after unconditionally overwriting the global
`_conn_gadget_dev` (which orphans the old kref, so `conn_gadget_cleanup()` and
its `misc_deregister()` can never run).

`misc_register()` opens with `INIT_LIST_HEAD(&misc->list)`. Register the same
static node twice and that node is reset to point at itself while its old
neighbours in `misc_list` still point at it — the list becomes **circular**.
Any later `list_for_each_entry(c, &misc_list, list)` inside `misc_open()` then
spins forever **holding `misc_mtx`**, at 100 % CPU, in uninterruptible kernel
context.

Every misc-device open on the system then blocks: `mali0`, `ion`, `binder`,
`hwbinder`, `uinput`, the compositor, every Android HAL. 94 waiters observed,
load average 115.

### What instantiates it twice

`usb_moded` (UT, host side) and Android's `vendor_init` (container) both
configure USB gadget functions through configfs concurrently. Caught with a
kernel WARN:

```
PID 3735  Comm: usb_moded
  fsg_alloc_inst -> device_create -> kobject_add -> sysfs_create_dir_ns
  kobject_add_internal failed for f_mass_storage with -EEXIST,
  don't try to register things with the same name in the same directory
```

`f_mass_storage` fails loudly with `-EEXIST`. Samsung's unguarded gadget
functions fail *silently*, by corrupting `misc_list` instead.

### Why the holder was never found

Recorded because two sessions burned days on it. The holder is **R-state
(running/spinning)**, not D-state:

* it never matches a `wchan == misc_open` search — it is not sleeping;
* `/proc/PID/stack` of a running task is unreadable garbage (every
  "unsymbolized address" chased — `0xffffff800a6e7200` etc. — was a stale
  stack slot, not code);
* it holds **no fd** for the device: a task blocked inside `->open()` has not
  had the fd installed yet, so "check its fds" finds nothing.

D-state sweeps, `wchan` grouping, SysRq-T and fd inspection were all
structurally incapable of seeing it. Only the `MISCDBG` printk instrumentation
in `misc_open()` proved it:

```
servicemanager  GOTLOCK 65 -> DROPPED 65 -> CALLING-DRIVER-OPEN -> RETURNED err=0
hwservicemanage GOTLOCK 64 -> DROPPED 64 -> CALLING-DRIVER-OPEN -> RETURNED err=0
watchdogd       GOTLOCK 130 -> (nothing, ever)
```

The victim is arbitrary — `watchdogd` one boot, `hfd-service` the next.
Whoever walks the list first *after* corruption is the one that spins, which
is why it looked racy.

### Fix

Runtime, via the LXC mount hook (runs before Android init parses rc files):
bind-mount an emptied `init.exynos9610.usb.rc` over the container's copy, so
the container never touches USB gadget configfs and `usb_moded` owns it alone.

The proper kernel fix — not yet applied — is an idempotency guard at the top
of `conn_gadget_setup()`:

```c
	if (_conn_gadget_dev) {
		kref_get(&_conn_gadget_dev->kref);
		return 0;
	}
```

## 2. Second blocker — `/dev/hwbinder` was 0600

With the wedge gone, Mir came up correctly (`Output 1: LVDS connected, used`,
`Current mode 1080x2340`, `Power is on`) but the greeter died in a loop on
`gralloc-mapper is missing`, and lightdm restarted forever.

The gralloc mapper is a HIDL HAL reached over `/dev/hwbinder`. The compositor
runs as root and worked; the greeter runs as `uid=108(lightdm)` and could not
open it. Stock Android's ueventd.rc sets all three binder nodes `0666`; the
generated udev rules missed them.

Fixed by `overlay/usr/lib/udev/rules.d/99-a50-binder.rules`. **This was the
last blocker** — the wizard renders after it.

## 3. Shell scaling

No device config existed, so the session fell back to `generic.conf`'s
`GRID_UNIT_PX=8` and the shell rendered far too small, icons pushed into the
corners. `ro.sf.lcd_density=420`, and UT's grid unit is 8dp at mdpi, so
`GRID_UNIT_PX = 8 * 420/160 = 21`. Set in
`overlay/etc/ubuntu-touch-session.d/android.conf`.

## 4. No browser pages: a Docker DNS address baked into the rootfs

Reported as "the browser cannot load pages". It was neither the browser nor
Wi-Fi. `/etc/resolv.conf` was a **static file** carrying

```
nameserver 192.168.65.7
```

which is Docker Desktop's internal DNS — captured when the rootfs image was
prepared inside a container, and unreachable from any real network. Everything
else was healthy: Wi-Fi associated, a correct default route, and
NetworkManager's own `dnsmasq` stub running and listening on `127.0.1.1:53`
with the DHCP-learned upstream (`192.168.179.1`).

Fixed by making `/etc/resolv.conf` a symlink to `/run/NetworkManager/resolv.conf`,
the conventional arrangement on an NM-managed system. `getent hosts ubuntu.com`
and `github.com` resolve immediately afterwards. Carried in
`overlay/etc/resolv.conf`.

Worth checking whether other build-time state leaked into the image the same
way — this one was invisible until the device had real internet to fail at.

### Side note: Wi-Fi associates on `swlan0`, not `wlan0`

`overlay/README.md` predicted "Wi-Fi binds the wrong netdev" from the Droidian
port, expecting `p2p0`. On Ubuntu Touch it picks **`swlan0`**, and unlike the
Droidian symptom it associates and routes correctly. Left alone deliberately —
it works, and forcing `wlan0` is a change with no observed benefit yet.

## 5. Tested and FALSIFIED: CMA exhaustion

An earlier draft of this file named CMA exhaustion as the root cause. It is
wrong, and is recorded here so it is not chased again:

* **Direct test.** `CmaFree` was `0 kB`; `drop_caches` returned it to
  `51176 kB` (50 MB free) — and `dd if=/dev/mali0` still hung, D-state,
  identically. Still wedged minutes later with 25 MB free.
* **The Mali driver never allocates CMA.** Exhaustive grep for `cma_alloc`,
  `dma_alloc_from_contiguous`, `dma_alloc_coherent`, `dma_alloc_attrs` across
  `drivers/gpu/arm/b_r26p0/` returns nothing. kbase allocates through
  `kbase_mem_pool` on ordinary `alloc_pages`, and `kbase_open()` is only
  `kbase_find_device()` plus a `kmalloc`.
* **The kernel never logged a CMA failure** — no `cma_alloc: alloc failed`,
  no `alloc_contig_range ... PFNs busy`, no OOM, across every wedge.

`CmaFree: 0` is normal Linux behaviour: the CMA region is loaned to movable
page-cache pages and migrated out on demand. It is not a pressure gauge.
`CONFIG_CMA_SIZE_MBYTES` was **not** raised to 256; doing so would take 256 MB
from a 4 GB device and risks colliding with this DT's fixed `reserved-mem`
carveouts, for no benefit.

## 6. Secondary findings that do hold

### IPC namespace

UT's LXC config keeps only `net user`; Droidian keeps `ipc net user`. Adding
`ipc` gets the container to `sys.boot_completed=1` with `lxc-android-ready`
SUCCESS. Real fix, worth keeping independently of the GPU work.

### binderfs

Not available in this kernel (`unknown filesystem type 'binder'`) — binderfs
landed in Linux 5.0 and this is 4.14. Both Droidian and UT use the legacy
misc-based binder, so the binderfs branch in `pre-start.sh` was always dead
code. Confirmed: `binder_open()` registers via `misc_register()`
(`binder.c:6864`), same `misc_mtx`.

### `waitid(P_PIDFD)` — real, but not a blocker

This kernel has an **incomplete pidfd backport**: `P_PIDFD` is defined in
`include/uapi/linux/wait.h`, and `CLONE_PIDFD`, `pidfd_pid()`,
`pidfd_get_pid()` and the `pidfd_open()` syscall all exist — but
`kernel/exit.c:kernel_waitid()` handles only `P_ALL/P_PID/P_PGID` and returns
`-EINVAL` otherwise. glib 2.88 gets a valid pidfd then fails to wait on it:

```
glib/gmain.c:6142: waitid(pid:4523, pidfd=18) failed: Invalid argument (22)
```

The UI works with these warnings present, so they are noise, not the blocker.
Backport prepared in `docs/patches/0001-waitid-add-P_PIDFD-support.patch`.
Its permanent home is a50-halium's `kernel/patches/`, per
[`conventions.md`](../conventions.md) — it is staged here for reference only.

## 7. What we should have done sooner

1. Instrument rather than infer. Two sessions of D-state sweeps, `wchan`
   grouping and SysRq-T dumps could not see an R-state holder *by
   construction*. The `MISCDBG` printks answered it in one boot.
2. Question the tool before the theory. "No holder exists" should have
   prompted "can this method see the holder at all?" much earlier.
3. Test the cheap falsification first. One `drop_caches` retired the CMA
   hypothesis in seconds.

## 8. State at close

* Boots to the Ubuntu Touch first-boot wizard; shell renders at GU 21
* `misc_open` blockers **0** (was 41-94); load average ~12 (was 115)
* `mali0` / `ion` / `uinput` open instantly; container `boot_completed=1`
* lightdm `NRestarts=0`; Mir driving the panel at 1080x2340
* Verified across a clean reboot

### Open

* Wi-Fi works at every layer below the UI (`wlan0` up, `wpa_supplicant`
  running, NetworkManager scanning fine) but the indicator shows nothing:
  **`CONFIG_RFKILL` is not built**, so there is no `/dev/rfkill`, `urfkilld`
  enumerates nothing and reports WLAN killswitch `state = -1` (no adapter).
  Needs one rebuild.
* Bluetooth still needs `CONFIG_BT` + `CONFIG_BT_HCIVHCI`; `bluebinder` is
  auto-restarting on `ENODEV` waiting for `/dev/vhci`, exactly as
  a50-halium's parked patch predicted. That patch bootlooped on 2026-08-31 —
  before this experiment's fixes — and its own README named an Android-init
  fatal error as the leading hypothesis. `hci_vhci.c` registers `/dev/vhci`
  via `misc_register()`, i.e. it adds a node to the very list that was being
  corrupted, so the patch deserves a fresh test on top of these fixes. One
  variable at a time: land `CONFIG_RFKILL` first.
* `pulseaudio.service` failed in the phablet session — audio is next.
