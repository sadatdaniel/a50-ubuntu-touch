# Session handoff — Samsung A50 / Ubuntu Touch

**Written 2026-09-04.** Everything a fresh session needs to pick this up.
Read this first, then `docs/status.md` and
`docs/experiments/006-what-we-missed.md`.

---

## 0. RIGHT NOW: the device is recovered and healthy

**Updated 2026-09-04, later session.** The `boot-abox-bt.img` experiment
described in earlier versions of this section is over. It did not boot, the
device was recovered to the known-good image, and it now runs `uname #4` with
`lightdm` active (`NRestarts=0`), container `sys.boot_completed=1`, `mali0`
opening instantly and zero `misc_open` waiters.

### Flashing no longer needs TWRP

The boot partition is writable from running Ubuntu Touch. It is **`/dev/sda14`**
(the `/dev/block/bootdevice/by-name/` symlinks are an Android-init thing and do
not exist on the UT side):

```sh
dd if=/userdata/<image>.img of=/dev/sda14 bs=4M; sync
# then read it back and hash it before rebooting - always
dd if=/dev/sda14 bs=1M count=52 2>/dev/null | head -c <image size> | sha256sum
```

A known-good image is staged **on the device** at
`/userdata/boot-known-good.img` (sha256 `1fa490eb…`, identical to
`boot-miscdbg2.img`), so a rollback is one `dd` with no host transfer and no
TWRP.

### If a flash does leave it unbootable

TWRP (Power+VolUp+USB), then push from the host — `/tmp` in TWRP is a ramdisk
and is wiped on reboot:

```sh
cd C:\Users\sadat\.zcode\workspace\default\a50-first-build
adb push boot-miscdbg2.img /tmp/b.img
adb shell 'dd if=/tmp/b.img of=/dev/block/bootdevice/by-name/boot bs=4M; sync'
```

`boot-miscdbg2.img` is the last known-good image. `boot-backup-preUT.img`
returns the device to its pre-project state. Both are published in the GitHub
release `boot-images-2026-09-04`.

### Why `boot-abox-bt.img` told us nothing

No kernel evidence of its failure survives: `/sys/fs/pstore` is empty and
`/proc/last_kmsg` held only the S-Boot log, because the device was recovered
with a forced button reset and Samsung's `sec_debug` clears its buffers on a
PIN reset. Do not go looking for it again.

It also moved **three** variables, not two. Its manifest is
`0001..0004 + 0005-abox + 0006-bt`, which silently **drops**
`misc-open-scope-and-tracing.patch` — the patch `d21f4fc` records as the source
of `uname #4`, the kernel that runs all day. **Every experimental build must
start from that patch set**, i.e. `kernel/patches/` *plus* the misc scope fix,
not `kernel/patches/` alone.

Bluetooth remains parked and remains the prime suspect for the older bootloop
(a50-halium `kernel/patches-experimental/README.md` already isolated it). It
stays out of every build until audio lands.

---

## 1. How to talk to the device

SSH over the USB RNDIS link. **Windows loses the static IP whenever the phone
re-enumerates**, so if ping fails, re-add it from an **elevated** shell:

```
netsh interface ip add address "Ethernet 9" 10.15.19.100 255.255.255.0
```

Then (root password `1234`; `plink` is used because OpenSSH hangs here):

```
plink -ssh -batch -hostkey "SHA256:BPpKdQdHCDAeDLdNFhWAXWN5Pfqxr9zNUb2gAiLk++4" -pw 1234 root@10.15.19.82 "uptime"
```

Rules that cost time to learn:

* Always wrap remote work in `timeout`, and background long jobs with
  `</dev/null >/dev/null 2>&1 &` — a remote job holding the pipe hangs the
  whole ssh session.
* `mount -o remount,rw /` before writing anything to the rootfs.
* **Android HAL errors appear only in logcat**, never in the journal:
  `lxc-attach -n android -- /system/bin/logcat -d -b all`
* logcat timestamps run ~2 h behind local time; don't mistake old lines for new.
* dmesg is flooded by battery SELinux spam every 10 s and evicts boot messages
  fast. For boot-time evidence read `/proc/last_kmsg` (previous boot).
* From TWRP, use adb, and prefix pushes with `MSYS_NO_PATHCONV=1` **and** `cd`
  into the file's directory, or Git Bash mangles the paths.

---

## 2. What works now

