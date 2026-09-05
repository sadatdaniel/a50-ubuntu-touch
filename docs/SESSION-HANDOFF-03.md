# Session handoff 03 — Samsung A50 / Ubuntu Touch

**Written 2026-09-05, late.** Read this first, then `docs/status.md`, then the
experiment you are touching.

Earlier handoffs are kept so the progression is visible. Where they disagree,
**this file wins**: [01](SESSION-HANDOFF.md) → [02](SESSION-HANDOFF-02.md) → 03.

---

## 0. RIGHT NOW

Working and verified across reboots: **audio, Bluetooth (incl. A2DP), phone
calls, mobile data, Wi-Fi, GPS, and Waydroid (Android apps)**.

| | |
|---|---|
| Running kernel | `90c281f8…` = `/userdata/boot-known-good-waydroid.img` |
| Rootfs | 16 GB, ~12 GB free |
| Failed units | 2 — `ssh.service`, `usb-tethering.service`. **Expected, do not "fix"**: an sshd from the boot script already owns port 22 |

### The kernel is NOT the published release

`90c281f8…` carries two patches on top of `boot-a50-2026-09-05.img`, both in
a50-halium, both boot-tested:

| patch | what it does |
|---|---|
| `decon-force-mask-layer.patch` | `/sys/module/decon/parameters/force_mask_layer` forces the fingerprint HBM mask layer. **Defaults off; inert when unset** |
| `CONFIG_ANDROID_BINDER_DEVICES` + `anbox-*` | gives Waydroid its own binder domain (this 4.14 tree has **no binderfs**) |

### Fallbacks staged on the device

| image | sha256 | what |
|---|---|---|
| `/userdata/boot-known-good-waydroid.img` | `90c281f8…` | **what is running** |
| `/userdata/boot-known-good.img` | `53fe13b5…` | published release; no Waydroid, no HBM |

```sh
dd if=/userdata/boot-known-good-waydroid.img of=/dev/sda14 bs=4M; sync
dd if=/dev/sda14 bs=512 count=108172 | sha256sum   # verify BEFORE rebooting
```

---

## 1. What changed this session

* **GPS works.** Three faults, none in the kernel. The real blocker: `gpsd`
  waits forever on `service.bootanim.exit`, which a Halium container never sets.
  [009](experiments/009-gps-permissions.md)
* **Waydroid works**, F-Droid installed, Android 13. [013](experiments/013-waydroid.md)
* **Camera root-caused** — an upstream Qt bug, not this device.
  [014](experiments/014-camera.md)
* **Fingerprint HBM solved**; the remaining blocker is Samsung's trustlet.
  [012](experiments/012-fingerprint.md)
* **Morph/Google Maps, updates, PIN** explained. [010](experiments/010-morph-intent-urls.md), [011](experiments/011-settings-quirks.md)
* **Two build bugs fixed** that made the kernel unbuildable from a clean
  checkout — see §4.

---

## 2. Waydroid — how it is set up, and why

**Launcher policy: only the `Waydroid` icon is shown.** All 13 per-app entries
are hidden. This is deliberate and was the user's call.

Why: in single-window mode Waydroid exposes **one** Android surface, but Lomiri
treats each app as its own launcher entry — so opening a second app *steals the
surface from the first*. Launch apps from inside Android instead.

Multi-window mode (`persist.waydroid.multi_windows true`) does render, but as
floating desktop windows — unusable on a phone. Currently **false**.

Three things had to be fixed, all in `overlay/`:

| file | why |
|---|---|
| `usr/lib/systemd/user/waydroid-session.service` | starting the session as root or via `su phablet -c` fails — the bus address stays root's. A **user** unit inherits the right env |
| `usr/local/bin/a50-waydroid-launch.sh` | supplies `DBUS_SESSION_BUS_ADDRESS` etc; **stays alive** (`waydroid app launch` exits in ~1 s and Lomiri then tears the app down); releases the surface on exit by sending Android home |
| `usr/local/bin/a50-waydroid-fix-desktop.sh` | Waydroid **rewrites the .desktop entries on every session start**, so this sweeps repeatedly until three clean passes |
| `etc/systemd/system/waydroid-container.service.d/50-a50-nocamera.conf` | stops Waydroid's camera provider, which crash-looped every ~6 s |

