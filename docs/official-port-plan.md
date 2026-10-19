# Official UBports community-port route

Decided 19 October 2026 (owner). UBports, not us, hosts the A50: GitLab CI in
`ubports/porting/community-ports`, the system-image OTA server, image signing,
downloads, the UBports Installer config and the devices website. No paid
hosting or our own signing keys. Their pipeline builds **the official rootfs
plus our device tarball**, with the kernel built by the standard `build.sh`
(`gsi-port-ci.yml`). Therefore every A50 fix must be upstream or in the device
tarball. The locked package cohort is a bridge, not a release mechanism.

## Gates

1. **Kernel builds and boots with the tools' Google clang** (`build.sh`).
   Status 19 Oct: config identical (branch `halium-a50-ut-llvm`); the tools'
   build compiles but hangs before the first printk with clang 11 and 12. The
   integrated assembler, LTO and the LLVM build-fix commits are ruled out
   (handoff 22). Testing clang 14 (`r450784e`).
2. **Cohort reduced to zero** (table below).
3. **Device repo in community-ports layout**: `.gitlab-ci.yml` including
   `gsi-port-ci.yml`, `deviceinfo`, `overlay/`, `ramdisk-recovery-overlay/`.
   The repo already has these; the CI include and the tools pin remain.
4. **Unified recovery from the tools** (`deviceinfo_use_unified_recovery`, set);
   depends on gate 1, because recovery.img carries the tools' kernel.
5. **Installer config** draft (`installer/a50.yml`, modelled on the official
   Samsung `herolte.yml`: heimdall BOOT+RECOVERY, recovery, `systemimage:install`).
6. **Contact the UBports porting team** (owner) to add `a50` to the
   system-image server and CI; then PRs to `ubports/installer-configs` and the
   devices website.

## Cohort → upstream

| Package(s) | Why we carry it | Route out |
|---|---|---|
| lomiri, -common, -greeter, -private `+a50state.4` | Restart/Recents/reopen window-state fixes (exps 053–055) | Upstream Lomiri: MR 330 merged; MR 331 (mariogrip, window state) open. Rebase on upstream, submit the remainder |
| lomiri-system-settings + 2 libs `+a50qtquick.1` | QtQuick validator / lock-security regression (exp 039) | Submit MR to lomiri-system-settings |
| tar `+a50openat2.1` | 26.04 tar fails on kernel 4.14 without openat2 (no ENOSYS fallback) | Ubuntu bug report against tar (affects all 4.x Halium ports) |
| waydroid `+single-instance.2+fdclose.1` | Lomiri single-instance launcher; fd leak (waydroid#2357) | UBports waydroid packaging MR; upstream PR on waydroid#2357 |
| qtmir ×3 pinned to `ac3ee9` (.83) | Validated version; rootfs has .84 (Mir→miroil migration) | Validate .84 on the A50; then drop the pin |
| content-hub ×5 `f9f0ad` | Was newer than older rootfs | Already in current rootfs: drop |
| libexiv2-27-compat | Camera/content ABI compatibility (exp 042) | Upstream report: add to rootfs seed |
| lomiri-action-api ×2 | Camera app needs Qt5 `Lomiri.Action` (exp 066) | Upstream report drafted (`dl/upstream-lomiri-action-report.md`) |

Device-tarball items (overlay, tmpfiles, recovery props, deviceinfo, systempart
in the kernel config) already follow the conventional route.

## Owner actions

- Post upstream reports/MRs (drafts are prepared on request).
- Contact the UBports porting team (forum/Matrix) once gate 1 passes.
