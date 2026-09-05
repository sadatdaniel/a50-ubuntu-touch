# Session handoff 02 — Samsung A50 / Ubuntu Touch

**Written 2026-09-05, later the same day.** Everything a fresh session needs to
pick this up. Read this first, then `docs/status.md`, then the experiment you
are touching.

Handoff 01 is kept at [`SESSION-HANDOFF.md`](SESSION-HANDOFF.md) so the two can
be compared side by side. It is **superseded** — where they disagree, this file
is right. What changed: the AppArmor kernel was boot-tested and failed, the
device was recovered, and GPS was fixed outright - it never needed that kernel.

---

## 0. RIGHT NOW: the device is healthy, on the known-good kernel

The phone boots and runs with **audio, Bluetooth (incl. A2DP), phone calls,
mobile data and GPS** all working, verified across clean reboots. Nothing is
in flight.

The boot partition holds
`53fe13b58818d56c2610c6a6fcc4a7596689b2b3bc53b91440d29cb0573c0f7d` — the
published `boot-a50-2026-09-05.img`.

### The AppArmor kernel was tested. It does not boot. It has been reverted.

Built cleanly (AppArmor strings present, SELinux still built) and flashed with a
verified read-back, but **the device did not boot at all** — no ping, no adb, no
USB gadget enumerating, so it failed *before* userspace, earlier than the
Android container this test was designed to stress. That rules out the
hypothesis it was built on.

Recovery needed TWRP, because with no USB enumeration there is no SSH window to
race. Before restoring, the boot partition was confirmed to still hold the
AppArmor image (`ef68eced…`), so the flash had landed and the kernel is
genuinely at fault. `/userdata/boot-known-good.img` and `/userdata/boot-bt4.img`
both hold `53fe13b5…`.

Two process failures worth naming: that build changed **four** options at once,
against this project's own one-variable rule; and no forensic evidence
survived, because a forced power-off makes S-Boot clear its buffers
(`sec_debug_init_buffer: this is PIN RESET, clear all`), so `/proc/last_kmsg`
read in TWRP holds TWRP's own boot, not the failed one.

**If you retry it, split the variables** — `CONFIG_SECURITY_APPARMOR=y` alone
first, leaving SELinux the default LSM. But it is no longer urgent: see below.

### GPS works

Three separate faults, **none of them in the kernel**, and the inherited plan
(build a kernel with AppArmor) was the wrong answer to all three. See
[experiment 009](experiments/009-gps-permissions.md).

1. `lomiri-location-service` resolves each caller's AppArmor profile before
   opening a session, so with no AppArmor every request failed. The error is
   returned to the caller and never logged, which is why the journal looked
   clean and why the inherited message ("Client lacks permissions") appears
   nowhere — the real one is `Error.CreatingSession`.
   `TrustStorePermissionManager` short-circuits on
   `TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING` before it reads
   any profile, which is what `lxc-android-config`'s own wrapper already does.
2. `/dev/gnss_ipc` came up `0600 root:root` while the vendor's own
   `init.gps.rc` specifies `0660 system system` and runs `gpsd` as user `gps` /
   group `system`. Its `on post-fs-data` block never runs in the container.
3. **The real blocker:** `gpsd` reads `service.bootanim.exit` at startup and,
   until it is set, sits in a 250 ms poll loop forever — one thread, never
   reads its own config, never opens `/dev/gnss_ipc`, never binds its socket,
   logs nothing at all. On stock Android the boot animation sets it. A Halium
   container runs no boot animation. The visible symptom was one level up: the
   GNSS HAL retrying `connect()` to the abstract socket `@GNSSND` and spinning
   `lal_state_handle_transition` three times a second.

Setting it takes `gpsd` from 1 thread to 12; it binds `@GNSSND`, opens
`/dev/gnss_ipc`, and satellites arrive — `num_svs: 5`, SNR 31–40 dB,
`used_in_fix_mask: 15`, and `gnssLocationCb` delivering a position every
second. Verified from a cold boot with nothing done by hand, and with audio,
Bluetooth, the container and lightdm all unaffected.

