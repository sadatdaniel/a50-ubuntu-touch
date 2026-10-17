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

## Phone state (17 October)

aa17 (`/proc/version` `#6`; aa18 is `#7`), boot of 10 October 17:17. Root
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

## Open, in order

1. **Waydroid soak**: re-check `grep -c "Too many open files"
   /var/lib/waydroid/waydroid.log` (4 historical) after days of uptime; then
   update `validated-packages.lock`, the fresh-rootfs test and the release.
2. **Camera/video GSI** (Halium PR 84, open upstream): either upstream merges
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
   **Kernel blocker for the conventional build:** `build.sh` clones the moving
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
