# Experiment 007 — why the audio DSP never boots: the firmware is requested before any filesystem exists

**Date:** 2026-09-04/05 · **Status:** ✅ **resolved — audio works.** Sound out
of the speaker, through PulseAudio, surviving a reboot with no manual steps.
· **Device needed:** yes

Three separate faults had to be fixed, in this order: the DSP firmware was
requested before any filesystem existed (Part 1), the speaker route is never
set by anything in Ubuntu Touch (Part 3 §13), and the droid HAL silently
swallows audio (Part 3 §14).

## TL;DR

The ABOX audio DSP never starts because `samsung_abox_probe()` asks for
`calliope_sram.bin` at **t = 1.43 s**, and on this device **no filesystem of
any kind exists until t = 2.08 s**. The request fails with `-ENOENT`, the
driver's completion callback returns early and **never retries**, and probe's
`pm_runtime_get()` pins the usage count so the device can never idle and resume
to try again. The DSP stays in reset forever: `Invalid calliope state: 0`,
every PCM write `-EIO`.

**The parked patch `abox-runtime-pm-get-sync.patch` is based on a false premise
and cannot fix this.** Its claim — that `pm_runtime_get()` never invokes the
resume callback — is disproved by the boot log below: `abox_enable` runs.

The fix under test is `CONFIG_EXTRA_FIRMWARE`, which links the blobs into the
kernel image, because built-in firmware is the only source available that
early.

## 1. The evidence

Captured from a snapshot of the kernel ring buffer taken at t = 5.32 s, the
first moment anything in userspace can run (see §3 for why this was hard):

```
[    1.424961] samsung-abox 14a50000.abox: abox_enable
[    1.424966] samsung-abox 14a50000.abox: abox_request_cpu_gear(ab0cdefa, 1)
[    1.425029] samsung-abox 14a50000.abox: abox_download_firmware
[    1.425034] samsung-abox 14a50000.abox: SRAM firmware downloading is deferred
[    1.425075] samsung-abox 14a50000.abox: Direct firmware load for calliope_sram.bin failed with error -2
[    1.425079] samsung-abox 14a50000.abox: Falling back to user helper
[    1.425152] samsung-abox 14a50000.abox: samsung_abox_probe: probe complete
[    2.194323] samsung-abox 14a50000.abox: Failed to request firmware
```

Read against the driver source, that is the whole failure:

1. `pm_runtime_get()` **does** trigger the async resume — `abox_enable` is
   right there at 1.4249 s. The premise of the get-sync patch is wrong.
2. `abox_download_firmware()` finds `data->firmware_sram == NULL`, issues
   `request_firmware_nowait()` and returns `-EAGAIN`. `abox_enable()` maps
   `-EAGAIN` to `ret = 0` and returns, so the resume callback **succeeds** and
   `runtime_status` becomes `active` — with the DSP still in reset. That is why
   the device looks healthy while producing no sound.
3. The direct load fails `-2` (`-ENOENT`); the user-helper fallback times out
   at 2.19 s with `fw == NULL`.
4. `abox_complete_sram_firmware_request()` opens with

   ```c
   if (!fw) {
           dev_err(dev, "Failed to request firmware\n");
           return;
   }
   ```

   — no retry, ever. And `abox_enable()` has only two callers: this callback,
   and `abox_runtime_resume()`.
5. `abox_runtime_resume()` cannot run again, because probe's `pm_runtime_get()`
   holds the usage count at 1 for the life of the boot. Confirmed on the
   device: `runtime_status=active`, `runtime_suspended_time=1330` ms total.

So there is exactly one moment when the firmware can be loaded, and it is
1.43 s into boot.

## 2. Why no filesystem exists at 1.43 s — and why an initramfs cannot help

The obvious fix is to put the firmware in the initramfs, since `populate_rootfs`
(a `rootfs_initcall`) runs before `device_initcall`, where
`module_platform_driver(samsung_abox_driver)` registers. **It was tried, and it
does not work on this device.** From the same boot log:

