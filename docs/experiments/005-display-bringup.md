# Experiment 005 — display bring-up: what was done, what worked, what didn't

**Date:** 2026-09-02 · **Status:** 🔄 mid-diagnosis · **Device needed:** yes (stable ssh state reached)

## TL;DR

Ubuntu Touch boots on the device: systemd runs, the Android container (Halium
11 GSI, API 30) reaches `sys.boot_completed=1`, lightdm starts, and the vendor
Mali G72 blob loads inside the compositor. The **only** remaining blocker is
that opening `/dev/mali0` (the GPU device) hangs the *first* process that tries
— and this kernel's `misc_open` holds a **global mutex across the driver's
open**, so every later misc-device open on the whole system queues behind it
(269 stuck processes observed). The screen therefore stays on the Samsung logo.
The likely fix and the exact next steps are at the bottom.

---

## 1. Where things are

### On the device (current state)

| What | Where |
|---|---|
| UT rootfs image (26.04.1, phablet+root pwd `1234`, ssh enabled) | `/data/rootfs.img` (4.37 GB, md5-verified at push) |
| Halium 11 GSI android image | **inside the rootfs image** at `/var/lib/lxc/android/android-rootfs.img` (473 MB) — the GSI tarball's own intended path |
| GSI copy that was misplaced as `/data/system.img` | renamed `/data/gsi-system-keep.img` (not deleted) |
| Droidian rootfs (way back) | `/data/droidian-rootfs.img` (12 GB real) + old backup images (`rootfs-snapshot-backup.img`, 8.6 GB) |
| Writable-rootfs marker (ro→rw for boot) | `/data/.writable_image` |
| Boot partition | `boot-rescue3.img`: Proton kernel (`Image-proton`) + **single-layer** ramdisk whose `/init` = our overlay init forcing `init=/root-rescue2.sh` |
| `/root-rescue2.sh` (current content) | **rescue v3**: USB RNDIS gadget + `10.15.19.82` + sshd (with `ssh-keygen -A` fix) + `exec sleep infinity` — **no systemd** |

### In the a50-ubuntu-touch repo (github, main @ 7eb757f)

| File | Content |
|---|---|
| `ramdisk-overlay/init` | v4 overlay init: shell-only `validate_init` (klibc dry-run opens /dev/console → ENXIO here), forced `init=/sbin/init`, mknod kmsg+console at handoff, **busybox switch_root** handoff (kernel has no readable console: write-only `console=ram`) |
| `deviceinfo` | kernel branch `ubuntu-touch-26.04`, defconfig `halium_a50_defconfig halium.config`, LLVM toolchain |
| `docs/experiments/003-first-build.md` | the tools-build fix series (10 kernel-branch commits) |
| `docs/experiments/004-boot-tests.md` | boot-test ledger: kernel bisection verdict (Google clang-r383902 hangs this device; Proton boots) |
| `docs/build-environment.md` | the Ubuntu 22.04 container recipe |

### Kernel branch (github `android_kernel_samsung_exynos9610_mint` @ d25a56a60)

10 commits making the tree buildable by the UBports tools (hermetic LLVM):
kbuild host-link fixes, `LDLLD/LLVMNM/LLVMOBJCOPY` empty-clobber fixes,
`-Wno-error` for clang, POLLY removed, vdso32 IAS+lld, tzdev/firmware incbin
paths, `__bad_copy_from` sentinels, setlocalversion trailing space.

### Host workspace (`C:\Users\sadat\.zcode\workspace\default\`)

| Path | Content |
|---|---|
| `a50-first-build/` | all flashable images: `boot-rescue3.img` (currently flashed), `boot-repro3.img`, `boot-control*.img` (test series), `boot-nolto.img`, `boot-proton.img`, `boot-backup-preUT.img` (**pre-experiment device state**, sha256 bdde0284…) |
| `a50-kernel-branch/` | host-side git of the kernel branch + bundles |
| `a50-port-proposed-edits/` | every rescue-script version, probe scripts, CHANGES.md, ASSETS.md |

### Containers (Docker, local)

`ut-build-env` (port build env + kernel trees), `ut-priv` (privileged, has the
single-layer ramdisk build), `a50-kernel-shell` (canonical branch clone at
`/root/exp002/mint`).

---

## 2. What worked (device-proven)

1. **Boot chain**: S-Boot accepts our images (incl. the `id` digest — unchecked
   by S-Boot). Kernel → initramfs → switch_root → systemd → userspace.
2. **Kernel verdict** (7 controlled boot tests): Google clang-r383902 kernels
   hang pre-userspace (with AND without LTO); **Proton Clang 13 kernels boot**.
   The Proton "tools-style" build's Image has exactly the same byte count as
   a50-halium's boot-verified `074aad86…`.
3. **ramdisk-overlay/init v3**: after the three fixes (shell-only
   `validate_init`, forced `init=/sbin/init`, busybox `switch_root`), the UT
   initramfs hands off correctly to any Debian-style rootfs — Droidian booted.
4. **kmsg/console mknod** (v4): without it systemd exits(1) → 36 s bootloop.
   Droidian's image only worked because the node persisted inside its image.