`strace` is what cracked it and is **now installed on the device** (it needed
`-o APT::Sandbox::User=root`; apt's `_apt` user cannot resolve DNS here).

### Also fixed: Google Maps in Morph

"cannot open intent addresses" is **not** a location bug — Morph's UA claims
`like Android 9`, so Google serves Android `intent://` deep links. Measured: 2
such links with the token, 0 without. See
[experiment 010](experiments/010-morph-intent-urls.md) and
`scripts/morph-google-ua.sh`.

### Where the last known-good things are

| | |
|---|---|
| Last fully working boot image | release `a50-complete-2026-09-05` → `boot-a50-2026-09-05.img`, sha256 `53fe13b5…` |
| Same image, on the device | `/userdata/boot-bt4.img` **and** `/userdata/boot-known-good.img` |
| The kernel that does not boot | `/userdata/boot-aa.img`, `ef68eced…` — keep for bisection, do not flash |
| Audio-only fallback (no Bluetooth) | same release → `boot-rollback-audio-only.img`, `97d2f644…` |
| Original pre-audio known-good | `a50-first-build/boot-miscdbg2.img`, `1fa490eb…` |
| Userspace half | same release → `a50-overlay-2026-09-05.tar.gz` |

The userspace fixes are independent of the kernel: flashing an older kernel
does **not** require reverting the overlay.

## 1. Where everything is

| what | where |
|---|---|
| Kernel, patches, build recipe | `github.com/sadatdaniel/a50-halium` |
| Device config, overlay, docs | `github.com/sadatdaniel/a50-ubuntu-touch` |
| Prebuilt images + overlay tarball | this repo's releases — latest is **`a50-complete-2026-09-05`** |
| Step-by-step rebuild from scratch | [`REPRODUCE.md`](../REPRODUCE.md) |
| Honest inventory of what works | [`docs/status.md`](status.md) |

Local working dirs on the dev machine (convenience only — everything is in git):

```
C:\Users\sadat\Development\a50-halium          kernel repo
C:\Users\sadat\Development\a50-ubuntu-touch     port repo
C:\Users\sadat\Development\a50-droidian         the earlier Droidian port - READ IT,
                                                it solved several of these problems first
C:\Users\sadat\Development\a50-ut-out\kbuild-*  build outputs
C:\Users\sadat\.zcode\workspace\default\a50-first-build\boot-miscdbg2.img
                                                the original known-good boot image
```

---

## 2. How to talk to the device

SSH over the USB RNDIS link. **Windows loses the static IP whenever the phone
re-enumerates**, so if ping fails, re-add it from an **elevated** shell:

```
netsh interface ip add address "Ethernet 9" 10.15.19.100 255.255.255.0
```

Then (root password `1234`; `plink` because OpenSSH hangs here):

```
plink -ssh -batch -hostkey "SHA256:BPpKdQdHCDAeDLdNFhWAXWN5Pfqxr9zNUb2gAiLk++4" -pw 1234 root@10.15.19.82 "uptime"
```

From Git Bash, prefix with `MSYS_NO_PATHCONV=1` or paths get mangled. Use
`pscp` (same flags) to copy files.

Rules that cost time to learn:

* Wrap remote work in `timeout`, and background long jobs with
  `</dev/null >/dev/null 2>&1 &` — a remote job holding the pipe hangs the ssh
  session.
* `mount -o remount,rw /` before writing anything to the rootfs. **Check it
  worked** — a silent read-only failure once made an upload look successful.
* **Never `pkill -f <pattern>`** where the pattern also appears in your own ssh
  command line — it kills your session. `killall <name>` is safe.
* Android HAL errors appear only in logcat, never in the journal:
  `lxc-attach -n android -- /system/bin/logcat -d -b all`
* **dmesg cannot show you boot.** The container's ueventd `restorecon` storm
  evicts the whole boot from the 8600-line ring buffer within a second. Read
  `/userdata/dmesg-boot-first.txt`, written by `a50-dmesg-snap.service` at
  t≈5.3 s. This is how the audio root cause was finally found.
* The ABOX DSP has its own log: `/sys/kernel/debug/abox/log-00`. It is
  authoritative about what the DSP thinks and it named the RDMA7 problem
  outright.

### Flashing — no TWRP needed

The boot partition is `/dev/sda14` and is writable from running Ubuntu Touch:

```sh
dd if=/userdata/<image>.img of=/dev/sda14 bs=4M; sync
# ALWAYS read back and verify before rebooting
dd if=/dev/sda14 bs=1M count=53 2>/dev/null | head -c <exact size> | sha256sum
```

Keep a known-good image on `/userdata` before every experiment. If a flash
does leave it unbootable, TWRP is Power+VolUp+USB, and `/tmp` there is a
ramdisk wiped on reboot.

**If it bootloops**, you can still win: SSH comes up for a few seconds each
cycle. Loop the flash command until one attempt succeeds — that is how the
Bluetooth bootloop was recovered.

---

## 3. The basic laws

These are not style preferences. Every one of them was learned by losing hours.

1. **Search for the known fix before improvising.** Twice in the last session
   guessing cost real time: inventing a `SlotCount` key crashed ofono, and not
   searching for `abox_if.c` meant missing that the bug was upstream-wide. Read
   `a50-droidian/docs/` first — that port solved audio and several other
   problems on this exact phone.
2. **Read the source that is actually installed.** The signal-strength bug was
   invisible until `dpkg -l` showed ofono-binder-plugin **1.1.28** while the
   reasoning had been done against upstream master. A differing debug format
   string was the clue.
3. **Verify, never assume.** "It returned 0" is not "it worked". A stub HAL
   accepts every write and reports success. `paplay` exits 0 into silence.
4. **An absent log line is not evidence of an absent event.** See the dmesg
   note above.
5. **Instrument rather than infer.** Two sessions of D-state sweeps could not
   see an R-state holder by construction; one printk answered it.
6. **One variable at a time**, and keep a known-good image within reach.
7. **Check a patch's premise, not just that it applies.**
   `abox-runtime-pm-get-sync.patch` applied cleanly, read plausibly, and was
   wrong about what the driver does.
8. **Do not poll hardware mixers.** Rewriting mixer controls mid-stream
   corrupts playback — it sounds like fast-forward. Fix configuration at the
   source instead.
9. Keep replies short; do the work in the tools.

---

## 4. What works, and what it took

Full write-ups in `docs/experiments/`. Short version:

**Audio** ([007](experiments/007-abox-firmware-too-early.md)) — three faults:
the DSP never booted because its firmware is requested at t=1.43 s and no
filesystem exists until t=2.08 s (fixed with `CONFIG_EXTRA_FIRMWARE`);
PulseAudio loaded a 12 KB **stub** HAL because the `hidl_compat` wrapper was
bind-mounted only inside the container while PulseAudio runs on the host; and
the vendor routes the speaker from `SIFS1 ← RDMA7`, a channel this DSP NACKs.

**Bluetooth** ([008](experiments/008-bluetooth-hci-sock.md)) — "CONFIG_BT
bootloops this device" was a misdiagnosis. The vendor tree comments out ~700
lines of `hci_sock.c`, so `hci_sock_create()` returns 0 without allocating a
sock and `bt_sock_create()` hits `BUG_ON(!sk)`. Any AF_BLUETOOTH socket panics
the kernel, and `bluebinder` opens one every boot.

**Telephony** — no kernel change. A missing `/etc/deviceinfo/devices/a50.yaml`
meant ofono silently used the legacy RIL plugin; `binder.conf` needed slot
paths, `radioInterface = 1.4`, and a `signalStrengthRange` suited to LTE RSRP
instead of RSSI.

---

## 5. Live hazards

* **The camera driver panics the kernel.** `fimc_is_devicemgr_open` NULL-derefs
  when anything enumerates V4L2, and `gst-plugin-scan` does. It presents as a
  bootloop from the user session and is easy to misattribute to whatever you
  just changed.
* **Do not unbind the ABOX driver.** `echo … > /sys/bus/platform/drivers/samsung-abox/unbind`
  panics. Rebind is not a usable test method.
* **Getting back to TWRP is unreliable** — `systemctl reboot
  --reboot-argument=recovery` works sometimes. Prefer flashing from running
  Linux.
* **Restarting ofono during a call** orphans the call and leaves PulseAudio's
  droid card stuck in the `voicecall` profile, which has no sinks at all. Media
  goes silent and the *next outgoing call* has no audio. `a50-audio-unstick.sh`
  clears it.

---

## 6. Runtime state that is NOT in git

Re-apply with `scripts/apply-device-workarounds.sh` plus the `overlay/` tree.
Also `/lib/firmware/calliope_*.bin`, and the OpenStore libs
(`libxml2.so.2`, `libicu*.so.74`) copied from `/userdata/rootfs-24.04.img`.

Images on `/userdata`: `rootfs.img` (live 26.04), `rootfs-26.04.img` (backup),
`rootfs-24.04.img` (**bootloops at ~15 s — keep only as a library source**).

---

## 7. Next steps, in order

1. **Fingerprint — finish enrollment.** The hard part is done: biometryd's
   `NotPermitted` wall (the AppArmor twin of the GPS one) is bypassed, so the
   Settings fingerprint page no longer crashes and the HAL enrolls
   (`preenroll_flag:1`, waiting for touches). What is left is real on-screen
   enrollment through Settings → Security & Privacy → Fingerprint on the
   under-display EGISTEC ET713, then confirming greeter unlock. See
   [experiment 012](experiments/012-fingerprint.md). If a CLI enroll aborts at
   0 %, retry — it is neither the permission wall nor a token problem.

2. **Camera.** `fimc_is_devicemgr_open` NULL-derefs when anything enumerates
   V4L2 (e.g. `gst-plugin-scan`), panicking the kernel. Presents as a bootloop
   from the user session and is easy to misattribute. A stability bug, not just
   a missing feature.

3. **Drop the `ld.config.txt` hack.** `a50-audio-hidl-compat.service` rewrites
   generated linker config every boot so the HAL wrapper can resolve
   `libaudiohal.so`. `HYBRIS_USE_VENDOR_NAMESPACE` exists to make that
   unnecessary and demonstrably does not work here — verified, the variable is
   absent from PulseAudio's environment and the load still fails. Understanding
   why deletes the hack. Worth doing before publishing.

4. Bluetooth **HFP** (calls over BT) and **headphone/earpiece** audio: both
   untested. Only the speaker path and A2DP are proven.

5. `usb-tethering.service` and `ssh.service` failures are expected — an sshd
   started by the boot script owns port 22. Do **not** "fix" `ssh.service`; it
   is the one service that could lock you out.