```
[    0.475113] Trying to unpack rootfs image as initramfs...
[    0.477985] rootfs image is not initramfs (junk in compressed archive); looks like an initrd
[    0.486410] Freeing initrd memory: 11808K
[    1.879811] RAMDISK: Couldn't find valid RAM disk image starting at 0.
[    1.881833] SAR_RD: Trying to load Ramdisk at offset 41637888
[    2.077999] SAR_RD: Successfully loaded ramdisk
```

The kernel **rejects** the boot image's ramdisk as an initramfs and frees it.
Samsung's own `SAR_RD` loader picks it up from the boot image at offset
41637888 and brings it up at **2.08 s** — 0.65 s after ABOX has already asked
and given up.

This was tested directly, not reasoned about. A boot image was built with the
seven firmware files added to the halium-boot initramfs at `/lib/firmware/`,
with a kernel byte-identical to the known-good one so the firmware was the only
variable, and with the cpio round-trip verified lossless first (every
pre-existing file identical in content, permissions and ownership; the only
delta being the seven blobs). It changed nothing —
`Direct firmware load for calliope_sram.bin failed with error -2` at
1.432125 s, exactly as before.

That leaves built-in firmware, which `_request_firmware()` checks via
`fw_get_builtin_firmware()` **before** touching any filesystem.

## 3. Why this took so long to see: the ring buffer never contained it

Every previous session's "no `abox_enable` in dmesg" conclusion was an
artifact. The kernel log buffer holds about 8,600 lines, and from roughly
t = 7 s the Android container's `ueventd` runs `restorecon` across `/sys` and
emits thousands of `Could not set context ... Operation not supported on
transport endpoint` lines, which evict the entire boot in about a second. On
the known-good kernel the MISCDBG tracing printks make it worse: `bluebinder`
restarting on `ENODEV` was on its own filling the buffer, so at uptime 512 s
`dmesg` reached back only to t = 342 s.

What made the log readable:

* `systemctl mask --now bluebinder` — it is failing anyway, waiting for a
  `/dev/vhci` that does not exist without `CONFIG_BT`.
* `a50-dmesg-snap.service`, installed on the device, which snapshots `dmesg`
  to `/userdata/dmesg-boot-*.txt` **immediately** on start (t ≈ 5.3 s, before
  the flood) and then at fixed uptimes. The first snapshot is the one that
  matters; it reaches back to `[0.000000]`.

A first attempt at this got nothing useful because the unit itself only starts
at t ≈ 5.3 s and the script then slept a further N seconds — so the "6 s"
snapshot was really taken at 11.3 s, well after the flood. The script now keys
off `/proc/uptime` and takes its first snapshot before anything else.

## 4. Also learned: do not unbind this driver

`echo 14a50000.abox > /sys/bus/platform/drivers/samsung-abox/unbind`, tried as
a way to re-probe with the firmware present, **panics the kernel**:

```
Unable to handle kernel NULL pointer dereference at virtual address 00000620
Kernel panic - not syncing: Fatal exception
```

The device reboots and comes back clean, so it is recoverable, but the remove
path is not safe. Do not use rebind as a test method here.

## 5. The fix being tested

`CONFIG_EXTRA_FIRMWARE`, appended to the same generated Kconfig set that patch
0002 writes, with the blobs copied from the device's own `/vendor/firmware`
into the kernel tree's `firmware/` directory:

```
CONFIG_EXTRA_FIRMWARE="calliope_sram.bin calliope_dram.bin calliope_iva.bin \
    tfadsp.bin AP_AUDIO_SLSI.bin APBargeIn_AUDIO_SLSI.bin APBiBF_AUDIO_SLSI.bin"
CONFIG_EXTRA_FIRMWARE_DIR="firmware"
```

`calliope_sram.bin` and `calliope_dram.bin` are the load-bearing pair. The
extras are the ones the live device tree marks `status = "okay"`, read from
`/proc/device-tree/abox@0x14A50000/*/samsung,name`; `calliope_iva.bin` is
included because it is small and sits beside the others in `/vendor/firmware`.
Total 2,357,000 bytes added to the kernel image, against 5,240,832 bytes of
spare boot partition.