**Waydroid's camera works** (Android Camera2, bypasses Qt entirely).

---

## 3. Where each open thing actually stands

### Camera — upstream Qt bug, not the device
Hardware, kernel driver, Samsung HAL and libhybris **all work** (16 preview
sizes readable from UT). `qtubuntu-camera` 0.5.1 implements only the legacy
`QCameraViewfinderSettingsControl`; Qt 5.15 needs
`ViewfinderSettingsControl2` (0 symbols vs 6 in `libgstcamerabin.so`). Qt
returns an empty resolution list → `QSize(-1,-1)` → SIGSEGV. Needs
qtubuntu-camera patched and rebuilt, or reporting upstream.
Also fixed on the way: the app needed `libexiv2-27-compat` or it could not even
load its own QML plugin. **The old "camera panics the kernel" hazard does not
reproduce** — all 50 V4L2 nodes probe safely.

### Fingerprint — trustlet, not illumination
HBM is solved and controllable. **Illumination is settled — do not re-test**:
with white pixels over the sensor and `actual_mask_brightness=255`, `nd cnt`
stayed 0 across 62 samples. No DRDY interrupt is ever registered
(`/proc/interrupts` has no `etspi_irq`) because the HAL never issues
`INT_TRIGGER_INIT`. Lead: **no fingerprint calibration data under
`/mnt/vendor/efs`**.

### AppArmor
Still unbuilt. The one attempt **did not boot** (failed before USB). Not
blocking anything now; GPS, biometryd and the location service are all
bypassed instead.

---

## 4. Traps that cost time — read before repeating them

* **`pkill -f <pattern>` / `awk '/pattern/'` kills your own ssh session** when
  the pattern appears in your command line. Bit me three times in one session
  despite already being written down. Use `pkill -x <name>`.
* **logcat timestamps are UTC, the device is CEST.** A log that looks two hours
  stale is live.
* **`strings` cannot see kernel module parameters.** Verify patches with
  `System.map`, not `strings Image`. A "0 occurrences" result there proves
  nothing — check a known-good symbol as a control first.
* **The kernel tree cannot be checked out on Windows** (`aux.c` is a reserved
  name) and an NTFS checkout mangles symlinks. Build with the source on a
  **Docker volume**: `-v a50-ksrc:/src/kernel/src`. Pre-clone into it, because
  the build script does `rm -rf "$SRC"` which fails on a mount point.
* **apt's `_apt` sandbox user cannot resolve DNS here.** Use
  `-o APT::Sandbox::User=root`.
* **decon only evaluates the HBM mask layer on a new frame.** A static window
  never triggers it, and the mask will not clear until another frame arrives.
* Two pre-existing build bugs are now fixed, but note them: the release script
  applied patches *after* the step that needed them (worked only because a
  previous run left the tree patched), and `bluetooth-hci-sock-restore.patch`
  carried duplicate abox hunks. **All nine patches now apply to a pristine
  tree.**

---

## 5. Suggested next steps

1. **Cut a release.** The published release predates GPS, Waydroid and both
   kernel patches. The built kernel currently exists only on the device and one
   dev machine — that is the biggest risk to this work.
2. **Camera:** report the `qtubuntu-camera` Control2 gap upstream before
   considering a fork.
3. **Fingerprint:** chase the missing EFS calibration data.
4. Untested basics: **Bluetooth HFP** (calls over BT), **headphone/earpiece**
   audio.
5. **Camera panic hazard is retired** — `status.md` and older handoffs were
   wrong; do not re-derive it.

---

## 6. Everything else

Sections 1–6 of [handoff 02](SESSION-HANDOFF-02.md) still apply verbatim: how
to reach the device, flashing, the basic laws, live hazards, and runtime state
that is not in git. They are not repeated here.
