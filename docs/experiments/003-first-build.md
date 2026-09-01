# Experiment 003 — the first end-to-end build with the UBports tools

**Date:** 2026-09-01 · **Status:** ✅ green build · **Device needed:** no (boot test pending)

## Question

Can `halium-generic-adaptation-build-tools` build this port end to end —
kernel with a bare `make`, boot image with its own `mkbootimg` — from nothing
but the published `deviceinfo` repo and the kernel branch? (Plan step 3.)

## Result

**Yes.** `./build.sh -k -b workdir` in the documented build environment
([`build-environment.md`](../build-environment.md)) produced:

| Artifact | Value |
|---|---|
| `boot.img` | 46,995,456 bytes — fits the 57,671,680-byte boot partition with 10.7 MB spare |
| kernel `Image` | 41,586,688 bytes, sha256 `62db7440…` |
| `boot.img` sha256 | `beb55619…` (not expected to be stable across rebuilds — see notes) |

The boot image header was unpacked and compared field-by-field against
`halium-boot-canonical.img` (an image that has booted this device):

* **Identical:** kernel_addr `0x10008000`, ramdisk/second addr `0x0`, tags
  `0x10000100`, page 2048, header_version 1, board `SRPRL05B007KU`,
  os_version bits `0x18000169`, the full command line, and all-zero last 32
  bytes (no SEAndroid/AVB footer).
* **Different, both expected:** kernel and ramdisk sizes (different compiler,
  and the upstream halium-boot ramdisk instead of Droidian's), and the 20-byte
  `id` SHA-1 digest — the one field [experiment 001](001-bootimg-header.md)
  could not reproduce; only a boot test answers whether S-Boot reads it.

## What it took: the hermetic-LLVM fix series

The tools build kernels as `make LLVM=1 LLVM_IAS=1` in a hermetic PATH with
Google's `clang-r383902` (android11-gsi). This tree had never been built that
way — mint builds it in-tree with Proton Clang and GNU `as`/`ld` on PATH.
Nine commits on the `ubuntu-touch-26.04` kernel branch close the gap
(`57ba2d496..9f697edbd`, each with the evidence in its commit message):

1. `032eef522` — kbuild: link host programs with lld (4.14 never passes
   HOSTLDFLAGS to the host-csingle rule; hermetic PATH has no `ld`).
2. `27574ba33` — Makefile: define `LDLLD`/`LLVMNM`/`LLVMOBJCOPY` in the
   LLVM=1 branch (else `CONFIG_LD_LLD=y` and `CONFIG_RELR=y` permanently
   empty `LD`/`OBJCOPY`/`NM` via late `:=` assignments), and warnings
   non-fatal for clang, replicating mint build.sh's load-bearing
   `KCFLAGS=-Wno-error`.
3. `6f40d625b` — defconfig: drop `CONFIG_LLVM_POLLY` (Google's clang ships
   no Polly; every `-mllvm -polly*` is a hard unknown-argument error).
4. `9d42aa535` — vdso32: integrated assembler + `-fuse-ld=lld` under
   LLVM_IAS (the compat vDSO forced `-no-integrated-as` and an arm32 GNU
   toolchain that the hermetic PATH cannot resolve).
5. `1a87b7b07` — tzdev: resolve the TrustZone `.incbin` blobs in O= and
   ThinLTO builds (`-I$(srctree)` at compile time; copies in the object tree
   at link time, because ThinLTO re-assembles inline asm with the linker's
   cwd — its failure mode was misreported as a plain segfault).
6. `af42a48d6` — firmware: same `-I$(srctree)` for the generated `.gen.S`
   incbins.
7. `e9e60317f` — thread_info: never emit `__bad_copy_from`/`__bad_copy_to`
   calls (compile-time-only sentinels; clang under ThinLTO can actually emit
   them, seen from `snd_ctl_ioctl_compat`).
8. `a9ecc9b15` — setlocalversion: drop the unconditional separator space
   (with no LOCALVERSION it produced `kernel.release = "4.14.194 "`, whose
   trailing space split `$(MODLIB)/source` into two words and broke
   `modules_install`; invisible to mint because the recovery variant never
   installs modules).
9. `9f697edbd` — tfa9872: keep that Makefile's local `-Werror` survivable
   under clang (`-Wno-error=ignored-optimization-argument`).

Plus one deviceinfo decision: `deviceinfo_kernel_llvm_compile="true"` — the
config's `CONFIG_LTO_CLANG=y`+`CONFIG_THINLTO=y` require `ld.lld` and the
LLVM binutils; `clang_compile` alone leaves GNU ld 4.9 as the linker.

## Assumptions corrected along the way

* "The build failed with a segfault" — actually an inline-asm `.incbin`
  parse error inside ThinLTO codegen, aborting after the crash banner.
* "clang-11 accepts the LTO flags" — only after `-Werror` stopped turning a
  redundant `-march/-mcpu` pair fatal; the *next* error (Polly) was hiding
  behind it.
* toybox `ln`'s error message names the arguments reversed from GNU ln;
  the real bug was the trailing space in KERNELRELEASE, not the linker.

## Config deltas vs the boot-verified kernel (for the boot test's ledger)

`console=tty0` in CONFIG_CMDLINE (intended, plan step 2) · `CONFIG_LLVM_POLLY`
off · compiler Google clang-r383902 instead of Proton Clang 210521 · same
defconfig otherwise, byte-compared before the POLLY line was dropped.

## What is still open

* The **boot test** (plan step 4) — flash `beb55619…` from TWRP with a
  known-good image staged as the way back. It answers, in one flash: does the
  tools-built kernel boot, and does S-Boot accept the `id` digest.
* Full build (`-b` without `-k`) — rootfs + system-image + device tarball,
  needed before the first real installation but not before the first kernel
  boot test.
* The from-scratch reproducibility rebuild (fresh workdir, published commits
  only) — running as this was written; its result belongs in this file.