The expected chain, if this works:

1. probe at 1.43 s → `abox_enable` → `abox_download_firmware` →
   `request_firmware_nowait` resolves from **built-in** firmware, no filesystem
   touched;
2. `abox_complete_sram_firmware_request` gets a real `fw`, logs
   *SRAM firmware loaded*, then loads `calliope_dram.bin` **synchronously**
   (`abox_request_firmware()` uses plain `request_firmware()`);
3. the live device tree sets `quirks = ... "off on suspend" ...`, so
   `ABOX_QUIRK_OFF_ON_SUSPEND` is set, and `pm_runtime_active(dev)` is true —
   both conditions of the callback's re-enable path hold — so it calls
   `abox_enable(dev)` again;
4. this time both firmwares are present, so `abox_cpu_power(true)` /
   `abox_cpu_enable(true)` run and `calliope_state` leaves `CALLIOPE_DISABLED`.

Verified before building: the live DT really does carry the quirk, and this
kernel really does support `CONFIG_EXTRA_FIRMWARE` (`firmware/Makefile`
hardcodes `CONFIG_EXTRA_FIRMWARE_DIR="firmware"`, so the blobs must sit at the
kernel source root, which is where the build script puts them).

## 6. What to check on the next boot

```sh
grep -aE 'abox_enable|SRAM firmware|calliope|is loaded' /userdata/dmesg-boot-first.txt
cat /sys/devices/platform/14a50000.abox/calliope_version   # currently blank
```

*SRAM firmware loaded* appearing, and `calliope_version` being non-blank, are
the signals. Then, and only then, is a `speaker-test` meaningful.

## 7. Recovery notes from the same session

The device had been left holding an untested `boot-abox-bt.img`, which did not
boot. It was recovered to `boot-miscdbg2.img` (sha256 `1fa490eb…`), verified by
reading the boot partition back and hashing it, and came up clean: `uname #4`,
`lightdm` active with `NRestarts=0`, container `sys.boot_completed=1`, `mali0`
opening instantly, zero `misc_open` waiters.

Two things worth keeping from that:

* **No kernel evidence of the ABOX+BT failure survives.** `/sys/fs/pstore` is
  empty and `/proc/last_kmsg` held only the S-Boot log, because the device had
  been recovered with a forced button reset and Samsung's `sec_debug` clears
  its buffers on a PIN reset (`this is PIN RESET, clear all`). Do not go
  looking for it again.
* **That image moved three variables, not two.** Its build manifest is
  `0001..0004 + 0005-abox + 0006-bt`, which silently **drops**
  `misc-open-scope-and-tracing.patch` — the patch a50-halium `d21f4fc` records
  as the source of `uname #4`, the kernel that runs all day. Any future
  experimental build must start from that patch set, not from
  `kernel/patches/` alone.

The boot partition can be written from running Ubuntu Touch — it is
`/dev/sda14`, and `dd` to it works — so an experiment no longer needs a TWRP
round-trip. A known-good image is staged on the device at
`/userdata/boot-known-good.img` for rollback.

---

# Part 2 — the DSP boots. What that exposed.

**Result of the `CONFIG_EXTRA_FIRMWARE` build: it works.** From the boot
snapshot, at the same 1.49 s where the old kernel gave up:

```
[    1.494942] samsung-abox 14a50000.abox: abox_enable
[    1.495012] samsung-abox 14a50000.abox: abox_download_firmware
[    1.495017] samsung-abox 14a50000.abox: SRAM firmware downloading is deferred
[    1.495027] samsung-abox 14a50000.abox: SRAM firmware loaded
[    1.495032] samsung-abox 14a50000.abox: calliope_dram.bin is loaded
[    1.495060] samsung-abox 14a50000.abox: abox_enable          <- re-enabled, quirk path
[    1.495096] samsung-abox 14a50000.abox: abox_download_firmware
```

