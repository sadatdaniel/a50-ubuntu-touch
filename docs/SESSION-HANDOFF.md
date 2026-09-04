# Session handoff — Samsung A50 / Ubuntu Touch

**Written 2026-09-04.** Everything a fresh session needs to pick this up.
Read this first, then `docs/status.md` and
`docs/experiments/006-what-we-missed.md`.

---

## 0. RIGHT NOW: the device is in an experiment, and it may not boot

The boot partition currently holds **`boot-abox-bt.img`** — a kernel carrying
two untested patches (audio DSP fix + Bluetooth). It was flashed from TWRP and
**has not been boot-tested yet**.

### If it boots

Verify the two things it was built for:

```sh
# audio DSP: this must NOT say "Invalid calliope state: 0"
ssh root@10.15.19.82 "dmesg | grep -aiE 'abox_enable|SRAM firmware|calliope' | grep -vi fg_asoc | head"
# bluetooth: /dev/vhci should now exist and hciconfig should not error
ssh root@10.15.19.82 "ls -l /dev/vhci; hciconfig -a | head -3; systemctl status bluebinder --no-pager | head -5"
```

### If it bootloops or hangs — GET BACK TO SAFETY

Boot into TWRP (Power+VolUp+USB), then:

```sh
adb shell 'dd if=/tmp/boot-backup-prev.img of=/dev/block/bootdevice/by-name/boot bs=4M; sync'
```

`/tmp` in TWRP is a ramdisk and is wiped on reboot. If that file is gone, push
a known-good image from the host instead:

```sh
cd C:\Users\sadat\.zcode\workspace\default\a50-first-build
adb push boot-miscdbg2.img /tmp/b.img
adb shell 'dd if=/tmp/b.img of=/dev/block/bootdevice/by-name/boot bs=4M; sync'
```

`boot-miscdbg2.img` is the **last known-good boot image** (the one that ran all
day). `boot-backup-preUT.img` returns the device to its pre-project state.
Both are also published in the GitHub release `boot-images-2026-09-04`.

**If the combined kernel bootloops, Bluetooth is the prime suspect** — it
bootlooped once before (a50-halium `kernel/patches-experimental/README.md`).
Rebuild with `0005-abox.patch` only and retest; that isolates it.

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

Root cause found: `samsung_abox_probe()` calls `pm_runtime_get()` — which is
asynchronous and never invokes the resume callback. `abox_runtime_resume()` →
`abox_enable()` is the only path that downloads `calliope_*.bin` and releases
the DSP from reset, and the pinned usage count then prevents any later resume.
Fix: `pm_runtime_get_sync()` —
`a50-halium/kernel/patches-experimental/abox-runtime-pm-get-sync.patch`,
**now flashed and awaiting its first boot test**.

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
* Keep replies short; do the work in the tools.
