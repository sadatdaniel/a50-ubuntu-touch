# Session handoff 07 — Samsung A50 / Ubuntu Touch

**Written 2026-09-11 (~03:15 CEST), after a long night session that fixed
three user-visible bugs and ran the AppArmor ladder.** Read this first,
then [experiment 018](experiments/018-suspend-freezer-wifi-instability.md)
and [019](experiments/019-apparmor-ladder.md), then 06 for the prior
framing. Where handoffs disagree, **this file wins**:
… → [05](SESSION-HANDOFF-05.md) → [06](SESSION-HANDOFF-06.md) → 07.

---

## 0. Current state, one paragraph

The phone is **healthy and in daily use**, running kernel `c57250fa…`
("step 1": fimc-fix + AppArmor compiled-in-but-inert; SELinux is the
default LSM). Wi-Fi, calls, SMS, data, GPS, audio, Bluetooth, Waydroid,
MTP/ADB all work. Suspend remains unsolved and parked behind kernel work
(see 018). The camera app remains broken by an upstream media-layer
mismatch (014) **plus** the no-AppArmor trust-store wall. The 30-minute
watcher (host-side automation `automation-28cb90e6`, state in
`C:\Users\sadat\Development\.a50-watch-state.json`) reports clean.

## 1. How to reach the phone

| Link | Address | Notes |
|---|---|---|
| USB RNDIS (cable) | `ssh root@10.15.19.82` | dependable; comes up from any boot; key auth installed (host `~/.ssh/id_ed25519`) |
| Wi-Fi | `ssh root@192.168.179.8x` | DHCP varies (.85/.86 seen); always re-discover, never assume |
| TWRP | `adb` (`R58M34XY4SJ`) | from powered-off: **VolUp + Power**; boot partition is `/dev/block/by-name/boot` (sda14); mount `/data` before reading staged images; **a forced power-off registers as PIN RESET and clears sec_debug's buffers — read crash registers before any manual reset** |
| Password fallback | plink with `-hostkey`, root/`1234` | |

**Never** end a risky operation with Wi-Fi off (no fallback link), and
never `pkill -f <pattern>` from an ssh one-liner (matches your own `sh -c`).

## 2. Where things are

* **Repos:** `C:\Users\sadat\Development\a50-halium` (kernel+build) and
  `a50-ubuntu-touch` (port) — both clean and pushed at time of writing
  (a50-halium `127598a`, a50-ubuntu-touch `54d7112`).