Predicted chain, observed exactly. And the two signals that matter:

| | before | after |
|---|---|---|
| `calliope_version` | blank | **`rSK1`** |
| `Invalid calliope state: 0` | every boot | **absent from every snapshot** |
| `Failed to request firmware` | present | absent |

The DSP is out of reset and answering IPC. `lightdm` `NRestarts=0`, container
`sys.boot_completed=1`, system stable. **This is the fix for the audio DSP.**

## 8. Still no sound: the last route is not connected

With the DSP alive, `speaker-test -D hw:0,0` still failed `-EIO`, but for a new
reason. The kernel side now runs clean — no errors at all:

```
abox_hw_params_fixup_helper[SIFS1](0)
abox_hw_params_fixup_helper: ABOX SIFS1: 16 bit, 2 channel, 48000Hz
vogue_dai_ops_hw_params: RDMA0-0: hw_params: 2ch, 48000Hz, 131072bytes, 16bit
abox_rdma_trigger[0](1)      <- stream starts
abox_rdma_trigger[0](0)      <- stops ~2 s later
```

It starts and then xruns, because the last hop of the path is unrouted. The
speaker amplifier's interface is identified in the boot log:

```
[    1.517561] Exynos9610-audio sound: tfa98xx-aif-7-34 <-> UAIF2 mapping ok
```

so the chain is `RDMA0 → SPUS OUT0 → SIFS1 → UAIF2 → TFA9872`. Read back from
the running device, the first two hops are already correct and the last is
not:

| control | value | meaning |
|---|---|---|
| `ABOX SPUS OUT0` | 0 = `SIFS1` | correct |
| `ABOX SIFS1` | 0 = `SPUS OUT0` | correct |
| **`ABOX UAIF2 SPK`** | **0 = `RESERVED`** | **not connected** |

Nothing in the Ubuntu Touch stack sets it; on Android the HAL does, from
`mixer_paths`. Note also that the mixer does **not** persist — there is no
`/var/lib/alsa/asound.state` and `alsa-restore` is `static` — so any manual
routing is gone after a reboot. That is worth knowing both ways: it is why a
bad setting cannot brick a boot, and why a good one will not survive one.

## 9. Setting that route panics the kernel — a real driver bug

`amixer -c 0 cset name='ABOX UAIF2 SPK' SIFS1` succeeds, and then starting a
stream panics, reproducibly:

```
speaker-test: Unable to handle kernel NULL pointer dereference at 00000010
pc : abox_hw_params_fixup_helper+0x830/0x1150
Kernel panic - not syncing: Fatal exception
```

`0x10` is `offsetof(struct snd_soc_dai, dev)` (`name`, `id`, `dev`), and
`abox_if_hw_params_fixup_by_dai()` starts with `struct device *dev = dai->dev`.

The cause is in the fallback branch of `abox_hw_params_fixup_helper()`:

```c
list_for_each_entry(w, &widget_list, work_list) {
        struct snd_soc_dai *dai;
        if (!w->sname)
                continue;
        dai = w->priv;
        if (abox_if_hw_params_fixup_by_dai(dai, params, stream) >= 0) {
```

`w->priv` holds a `snd_soc_dai` **only for DAI widgets** — `soc-dapm.c` assigns
it in `snd_soc_dapm_new_dai_widgets()` and nowhere else — but `w->sname` is set
on many more widgets than that, AIF widgets included. So the loop hands the
function something that is not a DAI.

Stock Android never reaches this branch: it is only entered when the first
attempt, `abox_if_hw_params_fixup(rtd, ...)` on `rtd->cpu_dai`, fails, and in
Samsung's own routing it succeeds. Our route puts the interface somewhere other
than the runtime's own cpu_dai, so we fall into code Samsung never runs.

**Not a local regression.** The identical unguarded loop, and the identical
unguarded `abox_if_hw_params_fixup_by_dai()`, are present verbatim in another
Samsung Exynos ABOX tree (Galaxy Note9 exynos9810 Pie,
`freeza-inc/bm-galaxy-note9-exynos-pie`) — checked directly. This is
long-standing in Samsung's driver.