5. **The GSI placement fix**: `android-rootfs.img` must live **inside the
   rootfs image** at `/var/lib/lxc/android/android-rootfs.img` (the GSI
   tarball's own path). After that: `lxc-android-config.service` **active**,
   `lxc-start` running, `sys.boot_completed=1`, Android 11 API 30 answering
   getprop. The Android container is alive.
6. **Live access**: ssh into the running UT system as root works
   (root/phablet, pwd `1234`). This is the bring-up superpower — no more
   blind bootloop iterations.
7. **Stability**: the bootloop is **racy** — some boots survive 2+ min
   indefinitely (one ran 26 min), others die at ~50 s. The death correlate:
   boots that reach the Android-container GPU path die; ones that fail it
   early (my broken-script boot) survive.

## 3. What didn't work / wrong turns

* **Layered cpio appends to the ramdisk** (v5/v6): untrustworthy — a later
  boot with init pointing at a file I had deleted caused a false "fix" cycle.
  Single-layer rebuild (gunzip → replace init → re-cpio) is the reliable way.
* **`/data/system.img` placement**: the GSI must NOT be a separate userdata
  file for this flow; the initramfs's rootfs-mode expects it inside the rootfs
  image (see above). The misplaced copy caused the container's
  `build.prop: No such file or directory` failure.
* **Editing the image's `/etc/ssh/sshd_config`**: invisible at runtime — UT
  bind-mounts `/data/system-data/etc/ssh/` over it (writable-paths). The
  persistent copy (`PasswordAuthentication=no` drop-in) is what sshd reads.
* **Host networking**: rescue3 has no DHCP server, so Windows APIPA'd the
  RNDIS adapter and had **no route** to `10.15.19.82` — ssh SYNs never
  reached the device. Host fix (needs elevation):
  `netsh interface ip add address "Ethernet 9" 10.15.19.100 255.255.255.0`.
* **misc_open probe hangs**: `timeout 3` doesn't kill D-state; must use
  `timeout -k`. And ssh sessions hang if a remote background job holds the
  pipe — always `</dev/null >/dev/null 2>&1 &` remote background jobs.

## 4. The display blocker — evidence

* `lomiri-system-compositor` dies into **D-state inside `misc_open+0x34`**
  (kernel stack captured). `misc_open+0x34` = acquiring the **global misc
  mutex**. This kernel (Samsung 4.14) holds that mutex **across the driver's
  open callback** (confirmed by reading `drivers/char/misc.c` in-tree).
* Therefore: the **first** process whose misc-device open *sleeps forever*
  freezes every subsequent misc open on the system. Measured: 269 processes
  stuck at `misc_open+0x34`; even reading `/proc/misc` waits on the mutex.
* The first victim's identity: logcat shows the compositor loads the vendor
  Mali blob (`libGLES_mali.so`, MaliG72 **r26p0**) successfully, then hangs.
  A plain open of `/dev/mali0` also hangs (dd test never returns, kill -9
  ineffective → D-state). `kbase_open` in-tree has no sleep — the hang is in
  a path invoked before/at register or another driver entirely (open order:
  hybris opens ion → mali0 → …; ion works, mali0 hangs).
* The container's own SurfaceFlinger (stock GSI runs it — Droidian's images
  disabled it) is the likely first opener at container boot: it may hold the
  mutex since before the compositor ever started.
* **Same kernel opened mali0 fine under Droidian** — so the difference is
  environmental: who opens it first, in what order, with what HAL state.

## 5. Likely solution paths (in order)

1. **Stop the GSI's own SurfaceFlinger** (it fights the host compositor for
   the GPU anyway — Droidian disables it). Inside the container:
   `stop surfaceflinger; stop bootanim` or disable via
   `lxc-android-config` device-hacks (the sanctioned overlay path), then
   restart lightdm on the host side and re-test the mali0 open.
2. If still stuck: boot **without starting the container at all** (rescue
   platform + `lxc-android-config` off) and test `/dev/mali0` — clean split
   of "container wedges it" vs "host path wedges it".
3. Check the kernel's `misc_open` mutex-scope patch: Samsung holds the mutex
   across driver open (upstream doesn't). A one-line kernel patch moving the
   driver `open` call outside the mutex (upstream behavior) removes the
   whole class of freeze — candidate branch commit with boot test.
4. Then restart lightdm → UT spinner → Lomiri greeter. Next expected
   blockers after display: AppArmor (guide step), Wi-Fi (wlan0), audio
   (32-bit HAL bridge) — each has a Droidian-era diagnosis.

## 6. Procedure notes for the next session

* Rescue platform (current boot): network comes up at ~4 s, device at
  `10.15.19.82` — **add host IP first** (elevated):
  `netsh interface ip add address "Ethernet 9" 10.15.19.100 255.255.255.0`
  then `ssh root@10.15.19.82` / pwd `1234`.
* Normal UT boot (current flashed image runs rescue first, then you can exec
  systemd over ssh): `ssh root@10.15.19.82`, then
  `systemctl isolate multi-user.target` or start units manually.
* Way back: TWRP → flash `boot-backup-preUT.img` (original pre-UT boot) —
  device returns to exact pre-experiment state; Droidian rootfs untouched at
  `/data/droidian-rootfs.img`.
* The dmesg capture pattern that works: background loop in PID1 script,
  `mount -o remount,rw /` before each `dmesg > file` (systemd-remount-fs
  flips / ro via the initramfs-generated fstab entry).
