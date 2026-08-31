# Status

**Last updated: 2026-09-01.** Nothing in this repository has yet booted Ubuntu
Touch on the device. This file is the honest inventory.

## Proven

| Claim | How it was checked |
|---|---|
| a50-halium reproduces `074aad86…` from a clean checkout | Fresh `git clone`, fresh container, `sha256sum -c kernel/expected-artifacts.sha256` passes. The toolchain used for this port is therefore the right one. |
| UBports' `mkbootimg` (`LineageOS/android_system_tools_mkbootimg`, `lineage-20.0`) can pack this device's boot image | Repacked `halium-boot-canonical.img`'s own parts with the `deviceinfo` offsets: identical except the 20-byte `id` digest. [experiment 001](experiments/001-bootimg-header.md) |
| a50-droidian's overflowing offsets are genuinely rejected by that tool | `struct.error: 'I' format requires 0 <= number <= 4294967295` |
| `halium-boot-canonical.img` contains exactly the published artifacts | Its kernel hashes to `074aad86…` (a50-halium's pinned `Image`), its ramdisk to `0af4d23f…` (the canonical ramdisk) |
| The vendor base is Android 11, so Halium 11 | The kernel tree's `build.sh` exports `ANDROID_MAJOR_VERSION="r"` and `PLATFORM_VERSION="11.0.0"` |
| Every boot image header value in `deviceinfo` | Read out of an image that has booted this device |
| No SEAndroid footer, no AVB footer | Last 32 bytes of every known-good A50 boot image are zeros |
| The three artifacts the tools will download all exist | HTTP 200 on the 26.04 rootfs, the Halium 11 GSI and the halium-boot ramdisk, 2026-09-01 |

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

## Deliberately not started

* Bluetooth. `CONFIG_BT` + `CONFIG_BT_HCIVHCI` bootloop this device; the patch
  is parked in a50-halium's `kernel/patches-experimental/`. Not before the port
  boots.
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
