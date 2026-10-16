# 060 — Upstream review: PR 84, GSI pin retention and cohort inputs

11 October 2026. Ubuntu Touch 26.04 only. Review and input preservation; no
flash, package install or reboot on the phone. Live phone check first.

## Live phone state

Reached over USB ADB after Wi-Fi SSH timed out. Running kernel is **aa17**:
`/proc/version` shows build `#6`. Its config and symbol names match both
the aa17 and aa18 outputs exactly. aa18's image carries `#7`, so the build
number is the distinguishing mark. Boot ID unchanged since the overnight soak
(up since 2026-10-10 17:14). Root RO, AppArmor Y, zero failed units, dpkg audit
empty, battery 98% charging. Load average ~17 comes from 16 D-state Samsung
TEE/RPMB kernel threads (`tz_worker`, `tz_iwsock`, `scsi_srpmb_work`,
`simpleinteracti`) with no CPU use, consistent with the ~12 baseline in
[006](006-what-we-missed.md). aa18 stays unflashed.

## Camera: Halium PR 84

[Halium/hybris-patches#84](https://github.com/Halium/hybris-patches/pull/84) is
still open, base `halium-11.0`, mergeable, head unchanged at `f2083f3e`, no
review or comments since 23 September. The halium-11.0 head is still
`790b3792`, the same revision our GSI pin uses. The conventional route remains
an upstream merge. UBports' daily `generic_arm64` Jenkins job builds that
branch (`haliumDeviceBuild('11.0', 'halium_arm64', ...)`), so a merge reaches
a normal numbered GSI. The port then only moves the `gsi.lock` pin, with no
250 GiB private build. Posting A50 evidence on the PR is an outward action
and awaits the owner.

## GSI pin no longer downloadable from Jenkins

Jenkins lists builds 1479–1578, but artifacts are kept for only about the
last 30 builds. Builds 1548 and older return 404 for
`halium_halium_arm64.tar.xz` and `used-repos.txt`. 1549 and later download.
**The pinned 1542 tarball is gone upstream.** `build-rootfs-image.sh` only
works from the cached `dl/halium_halium_arm64-1542.tar.xz` (gitignored). It
still matches `GSI_SHA256` (`48ed0fd1…`, 131,801,268 bytes). Any future pin
expires about a month after its build. A release must archive the exact GSI
tarball, e.g. as a release asset, rather than rely on Jenkins.

## Upstream security drift since 1542

Build 1578 (11 October) records the same 879 projects. frameworks/av moved
`18186d8` → `7db8eb3`: six LineageOS security fixes (Matroska write OOB,
AudioAttributes unmarshalling overflow, DynamicsProcessing OOB, MediaBuffer
off-by-32, Camera3StreamSplitter bounds check, camera mapper OOB).
`media/libaudioclient/AudioSystem.cpp` is still blob `bf98822`, so PR 84
applies to it unchanged. A full GSI build pinned to 1542 sources would ship
those known media/camera bugs. When the corrected GSI is built, re-pin to a
current retained build's `used-repos.txt`, keep the PR 84 blob guard, then
reflash and boot-test. Do not ship a stale 1542-based private GSI.

## Cohort archive retention

The 18-package lock is complete, but its inputs were not durable on the host:

| Inputs | Source | State 11 Oct |
|---|---|---|
| 9 official | repo.ubports.com pool | Downloaded; all hashes match |
| 4 Lomiri a50state.4 | Actions run 38061616400 | Artifact expires 2026-10-13; downloaded, all 4 match |
| 3 Settings a50qtquick.1 | phablet-readable phone copy | Pulled; all 3 match |
| tar a50openat2.1, waydroid a50singleinstance.2 | root-only phone audit evidence | Waydroid CI artifact already expired |

The rebuild scripts call `dch`, which stamps the current date, so a rebuild
cannot reproduce locked bytes. Per [059](059-image-package-integration.md),
a different archive needs revalidation, never a loosened hash check. The
host copy is under gitignored `dl/cohort-20261011/`. Like the GSI, it must
become a release asset before it can be called reproducible.

## Fresh-rootfs cohort test

`scripts/release/test-fresh-rootfs-cohort.sh ROOTFS_TAR BUNDLE EVIDENCE` runs
the builder's own `install-validated-packages.sh` against a freshly extracted
official rootfs. It runs in a disposable network-disabled container using
the retained `a50-halium-build` image and Docker's arm64 binfmt. It checks the
embedded lock and empty dpkg audit, and fails if any non-cohort package
changes. Input rootfs: today's daily
`rootfs-809e340e…` (index checksum `a213879c…`, 687,801,256 bytes, built by
rootfs-builder-debos `e117d0f4`, the commit cited in 059).

### Gated result, 16 October: PASS after an installer fix

The owner ran the copy-only export with sudo. Both archives match the lock.
All 18 archives were assembled into a flat bundle and verified.

**First run failed.** The simulated plan passed, but the real install aborted:
`E: Internal Error, Pathname to install is not absolute 'tar_…deb'`. A
single-package retry (tar alone, then the other 17) failed the same way for
any local archive (APT 3.2.0 in the rootfs). Cause: `--no-download` also
disables APT's acquisition of local `.deb` files, so they never get a cache
path. `repair-compatibility-packages.sh` already documented this pitfall.
The phone APT check and the 16-package check above were simulations only,
so the image builder's real install step had never succeeded.

**Fix** (`install-validated-packages.sh`): drop `--no-download` and disable
every source with `Dir::Etc::SourceList=/dev/null` and
`Dir::Etc::SourceParts=/dev/null`. Only the hash-checked local archives are
then installable; the plan gate is unchanged. `apt-get clean` removes the
copied archives from the image cache afterwards.

**Rerun:** `test-fresh-rootfs-cohort.sh` exits 0 on rootfs `809e340e…`.
Exactly 13 packages changed, all in the cohort: libexiv2-27-compat, the 4
Lomiri, 3 QtMir, 3 Settings, tar and waydroid. Every maintainer script ran,
`apt check` passed, dpkg audit is empty, the post-install verifier matches
all 18, and the embedded lock is identical. A harness bug, where `diff` exit
1 aborted under pipefail, was fixed before the final run. Evidence is in
gitignored `dl/fresh-rootfs-test-20261016c/`.

This proves the cohort installs into a fresh official rootfs through the
builder's own step. It does not prove a bootable image. A full image (GSI,
device tarball, overlays), a clean flash and first-boot checks remain.

