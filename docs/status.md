# Status

**Last updated: 2026-09-05.** Ubuntu Touch boots, reaches the UI, and now has
working audio, Bluetooth and mobile data. This file is the honest inventory.

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
| **Audio works** | Sound out of the speaker through Ubuntu Touch's normal path, with video unaffected — confirmed by ear across clean reboots. Two fixes: `CONFIG_EXTRA_FIRMWARE`, so the DSP gets `calliope_*.bin` at probe (t = 1.43 s, before any filesystem exists here), and presenting the real `hidl_compat` wrapper to PulseAudio host-side, which needed a linker-namespace change to resolve `libaudiohal.so`. The ABOX mixer is left entirely to the HAL. [experiment 007](experiments/007-abox-firmware-too-early.md) |
| **Bluetooth works** | `hci0` is `UP RUNNING` with the device's own BD address, and `bluetoothctl` discovers real nearby devices with live RSSI, and **earbuds pair and play audio over A2DP** — confirmed by the user. Needed `CONFIG_BT` + `CONFIG_BT_HCIVHCI`, restoring the HCI socket layer this vendor tree comments out, and `CONFIG_RFKILL`. The old "CONFIG_BT bootloops this device" result was a misdiagnosis — see [experiment 008](experiments/008-bluetooth-hci-sock.md). |
| **The signal strength indicator works** | Shows real bars while idle (15–20% at the test location), not only during calls. `ofono-binder-plugin` 1.1.28 maps dBm linearly between `signal_strength_dbm_weak`/`_strong` and returns a hardcoded `1` at or below the low end — and its defaults are **-100 / -60 dBm**, which suit RSSI, not the LTE **RSRP** this modem reports. Idle RSRP here is -107..-112 dBm, i.e. under the -100 floor, so it pinned to 1% and showed nothing; during a call it rose above -100 and worked. Fixed with `signalStrengthRange = -120,-75` in `binder.conf`. |
| **Mobile network works — SIM detected, registered on LTE** | `Present=true`, `ServiceProviderName="fraenk"`, `NetworkRegistration Status=registered`, `Technology=lte`, `ConnectionManager Attached=true`, on `/ril_0` of a dual-SIM device. Two config files: `OfonoPlugin: binder` in a device yaml that did not exist, and slot definitions in `binder.conf`. No kernel change. |
| **Wi-Fi works, including the UI** | Connects and lists networks. Note this happens with **no** `/dev/rfkill` and `urfkilld` inactive, which falsifies experiment 006's claim that the indicator needed `CONFIG_RFKILL`. RFKILL is built now, but for Bluetooth: `bluebinder` needs `/dev/rfkill`. `swlan0` is the interface that carries traffic. |

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
| **`conn_gadget` double-registration is avoided, not fixed** | The container is kept away from USB gadget configfs. The real fix is an idempotency guard in `conn_gadget_setup()`, still unwritten to the kernel branch. |
| **The `ld.config.txt` rewrite in the audio fix** | `a50-audio-hidl-compat.service` patches generated linker config on every boot so the HAL wrapper can resolve `libaudiohal.so`. `HYBRIS_USE_VENDOR_NAMESPACE` is supposed to make that unnecessary and demonstrably does not work here. Find out why and the hack can be deleted. [experiment 007](experiments/007-abox-firmware-too-early.md) §26 |
| **Headphones / earpiece** | Only the speaker path has been exercised. UAIF0 is the codec path and is untested. |
| **Camera** | `fimc_is_devicemgr_open` NULL-derefs when anything enumerates V4L2 (`gst-plugin-scan` does), panicking the kernel. Looks like a bootloop. Unrelated to audio. |

## Deliberately not started

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
