# Session handoff — Samsung A50 / Ubuntu Touch

**Written 2026-09-05.** Everything a fresh session needs to pick this up.
Read this first, then `docs/status.md`, then the experiment you are touching.

---

## 0. RIGHT NOW: the device is healthy, everything is pushed

The phone boots and runs with **audio, Bluetooth, phone calls and mobile data
all working**, verified across clean reboots. Both repositories are committed
and pushed; nothing of value lives only on a local machine.

The boot partition holds `53fe13b5…`, which is the published
`boot-a50-2026-09-05.img`.

### In flight right now

A kernel build adding **AppArmor** was started and may or may not have
finished. See §7 — it is the fix for GPS. If you are unsure whether it landed,
just rebuild; the recipe is committed.

---

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

1. **AppArmor — in flight, and it is the GPS fix.** GPS is not broken: the GNSS
   HAL registers `android.hardware.gnss@1.0`–`@2.1`, `gpsd` and
   `sec_gnss_service` run, and `lomiri-location-serviced` starts its
   `gps::Provider`. But every session is refused with

       Error creating session: Client lacks permissions to access the service

   because Ubuntu Touch identifies apps through AppArmor and **AppArmor is not
   built** (`aa-status` → "apparmor not present"; zero AppArmor strings in the
   kernel image against 10 for selinux). A build adding
   `CONFIG_SECURITY_APPARMOR` with `CONFIG_DEFAULT_SECURITY="apparmor"` — the
   option set from Halium's own `check-kernel-config` — was started at the end
   of the session. **Boot-test it carefully**: on 4.14 the major LSMs are
   mutually exclusive, so this makes SELinux non-default, and the Android
   container is the thing to watch. The container already runs
   `androidboot.selinux=permissive`, so nothing there should depend on SELinux
   enforcing — but verify, do not assume. This also unblocks app confinement.

2. **Camera.** The NULL-deref above. A stability bug, not just a missing
   feature.

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
