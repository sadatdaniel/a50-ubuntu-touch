# Current session handoff 22 — 17 October 2026

Start new work here. Handoffs 21 and older are history only. Verify live phone
and disk state before acting; nothing below is a substitute for checking.

## Goal

A conventional, stable Ubuntu Touch 26.04 port for the Samsung Galaxy A50
(SM-A505F, Halium 11), installed and updated the way UBports documents:
unified recovery, rootfs/system image on the system partition, signed
system-image OTA, an installer config. Samsung vendor stays intact. Every fix
needs a script, evidence, rollback and a pushed commit. The final full image
build runs on a remote Linux server (owner approves cost). Fingerprint is
last. `agent.md`/`first_contact.md` wait until the checklist is resolved.

## Where everything is (all on GitHub)

| What | Where |
|---|---|
| Port repo | `sadatdaniel/a50-ubuntu-touch` `main` |
| Kernel repo | `sadatdaniel/a50-halium` `main` (`9bb7c87`; aa18 source `8fda1ea`) |
| Build inputs: GSI 1542 and 1584, rootfs 2026-10-11, 18 locked packages, Waydroid fdclose.1 | release [`inputs-20261017`](https://github.com/sadatdaniel/a50-ubuntu-touch/releases/tag/inputs-20261017) |
| Every kernel build aa1–aa18 (aa17 = phone, aa18 unflashed) | a50-halium release [`kernel-builds-20261017`](https://github.com/sadatdaniel/a50-halium/releases/tag/kernel-builds-20261017) |
| Restore `dl/` on a fresh checkout | `bash scripts/release/fetch-release-inputs.sh` (tested from a clean container) |

Upstream artifacts expire: Jenkins keeps about 30 GSI builds, and CI
artifacts last 7–90 days. Archive any new input into a release before relying
on it.

## Phone state (17 October; superseded by the layout section below)

Runtime-firmware candidate 2 (`#1`, boot 18 October), aa17 fallback staged in `/userdata/a50-kernel-test`. aa17 is `#6`, aa18 `#7`. Root
RO, AppArmor Y, zero failed units. Access over USB ADB as phablet; root needs
the owner's sudo password, so arm a script under `/home/phablet` and ask the
owner to run `adb shell -t sudo sh /home/phablet/<script>.sh`. Running now
on the phone:

- Waydroid `…+a50singleinstance.2+fdclose.1` ([062](experiments/062-waydroid-fd-leak.md)):
  fixes the daemon fd leak (upstream waydroid#2357). Soak pending; then move
  the lock from `.2`.
- Camera-provider overlay `.rc` ([061](experiments/061-waydroid-camera-overlay.md)):
  zero provider starts. The removed 013 helper is still installed on this
  phone until the next image.

## Verified this cycle

- The fresh-rootfs gate passes: all 18 locked packages install through the
  builder's own APT step into official rootfs `809e340e`
  ([060](experiments/060-upstream-input-retention.md)). This needed a fix,
  since `--no-download` made every real install fail.
- 6-day log check: no service restarts, core dumps or OOM.
- Waydroid package builds are byte-identical across CI runs (pinned changelog date).

## Layout and OTA status (19 Oct, latest)

The phone runs the **system-partition layout** installed by UBports'
`system-image-upgrader`: two local OTAs, with user data retained
([064](experiments/064-unified-recovery.md), [065](experiments/065-system-partition-ota.md)).
The boot kernel is rf2 + `--systempart` (`dc71ee9c…`), recovery is unified
`b2c75255…` (normal, signature check on), the cohort has 20 packages
(camera Lomiri.Action added), and the GSI is 1585. Pipeline:
`build-ota-rootfs.sh` → `build-device-tarball.sh --recovery` →
`prepare-local-ota.sh` (`FORMAT=1`); test recovery via
`build-unified-recovery.py --test-upgrader`, never shipped. Remaining for
release: real signatures and a hosted channel, the installer config, the
console-setup unit and expanded-panel layout checks. Rollback:
`/userdata/a50-ota-test/ubuntu.img.bak` + rf2 boot.


## Open, in order

**Route decided 19 Oct: official UBports community port** — see
[official-port-plan](official-port-plan.md) for gates and the cohort→upstream table.

1. **Waydroid fd fix is now in the lock (19 Oct)**; the system-partition reinstall
   had reverted the phone to `.2`, so the next OTA restores `fdclose.1`. Earlier note,
   **Waydroid soak**: re-check `grep -c "Too many open files"
   /var/lib/waydroid/waydroid.log` (4 historical) after days of uptime; then
   update `validated-packages.lock`, the fresh-rootfs test and the release.
2. **Camera/video GSI — PR 84 MERGED 17 Oct** (NotKit reworked it:
   `get_audio_flinger()` always returns null; hybris-patches `7d83d27b`).
   Jenkins build **1585** (18 Oct) is the first with it: tarball `d08a92e4…`
   (archived in `inputs-20261017`, sources in `scripts/experiments/gsi1585-used-repos.txt`).
   Its 32/64-bit `libaudioclient.so` changed, and the wait loop's string is gone.
   **Done 19 Oct: installed on the phone and `gsi.lock` pinned to 1585**; owner
   confirms camera record/Stop/playback, sound and lock screen
   ([063](experiments/063-gsi-1585-camera.md)). Remaining: repeat recordings,
   calls, Bluetooth audio and sleep on 1585.
   **No custom GSI build is needed any more.** Done steps: swap the phone's Android
   image 1542 → 1585 reversibly (`scripts/experiments/swap-gsi-image.sh`;
   android-rootfs.img `da6c3373…`, 473,751,552 bytes), test boot, camera
   record/Stop/playback, audio and calls, then move `gsi.lock` to 1585.
   Old text: (Halium PR 84, open upstream): either upstream merges
   it and `gsi.lock` moves to a Jenkins build, or the remote server builds it.
   Sources are re-pinned to Jenkins build 1584
   (`scripts/experiments/gsi1584-*`, 44 projects newer than 1542, incl. the
   frameworks/av security fixes); `recording-library-test.yml` input
   `gsi_sources` selects it, and PR 84 blob guards still apply. Library-only CI
   run 39032463776 **passed**: PR 84 builds against the 1584 sources. The remote full build then runs that
   workflow with `full_image=true` on a ≥250 GiB runner and feeds
   `build-rootfs-image.sh --gsi-tar … --gsi-sha256 …`.
   The owner may post `dl/pr84-comment.md` upstream.
3. **Conventional layout and OTA** (UBports finalize docs, see
   [ota-finalization](ota-finalization.md)): unified recovery
   (`deviceinfo_use_unified_recovery`), rootfs/GSI on the system partition,
   local OTA via `system-image-upgrader` (bypass removed after), two signed
   updates retaining userdata, channel/hosting with UBports, installer config
   in `ubports/installer-configs` (Heimdall/Samsung transport). OTA is
   disabled today.
   **Firmware blocker mostly resolved (18 Oct):** a50-halium
   `build-kernel.sh --runtime-firmware` builds aa17 with *no* Samsung blobs.
   ABOX and TFA9872 retry loading from `/vendor/firmware`
   ([runtime-firmware](https://github.com/sadatdaniel/a50-halium/blob/main/docs/runtime-firmware.md)).
   Public CI builds it reproducibly. On the phone (`boot-aa17rf2.img`
   `7d5855ef…`, currently installed) speaker audio and 15 deep sleeps pass.
   Calls, Bluetooth audio, cold-boot repeats and an overnight soak remain; then it
   can replace aa17 and unblock the conventional `build.sh` path below.
   Rollback: `/userdata/a50-kernel-test/flash-boot-image.sh` with the aa17 image.
   **Conventional kernel, next steps (18 Oct):** the exact tested source is
   now branch `halium-a50-aa17rf2` (`4f37ef39`) of the kernel fork, produced by
   the fork's `halium-a50-tools` workflow. It rebuilt the tested Image
   byte-identically; `arch/arm64/configs/halium_a50_defconfig` there is the full
   build `.config`. `build.sh` now pins the tools at `7dd99e0d`. The tools
   only accept Google prebuilt clang, and experiment 004 saw a tools-built
   (clang-r383902 ThinLTO) kernel hang at the Samsung logo, never bisected.
   Follow docs/kernel.md, one variable per boot test:
   (a) bare `make halium_a50_defconfig` with Proton clang; diff `.config` (needs
   the old branch's ANDROID_MAJOR_VERSION Kconfig commit `d159cfba` and
   `console=tty0` `bab51ce8`);
   (b) boot that kernel;
   (c) only then the tools' clang, picking the LLVM=1 build fixes from old
   `ubuntu-touch-26.04` (`57ba2d49`…`d25a56a6`);
   (d) point `deviceinfo_kernel_source_branch` at the result.
   Every flash needs the owner present, with aa17 or rf2 fallback staged.
   **Progress 18 Oct:** (a) passed (`halium-a50-ut`: bare make = tested
   config). `halium-a50-ut-llvm` + `deviceinfo` (clang `android12L-gsi`
   r416183b, `llvm_compile=true`) now build with the pinned conventional
   `build.sh` in `conventional-build.yml` (run 39166485573). Two fixes were
   needed: LLVM=1 instead of GCC 4.9 GNU as, and weak `mem*` aliases for clang's
   integrated assembler. Its kernel config is aa17's minus blobs and Polly.
   Single-variable boot test staged: conventional kernel + aa17 ramdisk
   `boot-aa17conv.img` `7476403a…` (archived); current boot is rf2 `7d5855ef…`.
   **Result 19 Oct: hangs at the Samsung logo**, like experiment 004 (clang 11).
   S-Boot's `last_kmsg` ends at `Starting kernel...` with no kernel line, so
   it dies before the first printk reaches ramoops. Restored rf2 from TWRP with
   `flash-boot-image.sh` (guards passed); healthy. Config is identical, so the
   cause is the Google clang/lld build (12 here, 11 before), not
   configuration. Next single variables, each one boot test: (1) same clang
   without LTO (`CONFIG_LTO_CLANG`/`THINLTO` off via an extra defconfig fragment
   on a test branch); (2) clang r450784e (14); (3) `CONFIG_RELR` off. Evidence is
   in local gitignored `dl/conv-hang-20261019/`.
   **(1) done, 19 Oct: no-LTO also hangs** at the same point (`boot-aa17nolto.img`
   `059c06a5…`, branch `halium-a50-ut-llvm-nolto`, CI 39210295111; config =
   tested minus LTO and its automatic `RANDOMIZE_MODULE_REGION_FULL`). LTO is
   ruled out; rf2 restored from TWRP. Remaining difference from the booting
   Proton build: Google clang/lld and the **integrated assembler** (the Proton
   build assembles `.S` with GNU as; the tools force `LLVM_IAS=1`). An early-asm
   (head.S/KASLR/RELR) miscompile fits "dies before the first printk". Next:
   isolate the assembler with a Proton clang 13 + integrated-assembler build in
   a50-halium CI, then clang r450784e or `CONFIG_RELR` off.
   **Assembler ruled out, 19 Oct:** a50-halium `--llvm-ias` (Proton clang 13 +
   integrated assembler + weak mem* fix, CI 39220818286, symbols identical to
   rf2) **boots** (boot `7b5ac1c0…`, owner-verified hash). Remaining suspects: the
   Google clang/lld version (11 and 12 both hang) or the old branch's LLVM=1
   commits (`thread_info.h`, Makefile, tzdev, firmware asm include). Next single
   variable: Proton build of `halium-a50-ut-llvm`'s extra commits, then
   clang r450784e.
   **LLVM commits ruled out, 19 Oct:** a50-halium `--llvm-build-fixes`
   (Proton 13 + those commits + systempart, CI 39249357299, symbols identical)
   boots (boot `b329a4d8…`, owner-verified); it is currently installed. The hang
   is therefore Google's clang/lld itself (r383902 and r416183b). Next: tools
   build with `android12L`→`r450784e` (clang 14) or another supported revision.
   Earlier note: `build.sh` clones the moving
   `halium-generic-adaptation-build-tools` (head `7dd99e0d` on 17 Oct) and builds
   `deviceinfo_kernel_source` branch `ubuntu-touch-26.04` (last change
   1 Sep), not aa17. aa17 is FreshROMs at `kernel/source.lock` plus the
   a50-halium patch series, built with `--profile full --firmware DIR`. That
   needs 8 proprietary Samsung blobs built in (ABOX needs them before any
   filesystem exists), which public CI cannot have. Owner decision: either
   redistribute the blobs in a kernel branch/tag so `build.sh`/CI reproduce
   aa17, or build only on the private remote server (extract them from the
   phone with a50-halium `build/extract-vendor-firmware.sh`). Then pin the
   tools commit in `build.sh`, set `deviceinfo_kernel_source_branch` to an aa17
   tag, and enable `deviceinfo_use_unified_recovery="true"`,
   `deviceinfo_has_recovery_partition="true"` and
   `deviceinfo_unified_recovery_ui_density="xxhdpi"`. Recovery flashing needs
   the owner present, with the TWRP backup verified first.
4. Clean install from the built candidate, then the backlog checks
   ([release-validation-backlog](release-validation-backlog.md)).
5. Debt: four package scripts still use unpinned `dch` dates; legacy
   OpenStore libxml2/ICU extraction; the conventional `build.sh` kernel path
   differs from tested aa17.

## Host notes

C: is nearly full (about 9 GB free on 17 October; another project is
writing). Docker's data VHD is about 35 GB; it shrinks only via the
owner-approved stopped-Docker DiskPart compaction (see 059). Do not touch
other projects' containers, volumes or the `oci-a1-retry` job. Preserve
`a50-halium/out-aa*` (also archived in the release above).