* **Kernel builds on host:** `a50-halium\out\` (fimc-fix, released),
  `out-aa1\` (step 1, `c57250fa`), `out-aa2\` (step 2, `3bdf7e6d`, does
  NOT boot). Donor for packing: `out\donor-90c281f8.img`.
* **Staged on phone (/userdata):** `boot-aa1.img` (c57250fa — currently
  running), `boot-fimcfix.img` (fe4e753a — 5 h stable), `boot-racefix.img`
  (2e5073f4), `boot-known-good-waydroid.img` (90c281f8, release image).
  **Flash = `dd … of=/dev/disk/by-partlabel/boot`, then read back the
  image-sized prefix and compare hashes before rebooting.** Image sizes
  differ between builds (55,449,600 vs 55,785,472) — hash the right length.
* **Evidence:** `a50-ut-out\suspend-018\` (crash logs A–E), 
  `a50-ut-out\mediahub\` (coredump + symbols).
* **GitHub release:** `a50-halium` → `a50-ubports-halium-2026-09-10`
  (boot.img/Image/System.map/manifest/SHA256SUMS). Release creation works
  via the git credential token + REST API (`gh` CLI is logged out but
  `git credential fill` yields a working token; use `git -c
  http.version=HTTP/1.1 push` — plain push sometimes times out).

## 3. What this session did

1. **Kernel fix for the fimc close-wedge** (a50-halium `3471956`, in the
   running kernel and the 2026-09-10 release): the group worker's
   semaphores are released unconditionally on close; verified with
   2,160-op open/close storms. This was the unkillable-D-state freezer
   blocker from 018 crash D.
2. **Waydroid "forever loading" fixed** (`a140fc8`): stale session after a
   Lomiri restart; the launcher wrapper now detects it (Wayland socket
   newer than session start — use `ps -o etimes`, `/proc/PID` mtime is
   dynamic garbage) and rebuilds. Matches upstream's on-demand model.
3. **Screenshot session-crash fixed** (`31f3f68`): Lomiri 0.6.1
   `Dialogs.qml:277` destroyed QML mid-handler; deferred with
   `Qt.callLater`. Live via bind mount (`a50-dialogs-fix.service`) since
   /usr is read-only; overlay carries it for installs.
4. **AppArmor ladder executed** (019, `54d7112` + build wiring `127598a`):
   step 1 (compiled, SELinux default) **boots**; step 2 (default LSM)
   **dies pre-console** (~1.16 s, before any console output; crash
   registers lost to the PIN RESET). Phone restored via TWRP.
5. **media-hub crash root-caused** (018): dies in
   `apparmor::Context::profile_name()` on garbage QString — every app
   openUri. Fix = kernel AppArmor.
6. **Camera "permission error" diagnosed**: same no-AppArmor trust-store
   wall as location (009). Fix = kernel AppArmor.

## 4. Temporary instruments on the device (all documented, remove when
their fixes ship in an install)

| Unit / file | Purpose |
|---|---|
| `a50-kmsg-capture.service` → `/userdata/a50-kmsg-capture.sh` | fsync-per-line kmsg tail to `/userdata/kmsg-capture.log`; survives crashes; interleaves boots (use timestamps) |
| `a50-fimc-lock.service` + `/run/udev/rules.d/99-a50-fimc-scan-block.rules` | fimc nodes 0600 host-side (gst-plugin-scan denial; the ACL/uaccess interaction is documented in 018) |
| `a50-dialogs-fix.service` (bind mount over `/usr/share/lomiri/Components/Dialogs.qml`, source at `/userdata/Dialogs.qml`) | screenshot-crash fix until the overlay ships |
| `/home/phablet/.local/bin/a50-waydroid-{launch,fix-desktop}.sh` + `waydroid-session.service.d/10-fixed-sweep.conf` | live versions of the pushed waydroid fixes |
| `apt cache/dbgsym remnants` in `/userdata/apt-cache/` | media-hub symbolization artifacts; safe to delete |

## 5. What is planned next (priority order)

1. **AppArmor rung 3a — cmdline selection** (in progress this session):
   step-1 config + `security=apparmor` appended to CONFIG_CMDLINE (the
   tree already carries CONFIG_CMDLINE — S-Boot ignores the boot-image
   cmdline, kernel.md risk 2). Same runtime `chosen_lsm` switch, no
   Kconfig-layout change. Boots + `aa-status` works → AppArmor is ON and
   media-hub/camera/trust-store should heal (verify all three!). Dies the
   same pre-console way → the selection logic itself; then rung 3b is a
   source diff of `security/` + Samsung early-init against a working
   AppArmor-default 4.14, with earlycon researched from the DTB (unknown
   UART address — do NOT guess it into CONFIG_CMDLINE, a wrong earlycon
   can hang early boot and become its own variable).
2. **Suspend/resume** (018): PM cycles still destabilize the system; the
   fimc fix removes one engine, but the ladder proved the corruption has
   more sources. Re-test PM cycles only after multi-day watcher-quiet.
   Then: Wi-Fi/USB/display resume path, then the missing auto-suspend
   trigger (autosleep config or enabling the HAL loop).
3. **Waydroid stability**: the guest's graphics-composer HAL still
   SIGSEGVs occasionally (2× after the step-1 flash, signature identical
   to the corruption-era crashes) — watch whether it recurs on quiet
   boots.
4. **UBports registration** (goal 3): parked behind a stable suspend and
   a boot-tested tools-path kernel (kernel.md risk 1) — unchanged.

## 6. Build cheat-sheet (reproducibility)

```bash
cd C:\Users\sadat\Development\a50-halium
MSYS_NO_PATHCONV=1 docker run --name a50-kbuild \
  -v a50-ksrc:/src/kernel/src -v "C:/Users/sadat/Development/a50-halium:/src" \
  -v "C:/Users/sadat/Development/a50-fw:/fw" -w /src a50-halium-build \
  ./build/build-kernel.sh --profile full --firmware /fw [--apparmor stepN] --out /src/outX
```
A stopped build container pins the source volume (`docker rm` it before
`docker volume rm a50-ksrc` — the script correctly refuses rung switches
on a reused tree). Pack with `make-boot-image.sh --port ubports --image
… --donor out/donor-90c281f8.img`. Flash from the running system per §2.
Build ≈ 45 min; the ThinLTO link goes quiet for several minutes — that is
normal.