### Preliminary simulation with the 16 held archives

This is not the gated test. In the same fresh rootfs (arm64, 26.04, empty
audit), an APT `--simulate` with the same flags succeeds with zero removals.
It shows that **the rootfs has moved past part of the cohort**:

| Packages | Fresh rootfs | Cohort | Effect |
|---|---|---|---|
| content-hub ×5 | `.55 f9f0ad` | same | no change |
| libexiv2-27-compat | absent | locked | new install |
| Lomiri ×4 | `.519 fe38aa` | `+a50state.4` of same base | upgrade |
| QtMir ×3 | `.84 6a015e` | `.83 ac3ee9` | **downgrade** |
| Settings ×3 | `.490 aeb37d` | `.487 d10c47+a50qtquick.1` | **downgrade** |

The installer passes `--allow-downgrades` and its plan gate checks only
package names, so a build would pass and silently roll these back.
Upstream review:

- Settings `.487`→`.490` is Weblate translations only (`po/eu.po`,
  `po/nb.po`). Low risk; rebase `a50qtquick` onto current upstream when the
  cohort is next revalidated.
- QtMir `.83`→`.84` is the Mir→miroil migration (14 commits, about 60 files,
  merged 10 October). It is untested on A50. Keeping validated `.83` is
  ABI-consistent: Mir/miroil packages are identical on the phone and in the
  fresh rootfs. Revalidate Restart/Recents/scaling before moving to `.84`.

Comparing the phone's 1,602 packages with the fresh rootfs's 1,593 shows
**184 version differences outside the cohort** (UI toolkit, keyboard,
online accounts, telephony, notifications, address book and others),
10 phone-only packages and 1 fresh-only package. The running phone is not a
proxy for a clean build. The fresh-image checklist must run on the actual
candidate. The rootfs is resolved from the moving daily index, so record
its hash per candidate, as the builder already does.

## Rollback

Nothing on the phone changed apart from the phablet-owned helper
`/home/phablet/a50-cohort-export.sh` and its copy-only output directory.
Both can be removed once release inputs are archived durably. To roll back
the installer fix, revert it, but the old flags cannot complete a real
install. Host additions are confined to gitignored `dl/`.
