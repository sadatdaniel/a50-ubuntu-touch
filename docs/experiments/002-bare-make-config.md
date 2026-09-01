# Experiment 002 — can a standalone defconfig reproduce the boot-verified kernel config?

**Date:** 2026-09-01 · **Status:** ✅ answered · **Device needed:** no

## Question

[`kernel.md`](../kernel.md) risk 1: the UBports tools build kernels with a bare
`make <defconfig>`, while a50-halium's boot-verified kernel (`Image`
`074aad86…`) is produced by the vendor tree's own `build.sh`, whose documented
extras were `KCONFIG_BUILTINCONFIG`, `ANDROID_MAJOR_VERSION`,
`PLATFORM_VERSION` and the toolchain's `LD_LIBRARY_PATH`. If those extras
cannot be carried by a defconfig, the tools can never build this kernel.

Can a `savedefconfig` of the boot-verified `.config`, expanded again with a
bare `make`, reproduce that `.config` byte-for-byte? And if not, what exactly
is missing?

## Method

No device. Ground truth: the `.config` of the verified `074aad86…` build
(md5 `6659133222243b7426fa2b01187d3c14`), pulled out of the build container
right after that build. The in-tree copy inside the experiment workspace was
verified byte-identical to it before anything else ran.

Workspace: a dedicated container (`a50-kernel-shell`, `sleep infinity`) — not
`a50-verify-clean`, whose entrypoint re-runs the whole build pipeline and
races interactive work (that race produced the **792-line** defconfig from the
previous session, now treated as suspect and superseded). Inside it:

* fresh `git clone` of the kernel tree at the pinned commit `bec0c2af…`
* the four a50-halium patches applied (they touch only `build.sh` and the
  ramdisk fstab — no Kconfig sources, so config semantics are untouched)
* `KernelSU` materialized and `drivers/kernelsu` symlinked to
  `../KernelSU/kernel`, as `build.sh` does — without it, Kconfig cannot parse
  the tree at all (`drivers/kernelsu/Kconfig` missing)

Then:

1. `make ARCH=arm64 savedefconfig` with `build.sh`'s own environment
   (Proton Clang as CC *and* HOSTCC, `CROSS_COMPILE`, `ANDROID_MAJOR_VERSION=r`,
   `PLATFORM_VERSION=11.0.0`) → **793 lines**, committed as
   [`002-halium_a50_defconfig.txt`](002-halium_a50_defconfig.txt).
2. **Expansion A** — `make O=… halium_a50_defconfig`, same environment, but
   *no* `KCONFIG_BUILTINCONFIG` and *no* tmp-defconfig pipeline. Diff against
   ground truth.
3. **Expansion B** — same command, bare environment: host gcc, no toolchain,
   no Android env vars. Diff.
4. **Expansion C** — B plus the three missing symbols appended as explicit
   `=y` lines to a test defconfig. Diff.
5. **Full replication** — reconstruct `build.sh`'s config step exactly from
   its own parts and diff against ground truth. This was done last, after A
   exposed an anomaly (see corrections below).

## Results

**A — the defconfig stands on its own.**

```
diff <expansion-A .config> <boot-verified .config>   →   IDENTICAL
```

A bare single `make halium_a50_defconfig` — exactly the shape the UBports
`build-kernel.sh` uses (`make O= $MAKEOPTS $defconfig`) — reproduces the
boot-verified config **byte-for-byte**.

**B — bare environment: exactly three symbols drop.**

```
CONFIG_HALL_EVENT_REVERSE=y        drivers/input/misc/Kconfig:884  (>= "q")
CONFIG_HALL_NEW_NODE=y             drivers/input/misc/Kconfig:905  (>= "r")
CONFIG_USB_F_CONN_GADGET_NDOP=y    drivers/usb/gadget/Kconfig:480  (>= "q")
```

All three are `default y` with `depends on ANDROID_MAJOR_VERSION …`, and
`ANDROID_MAJOR_VERSION` is itself a Kconfig symbol fed by
`option env="ANDROID_MAJOR_VERSION"` (top-level `Kconfig:16`). Without the
environment variable the symbols are invisible and absent from `.config`;
with it (`=r`) they default on, which is what the boot-verified config has.

Note also: expansion B used **host gcc**, not Proton Clang, and still
reproduced everything else — this 4.14 Kconfig has no compiler-detection
symbols, so the config round-trip is compiler-independent. The compiler
question (risk 3) is real for the *binary* but does not touch the *config*.

**C — a defconfig cannot carry them.** Appending the three `=y` lines to the
defconfig and expanding bare: all three dropped, one with