Fix, in `kernel/patches-experimental/abox-fixup-helper-dai-guard.patch`: filter
on `w->id` being `snd_soc_dapm_dai_in`/`dai_out` and check `w->priv`, exactly
as ASoC's own `snd_soc_dapm_connect_dai_link_widgets()` guards the same lookup;
plus make `abox_if_hw_params_fixup_by_dai()` return `-EINVAL` on a NULL dai.
That last one fits the function's existing contract — it is already written to
be called speculatively and to reject DAIs that are not its own
(`dev->driver != &samsung_abox_if_driver.driver` → `-EINVAL`).

## 10. An unrelated crash found on the way: the camera driver

The first crash during this work was **not** audio, and it is worth recording
so it is not misattributed later:

```
gst-plugin-scan: Unable to handle kernel paging request at ffffff800c1613b0
pc : fimc_is_devicemgr_open+0x1e8/0x3a0
Kernel panic - not syncing: Fatal exception
```

`gst-plugin-scan` enumerating V4L2 devices crashes the Exynos FIMC-IS camera
driver. This is independent of audio and independent of the firmware change,
and it can look exactly like a bootloop because it fires from the user session.

## 11. Also: do not use driver unbind as a test here

`echo 14a50000.abox > /sys/bus/platform/drivers/samsung-abox/unbind` panics
(`NULL pointer dereference at 00000620`). The device recovers on reboot, but
the remove path is not safe. Rebind is not a usable way to re-probe this driver.

## 12. Where this leaves audio

* **Solved:** the DSP never booting. `CONFIG_EXTRA_FIRMWARE` fixes it, proven
  by `calliope_version = rSK1` and the disappearance of
  `Invalid calliope state: 0`.
* **Solved (pending boot test):** the panic that blocked enabling the speaker
  route, via the DAI guard patch.
* **Open:** `ABOX UAIF2 SPK` has to be set to `SIFS1` for the speaker path to
  exist at all, and nothing in the UT stack does it. Once the guard patch is
  boot-tested, the remaining work is to establish the full route and then make
  it persistent — and to find out why PulseAudio's droid sink produces no ABOX
  activity at all, which is a separate question from the raw ALSA path.
* **Also fixed in the same build:** `Tfa9872.cnt`, the speaker amplifier's
  container file, was failing to load for exactly the same
  requested-before-any-filesystem reason (`tfa98xx_load_container()` is called
  once from probe, with no retry), so it is in the built-in firmware list too.

---

# Part 3 — audio works

**2026-09-05.** Sound comes out of the speaker, confirmed by ear, through
PulseAudio, and it survives a reboot with no manual steps.

## 13. The last piece: the vendor's own `media-speaker` path is wrong for us

Applying Samsung's `media-speaker` verbatim still gave `-EIO`, with a
completely clean kernel log — UAIF2 clocking at `bclk=1536000`, the amp
unmuting, `TFADSP_CMD_WRITE done`, no errors anywhere. The PCM status told the
real story:

```
state: RUNNING   delay: 8192   avail: 0   avail_max: 4096
tstamp: 0.000000000        <- the hardware pointer never advanced
```

The buffer filled and nothing drained it, so ALSA's `wait_for_avail()` timed
out and returned `-EIO` ("DMA or IRQ trouble"). Not a driver bug — the DSP
simply was not consuming.

**ABOX keeps its own firmware log at `/sys/kernel/debug/abox/log-00`**, and it
named the cause outright:

```
[PCMOUT:WARNING] ret(-110), param(7), NACK REPLIED: 20
[PCMOUT:WARNING] ret(-110), param(7), NACK REPLIED: 14
[SFR] RDMA7_CTRL0=0x00400000, RDMA7_STATUS=0x00000000, SPUS_ASRC7_CTRL=0x00000000
```