| Area | State |
|---|---|
| Boot chain | S-Boot → tools-packed image → halium-boot initramfs → `switch_root` → systemd. Solid. |
| Display / Lomiri | Works. Boots to the UI. |
| Wi-Fi | Works (associates on `swlan0`). |
| Browser / DNS | Works. |
| OpenStore | **Works** after co-installing old SONAMEs. |
| Rotation | Works (`sensorfwd` unmasked). |
| Shell scaling | `GRID_UNIT_PX=21`. |
| Audio | **No sound.** Userspace fully fixed; DSP does not boot. See §4. |
| Bluetooth | Not working; needs `CONFIG_BT`. Untested patch now flashed. |

---

## 3. The big fixes, and why they were needed

**Display blocker — `misc_list` corruption.** `f_conn_gadget.c` registers a
single *static* `miscdevice` with no already-registered guard, so instantiating
the configfs function twice makes `misc_list` circular and `misc_open()` spins
forever holding `misc_mtx` — freezing every misc open on the system (mali0,
ion, binder, HALs). It looks exactly like a hung GPU. Triggered because
`usb_moded` and the container's `vendor_init` both drive USB gadget configfs.
Worked around by keeping the container away from USB configfs; the real fix is
`a50-halium/kernel/patches-experimental/conn-gadget-double-register.patch`.

**Greeter blocker — `/dev/hwbinder` was `0600`.** The gralloc mapper is a HIDL
HAL over hwbinder; the compositor runs as root and worked, the greeter (uid
108) did not. Fixed by `overlay/usr/lib/udev/rules.d/99-a50-binder.rules`.

**OpenStore.** 26.04 ships libxml2 2.15 (`libxml2.so.2` → `.so.16`), which
breaks focal-framework clicks. Fixed by co-installing the **genuine** old
libraries from the 24.04 image already on the device. Do **not** symlink a
renamed library to the old name — that links, then corrupts the heap.

---

## 4. Audio — where it actually stands

The **entire userspace chain is fixed and proven**:

* the GSI's `init.disabled.rc` disabled both audio HALs → overridden, so
  `init.svc.vendor.audio-hal = running`;
* the real Samsung HAL is 32-bit only → Android's 64-bit `audio.hidl_compat`
  wrapper bind-mounted over `/vendor/lib64/hw/audio.primary.default.so`;
* the wrapper needs `libaudiohal.so`, invisible in the vendor/sphal namespace →
  **`HYBRIS_USE_VENDOR_NAMESPACE` must be UNSET** (not `0` — libhybris tests
  presence). Drop-in must sort after `ubuntu-touch.conf`, hence `zz-`;
* `use_legacy_stream_set_parameters=true` stops the droid module segfaulting.

Proof it works: logcat shows **real `adev_open_output_stream` / `out_write`
calls** from PulseAudio's own PID — the exact end-to-end signal the Droidian
port documents as "working".

**The remaining blocker is in the kernel, below all of that.** The ABOX audio
DSP never boots: `samsung-abox: Invalid calliope state: 0`, no `abox_enable`,
no firmware download, and `speaker-test` straight to `hw:0,0` with PulseAudio
stopped fails with `-EIO`. So it is *not* a PulseAudio or HAL problem.

**Root cause, proven on hardware 2026-09-04** — and it is *not* what the parked
patch says. See [experiment 007](experiments/007-abox-firmware-too-early.md)
for the full log.

`samsung_abox_probe()` requests `calliope_sram.bin` at **t = 1.43 s**, and this
device has **no filesystem at all until t = 2.08 s** — the kernel rejects the
boot image's ramdisk as an initramfs ("junk in compressed archive; looks like
an initrd"), frees it, and Samsung's `SAR_RD` loader brings it up only at
2.08 s. So the request fails `-ENOENT`,
`abox_complete_sram_firmware_request()` returns early on `!fw` and **never
retries**, and probe's `pm_runtime_get()` pins the usage count so the device
can never idle and resume to try again. One shot, missed by 0.65 s.

`abox-runtime-pm-get-sync.patch` is therefore **disproved**: its premise is
that `pm_runtime_get()` never invokes the resume callback, but the boot log
shows `abox_enable` running at 1.4249 s. Do not flash it as "the audio fix".

The fix under test is `CONFIG_EXTRA_FIRMWARE` — link the calliope blobs into
the kernel image, since `fw_get_builtin_firmware()` is checked before any
filesystem. Putting the firmware in the initramfs was tried first and does
**not** work, for the SAR_RD reason above.