```
warning: override: reassigning to symbol USB_F_CONN_GADGET_NDOP
```

An invisible symbol's `.config` line is discarded. No defconfig content can
fix this; the environment or the Kconfig source has to.

**Full replication — the original recipe, reconstructed and byte-identical.**

```
diff <core + 4 fragments + patch-0002 block, expanded> <boot-verified>   →   IDENTICAL
```

The tmp defconfig `build.sh` actually feeds Kconfig is:

```
arch/arm64/configs/exynos9610-a50_core_defconfig
  + kernel/configs/mint_partial-deknox-11.config
  + kernel/configs/mint_mali-11.config
  + kernel/configs/mint_variant_recovery.config
  + kernel/configs/mint_root-none.config
  + patch 0002's appended block (SYSVIPC, FHANDLE, cgroups, namespaces, VT,
    the lxc-net netfilter set, CONFIG_CMDLINE, FIVE/PROCA/DEFEX off)
```

expanded with `ARCH=arm64`, `ANDROID_MAJOR_VERSION=r`, clang.

## Corrections this experiment forced (rule 1: verify, never assume)

Two mechanism claims in `device-facts.md` were wrong, both found because
expansion A reproduced the config while the documented mechanism said it
should not have:

1. **`KCONFIG_BUILTINCONFIG` is dead.** `build.sh` exports it, but this
   tree's `scripts/kconfig/conf.c` is stock mainline and reads
   `KCONFIG_ALLCONFIG` — `KCONFIG_BUILTINCONFIG` appears nowhere in kconfig.
   The "second baseline defconfig merged through the environment" never
   happens. The real second baseline is the `merge_config` fragments above.
2. **`SET_ANDROIDVERSION`'s append never reaches Kconfig.** It appends
   `CONFIG_MINT_PLATFORM_VERSION=$BUILD_ANDROID_PLATFORM` to the tmp
   defconfig — but runs *before* `VERIFY_DEFCONFIG`, which does
   `cat core > tmp` and overwrites it. The boot-verified config's
   `CONFIG_MINT_PLATFORM_VERSION=9` is not an appended 11: it is the
   `range 9 13` clamp of an int symbol with no user value and no default.

Both corrections are **proposed, not applied**: under this project's current
working convention the agent does not edit files it did not create. Edited
copies of `a50-halium/device/samsung-a50/device-facts.md` (and of this repo's
`status.md`, `kernel.md`, `plan.md`) live in the agent workspace's
`a50-port-proposed-edits/` folder, each noted in its `CHANGES.md`, for a human
to apply. The outcome-level claim ("a bare `make` of a checked-in defconfig
does not boot this device") stands — the checked-in defconfigs are not the
recipe above — but the mechanism is the fragment list, not the environment
variable.

## Conclusion

Risk 1's **config half is settled on paper**, with one exact residue:

* A standalone defconfig exists and works —
  [`002-halium_a50_defconfig.txt`](002-halium_a50_defconfig.txt), 793 lines —
  provided `ANDROID_MAJOR_VERSION` is in the environment.
* The UBports tools do **not** set `ANDROID_MAJOR_VERSION`
  (verified against `halium-generic-adaptation-build-tools/build-kernel.sh`
  at `d5838d5`), so three symbols would silently drop.

**Fix for plan step 2** (kernel branch): one small patch removing the
`depends on ANDROID_MAJOR_VERSION …` line from those three symbols. They are
`default y` and the boot-verified config wants them `y`; with the dependency
gone they default on in any environment, the defconfig stays minimal, and no
environment has to be arranged. The 793-line defconfig goes in as
`arch/arm64/configs/halium_a50_defconfig` in the same commit series.

## What is still open

* The boot test itself (plan steps 3–4). Byte-equal `.config` proves the
  config half; `ANDROID_MAJOR_VERSION` also reaches Makefiles outside Kconfig
  (`drivers/input/misc/Makefile` and friends), which affects *build* flags,
  not `.config` — the boot test is what closes that.
* The compiler (risk 3) remains a separate variable for the boot test, by
  design.
* The `id`-digest question from [experiment 001](001-bootimg-header.md)
  is untouched by this experiment.

## Reproducibility note

The workspace lives in container `a50-kernel-shell:/root/exp002` and the raw
artifacts (defconfig, diffs, both `.config`s) in the session scratchpad under
`exp002/` — the scratchpad is session-local, which is why the defconfig is
committed here as the durable artifact. Rerunning takes: a clone at the pin,
the four patches, KernelSU + the `drivers/kernelsu` symlink, then the five
steps above.