The DSP firmware **NACKs every PCMOUT command for channel 7**. `route-rdma7-to-sifs1`
is in `mixer_paths.xml`, but RDMA7 is not a channel this firmware will accept
from the AP — consistent with `mixer_paths.xml`'s own `<pcmdai>` table, which
maps the HAL's playback links to 0/1/2/3/5/15 and never mentions 7.

Channel 0 is accepted, and the vendor file already contains the path for it —
`route-sifs0-to-uaif2`. So the working chain is:

```
RDMA0 (hw:0,0) -> SPUS OUT0 -> SIFS0 -> UAIF2 -> TFA9872 speaker amp
```

with the DSP now reporting success instead of NACKs:

```
[PCMOUT:INFO] PCM open for task: 0, channel: 0
[PCMOUT:INFO] pcm_setbuffer: addr: 0x91000000, size: 48000, count: 2
[PCMOUT:INFO] pcm_trigger - ch: 0, on/off: 1
```

Two controls do it, and neither is set by anything in Ubuntu Touch:

| control | value |
|---|---|
| `ABOX SPUS OUT0` | `SIFS0` (already the default) |
| **`ABOX UAIF2 SPK`** | **`SIFS0`** — comes up `RESERVED` |
| `ABOX ERAP info DSM On` (numid 136) | `1` — the smart-amp reference the tfadsp IPC needs |

`ABOX ERAP info DSM On` has to be addressed **by numid**; `amixer cset name=...`
cannot match it. With it at 0 the first `tfadsp_write` times out and the driver
latches an "ipc timeout state" for the rest of the boot.

## 14. PulseAudio: the droid HAL never reaches the hardware

With raw ALSA working, PulseAudio still produced silence — and, tellingly,
**zero ABOX activity in dmesg** during playback. The droid HAL accepts writes
and returns success while nothing reaches the card. This is exactly the trap
`SESSION-HANDOFF.md` §8 warns about: "it returned 0" is not "it worked".

Fixed by driving the card directly with a native ALSA sink and making it the
default, while leaving the droid card loaded for the things that have no ALSA
equivalent here (voice call, mode switching):

```
load-module module-alsa-sink device=hw:0,0 sink_name=a50_speaker \
    sink_properties="device.description='Speaker'" rate=48000 channels=2 format=s16le
set-default-sink a50_speaker
```

This is a **stopgap for media playback, not a replacement for the HAL**. Why the
HAL swallows the audio is still open, and is now the interesting question,
because everything below it is proven working.

## 15. What is now in git

| file | purpose |
|---|---|
| `overlay/usr/local/bin/a50-audio-speaker-route.sh` | applies the ABOX route |
| `overlay/etc/systemd/system/a50-audio-route.service` | runs it every boot |
| `overlay/usr/local/bin/a50-dmesg-snap.sh` | early boot-log snapshots (§3) |
| `scripts/apply-device-workarounds.sh` | appends the ALSA sink to `touch.pa` |
| a50-halium `kernel/patches-experimental/abox-fixup-helper-dai-guard.patch` | the NULL-deref guard |

The kernel change itself is `CONFIG_EXTRA_FIRMWARE` plus the eight blobs; see
§5 and `docs/kernel.md`.

## 16. Verified after a clean reboot

| check | result |
|---|---|
| `a50-audio-route.service` | `active` |
| `ABOX UAIF2 SPK` | routed to `SIFS0` |
| `a50_speaker` sink | loaded, default |
| playback via PulseAudio | `RUNNING`, amp `profile = 0: music` |
| audible | **yes** |

## 17. Still open

* **The droid HAL path** (§14). Everything under it works, so this is now a
  userspace question, not a kernel one.
* **Headphones / earpiece.** Only the speaker (UAIF2) is routed. UAIF0 is the
  codec path and is untested.
* **Volume.** PulseAudio's software volume works; the amp's own gain and the
  `mixer_gains.xml` values are not applied.
* **The camera driver panics** on V4L2 enumeration (§10) — unrelated to audio
  but it looks like a bootloop when `gst-plugin-scan` runs.