Ruled out along the way: firmware presence, the CP/`cass` daemon, `/dev/snd`
permissions, the `calliope_cmd FAILSAFE` path, and PCM contention.

---

## 5. Runtime state that is NOT in git

These live only on the device and are lost on a rootfs reflash. Re-apply with
`scripts/apply-device-workarounds.sh`, plus, for audio:

* `/lib/firmware/calliope_*.bin` (copied from `/vendor/firmware`)
* `/etc/systemd/user/pulseaudio.service.d/zz-a50-hybris.conf` with
  `UnsetEnvironment=HYBRIS_USE_VENDOR_NAMESPACE`
* the `audio.hidl_compat` bind-mount over
  `/android/vendor/lib64/hw/audio.primary.default.so`
* OpenStore libs: `libxml2.so.2` + `libicu*.so.74` copied from
  `/userdata/rootfs-24.04.img`

Images on `/userdata`: `rootfs.img` (live 26.04), `rootfs-26.04.img` (backup),
`rootfs-24.04.img` (**bootloops at ~15 s — keep only as a library source**).

---

## 6. Build and reproducibility

**Never build on a Windows bind mount** — the kernel tree has case-colliding
filenames (`xt_CONNMARK.c` / `xt_connmark.c`) that Docker Desktop's mount
silently loses, producing `No rule to make target`. Build inside the container:

```
docker run --rm -v "C:/Users/sadat/Development/a50-ut-out/kbuild:/outdir" a50-halium-build bash -c \
 'git clone -q https://github.com/sadatdaniel/a50-halium.git /w && cd /w && ./build/build-kernel.sh && cp out/* /outdir/'
```

Reproducibility is **verified**: a fresh GitHub clone built in-container gives
`074aad86958de6b8a4914269826f87f70c7eeb5315bb3842e4d935dacd566be6`, matching
`kernel/expected-artifacts.sha256` exactly.

To test a patch, copy it from `kernel/patches-experimental/` into
`kernel/patches/` before building. To pack a boot image, reuse the header from
a working image and patch only `kernel_size`/`ramdisk_size` (S-Boot ignores the
id digest — experiment 001/004). Boot partition limit: **57,671,680 bytes**.

Host disk is tight (~5 GB). `docker system df`; stopped containers are the
usual win.

---

## 7. Next steps, in order

1. **Boot-test the flashed kernel** (§0). Audio and BT both hinge on it.
2. If it loops → revert (§0), rebuild with the ABOX patch alone.
3. If audio works → make the runtime bits persistent (§5) in
   `scripts/apply-device-workarounds.sh` and `overlay/`, then promote
   `abox-runtime-pm-get-sync.patch` to `kernel/patches/`.
4. If BT works → `bluebinder` should stop failing with `ENODEV`; promote that
   patch too.
5. Remaining: AppArmor (needed for confinement; apps do launch without it),
   `usb-tethering.service` and `ssh.service` failures (expected — an sshd
   started by the boot script owns port 22; do **not** "fix" `ssh.service`, it
   is the one service that could lock you out).

---

## 8. Working agreements

* **Search for a known fix before improvising.** The OpenStore SONAME break and
  its fix were publicly documented; not checking first cost a rootfs build and
  a bootloop.
* **Sanity-check every decision before acting** — verify a URL resolves, a
  patch applies, a path exists.
* Verify, never assume. "It returned 0" is not "it worked": `paplay` exits 0
  into a stub HAL that makes no sound, and sinks appear even when the HAL is a
  stub.
* **An absent log line is not evidence of an absent event.** The kernel ring
  buffer holds ~8,600 lines and the container's `ueventd` `restorecon` storm
  wipes the whole boot out of it within a second of starting. Two sessions
  concluded "`abox_enable` never runs" from a `dmesg | grep` that could not
  physically have contained it. Before drawing a conclusion from a missing
  line, check what the buffer actually still covers (`dmesg | head -1`).
  `a50-dmesg-snap.service` on the device now snapshots the buffer at t ≈ 5.3 s,
  before the flood, into `/userdata/dmesg-boot-first.txt` — read that, not
  live `dmesg`, for anything about boot.
* Check a patch's *premise* against the source before building it, not just
  whether it applies. `abox-runtime-pm-get-sync.patch` applied cleanly, read
  plausibly, and was wrong about what the driver does.
* Keep replies short; do the work in the tools.
