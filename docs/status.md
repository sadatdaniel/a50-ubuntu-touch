# Status

**Last updated: 2026-09-03.** Ubuntu Touch now boots on the device and reaches
the first-boot wizard. This file is the honest inventory.

## Proven

| Claim | How it was checked |
|---|---|
| **Ubuntu Touch boots to its UI on this device** | Wizard (language selection) renders; Mir drives the panel at 1080x2340; container `sys.boot_completed=1`; lightdm `NRestarts=0`; verified across a clean reboot. [experiment 006](experiments/006-what-we-missed.md) |
| The display blocker was misc-list corruption, not CMA and not the mutex design | Unguarded double `misc_register()` on a static `miscdevice` in `f_conn_gadget.c` makes `misc_list` circular; `MISCDBG` instrumentation caught `GOTLOCK` with no release. CMA falsified directly: 50 MB freed via `drop_caches`, `mali0` still hung. [experiment 006](experiments/006-what-we-missed.md) |
| The greeter needed `/dev/hwbinder` at `0666` | Compositor (root) worked while greeter (uid 108) failed with `gralloc-mapper is missing`; fixed by `overlay/usr/lib/udev/rules.d/99-a50-binder.rules` |
| a50-halium reproduces `074aad86…` from a clean checkout | Fresh `git clone`, fresh container, `sha256sum -c kernel/expected-artifacts.sha256` passes. The toolchain used for this port is therefore the right one. |
| UBports' `mkbootimg` (`LineageOS/android_system_tools_mkbootimg`, `lineage-20.0`) can pack this device's boot image | Repacked `halium-boot-canonical.img`'s own parts with the `deviceinfo` offsets: identical except the 20-byte `id` digest. [experiment 001](experiments/001-bootimg-header.md) |
| a50-droidian's overflowing offsets are genuinely rejected by that tool | `struct.error: 'I' format requires 0 <= number <= 4294967295` |
| `halium-boot-canonical.img` contains exactly the published artifacts | Its kernel hashes to `074aad86…` (a50-halium's pinned `Image`), its ramdisk to `0af4d23f…` (the canonical ramdisk) |
| The vendor base is Android 11, so Halium 11 | The kernel tree's `build.sh` exports `ANDROID_MAJOR_VERSION="r"` and `PLATFORM_VERSION="11.0.0"` |
| Every boot image header value in `deviceinfo` | Read out of an image that has booted this device |
| No SEAndroid footer, no AVB footer | Last 32 bytes of every known-good A50 boot image are zeros |
| The three artifacts the tools will download all exist | HTTP 200 on the 26.04 rootfs, the Halium 11 GSI and the halium-boot ramdisk, 2026-09-01 |
| **The audio DSP boots and the speaker amplifier works** | `calliope_version` reads `rSK1`, `Invalid calliope state: 0` is gone, and `speaker-test -D hw:0,0` is **audible** — confirmed by ear. Two fixes: `CONFIG_EXTRA_FIRMWARE`, so the DSP gets `calliope_*.bin` at probe (t = 1.43 s, before any filesystem exists here), and the `ABOX UAIF2 SPK` route, which nothing in Ubuntu Touch sets. [experiment 007](experiments/007-abox-firmware-too-early.md) |

## Not proven, and blocking

| Open | Why it matters |
|---|---|
| **A bare `make <defconfig>` kernel does not boot this device** | It is how the tools build kernels. [`kernel.md`](kernel.md) risk 1 — the largest single risk in the port. |
| **`console=tty0` cannot be delivered via `deviceinfo_kernel_cmdline`** | S-Boot ignores the boot image command line. [`kernel.md`](kernel.md) risk 2. |
| **The tools use Google's prebuilt Clang, not the pinned Proton Clang** | A second changed variable sitting under risk 1. [`kernel.md`](kernel.md) risk 3. |
| **The kernel branch `ubuntu-touch-26.04` does not exist yet** | `deviceinfo_kernel_source_branch` points at it. Marked `[?]`. |
| **Does S-Boot check the boot header `id` digest?** | The one field experiment 001 could not reproduce. One boot test. |
| **AppArmor** | Untouched. Ubuntu Touch needs it to run apps. |
| **The initramfs fixes have not been ported** | Four are expected to be needed. `ramdisk-overlay/README.md`. |
| **Wi-Fi has no UI: `CONFIG_RFKILL` is not built** | Every layer below the UI works — `wlan0` up, `wpa_supplicant` running, NetworkManager scans and lists APs. But with no `/dev/rfkill`, `urfkilld` enumerates nothing and reports WLAN killswitch `state = -1` (no adapter), so the indicator shows no Wi-Fi. One rebuild. [experiment 006](experiments/006-what-we-missed.md) |
| **`conn_gadget` double-registration is avoided, not fixed** | The container is kept away from USB gadget configfs. The real fix is an idempotency guard in `conn_gadget_setup()`, still unwritten to the kernel branch. |
| **Audio through PulseAudio / the droid HAL** | The HAL accepts writes and returns success while nothing reaches the card, and no PulseAudio playback has ever been confirmed audible. Everything below it is proven working, so this is a userspace question. **Do not "fix" it with a raw ALSA sink** — that takes `hw:0,0` from the media stack and stops video playing at all. [experiment 007](experiments/007-abox-firmware-too-early.md) §14, §18 |
| **Headphones / earpiece** | Only the speaker (UAIF2) is routed. UAIF0 is the codec path and is untested. |
| **Camera** | `fimc_is_devicemgr_open` NULL-derefs when anything enumerates V4L2 (`gst-plugin-scan` does), panicking the kernel. Looks like a bootloop. Unrelated to audio. |

## Deliberately not started

* Bluetooth. `CONFIG_BT` + `CONFIG_BT_HCIVHCI` bootlooped this device on
  2026-08-31; the patch is parked in a50-halium's
  `kernel/patches-experimental/`. The Android half is confirmed alive under
  Ubuntu Touch too — `/dev/scsc_h4_0` present,
  `android.hardware.bluetooth@1.0-service` running, and `bluebinder`
  auto-restarting on `ENODEV` waiting for a `/dev/vhci` that does not exist.
  Worth a fresh test now: that bootloop predates experiment 006, its own README
  named an Android-init fatal error as the leading hypothesis, and `hci_vhci.c`
  registers `/dev/vhci` via `misc_register()` — adding a node to the very list
  that was being corrupted. One variable at a time: land `CONFIG_RFKILL` first.
* UBports recovery and the UBports installer. The guide adds both at
  finalization, and TWRP is currently the only reliable way back.

## A standing hazard, not a task

Getting from running Linux back to TWRP is **unreliable on this device**:
`systemctl reboot --reboot-argument=recovery` sometimes works and sometimes
reboots straight back into Linux (three successes then four failures in one
session). The AOSP bootloader control block is ignored by S-Boot — tested — and
glibc's `reboot()` cannot pass `recovery` at all.

Never end a session with the device bootlooping, and keep a known-good boot
image within reach before every flash. Published with hashes in a50-droidian,
release `boot-images-2026-09-01`.
