# 059 — Build-time integration of the validated package cohort

11 October 2026. Ubuntu Touch 26.04 only. Development inputs, not a stable image
or an enabled OTA channel. No phone package installation, reboot or flash was
performed in this audit.

## Problem and conventional approach

The previous image assembler extracted the Ubuntu/GSI/device tarballs and
applied a few standalone repairs. It did not install the validated Lomiri,
Settings, tar or Waydroid packages. Rebuilding that image could lose fixes even
though their sources, package build scripts and phone tests were published.

The [official UBports rootfs builder](https://gitlab.com/ubports/development/core/rootfs-builder-debos/-/blob/e117d0f4903ef747ea892a6d5c1337b11f80390c/ubuntu-touch/ubuntu-touch-common.yaml)
installs native packages through APT inside the build chroot. This integration
uses that same mechanism in the existing image assembler. It does not unpack
replacement libraries or run an on-phone first-boot repair.

`scripts/release/validated-packages.lock` records package name, version,
architecture, SHA256 and archive/build origin for the 18 tested inputs. Nine
are native source backports; nine are official UBports archives whose hashes
were matched to the phone's signed-repository metadata. The official QtMir
ac3ee9 cohort replaces the obsolete a50mir1 workaround. No indicators-client
package from the Lomiri build is included.

## Build interface and safeguards

Prepare a directory containing exactly the locked `.deb` filenames. Retrieve
the official `https://repo.ubports.com/` archive URLs from the lock. Build the
local backports with their existing pinned scripts:

- `build-lomiri-window-state-package.sh DIR --restart-safe`: four packages.
- `build-lock-settings-package.sh DIR`: three packages.
- `build-tar-openat2-package.sh DIR`: one package.
- `build-waydroid-single-instance-package.sh DIR`: one package.

All are under `scripts/experiments`. CI artifacts have limited retention;
the recorded Actions run is provenance, not permanent distribution hosting.
Preserve release archives with their hashes when publishing a candidate.
If rebuilding yields different archive bytes, investigate and deliberately
update the lock after validation; do not disable the checksum check.

On a Linux builder with native ARM64 execution or a previously configured
binfmt interpreter:

```sh
python3 scripts/release/verify-package-bundle.py --bundle /path/to/bundle
sudo bash scripts/release/build-rootfs-image.sh \
    --device-tarball out/device_a50.tar.xz --package-bundle /path/to/bundle
bash scripts/release/make-installer-zip.sh --out "$PWD/out" --version CANDIDATE
```

The bundle is verified before large downloads or image creation. APT runs
against the offline 26.04/arm64 root, with service startup temporarily blocked
through the native policy-rc.d convention. Existing policy is restored on
failure or success. Installation disables all APT sources and uses
`--no-remove` and `--no-install-recommends`. (`--no-download` was used
originally, but it also blocks APT copying local archives, so the real install
failed; see [060](060-upstream-input-retention.md).) The simulated plan may touch only cohort packages;
missing or incompatible base dependencies abort the build. Resolve those by
reviewing signed repository inputs, rather than fetching unrecorded packages
or substituting raw library files.

Device/version overlays follow package installation. Installed versions,
architectures, status and dpkg audit are checked afterward. The image contains
the lock and a full package inventory under `/usr/share/a50-release/`.
Only a fully completed/unmounted image gets an atomic success stamp binding
rootfs, boot, package lock and actual Ubuntu/GSI provenance. The ZIP builder
verifies that stamp and the current cohort before compression. It embeds the
lock and actual GSI source; it no longer mislabels a candidate as gsi.lock's
baseline. Default packaging without the optional kernel manifest is also
covered by the regression.

This is a frozen **candidate cohort**, not a blanket apt hold. New upstream
versions require reviewing/removing backports and validating a new cohort.
An OTA rootfs component must include these native packages through its build
recipe; a device overlay alone cannot preserve them across rootfs replacement.

## Checks performed

- All 18 real archives match locked hashes and native Debian package metadata;
  total size 8,110,264 bytes.
- The phone's native ARM64 verifier matches all 18 installed versions and
  architectures. Native APT simulation succeeds: zero installations, upgrades
  or removals. This confirms the running cohort, not a fresh rootfs install.
- A real Debian archive regression rejects missing/extra/corrupt archives,
  metadata mismatches, duplicate/path inputs and wrong installed versions.
- A tiny real ZIP regression rejects absent build stamps, modified image
  inputs and a different cohort; actual candidate GSI provenance and embedded
  lock are verified. No real phone image is built or flashed by that test.
- Shell syntax and refusal to install into `/` pass. Final phone health:
  root read-only, AppArmor Y, empty dpkg audit and zero failed system units.

Run on Linux; the image gate regression requires root and standard zip/unzip:

```sh
python3 scripts/release/test-validated-packages.py
sudo bash scripts/release/test-image-package-gates.sh
```

Private phone evidence is `/userdata/a50-integration-audit-20261011`, including
`packages.tsv`, `native-apt-plan.txt` and the verified bundle. It is not published.

## Integration matrix and remaining gates

| Fix/component | Build home | Evidence still required |
|---|---|---|
| Lomiri reopen/Recents/shared Restart | Four native a50state.4 packages | Actual offline rootfs installation and clean boot |
| QtMir proportions | Three official ac3ee9 packages | Same image/clean-boot gate; obsolete package rejected by cohort |
| Settings QtQuick validator | Three native a50qtquick.1 packages | First-boot none/PIN/passphrase transitions |
| Kernel-4.14 tar compatibility | Native a50openat2.1 package | Actual image install; update/reset use |
| Camera/content ABI compatibility | Official exiv2/content-hub packages | Fresh-image Camera/OpenStore/content flows |
| Waydroid launcher lifecycle | Native a50singleinstance.2 package | Fresh setup, image initialization and reboot/soak; Android images are separate userdata inputs |
| Audio, ION access, autosuspend, USB defaults | Committed device overlay | Rebuilt tarball and clean-image boot; generated audio linker allowlist still needs upstream replacement |
| AppArmor, watchdog/Wi-Fi/USB kernel fixes | Tested aa17 kernel profile | Conventional device build still differs; aa18 pidfd wait is unflashed |
| Polkit 127 authentication on kernel 4.14 | Supported legacy helper image script | First-boot authentication and permissions in final image |
| Video Stop deadlock | Exact Halium PR84 Android backport | Complete corrected GSI build, interface checks, boot and repeated recording; temporary library test is insufficient |
| OTA/recovery/reset/installer | Existing finalization candidates | Hardware-tested unified recovery, two signed updates retaining userdata and a maintained channel |

The legacy OpenStore compatibility script still downloads/extracts unowned
older libxml2/ICU payloads. That is a separate release debt; this cohort does
not claim to replace it with properly managed/signed compatibility packages.
The generic build.sh kernel path follows a moving adaptation-tools checkout
and an older device kernel profile. Do not use it as proof that tested aa17
fixes are included. Device tarball mode/symlinks must continue to come from
`git archive`, not a Windows working tree.

The complete corrected camera GSI needs a conventional Linux builder with about
250 GiB free. After cleanup and VHD compaction this Windows PC has about 44.3 GiB
free, so no full GSI build was attempted. Docker is healthy and the owner has
not approved paid cloud provisioning. An old host installer ZIP was removed
only after confirming its identical SHA256 copy on the phone. Subsequent owner-
authorized cleanup removed only obsolete A50 Docker caches; the dated follow-ups
below record retained inputs, restored Docker and current space. One unrelated
container job resumed. Do not disturb it.

aa18 remains unflashed. Full image installation,
clean installation and [official recovery/OTA testing](https://docs.ubports.com/en/latest/porting/finalize/UBports_recovery.html)
remain release blockers. No stable-release or automatic-update claim follows
from this audit.

## Docker recovery follow-up, 11 October

The owner approved the restart and interruption of the other running jobs.
Native restart/stop failed because WSL could not access the existing Docker
data disk. The standard [Microsoft WSL disk recovery procedure](https://learn.microsoft.com/en-us/windows/wsl/disk-space)
restored its attachment. A UUID-checked, unmounted disk check skipped pending
journal recovery and initially aborted. The installed e2fsck journal-only
mode then replayed committed changes with an undo file and exit 0. A fresh
read-only check completed all five passes with exit 0; summary free-block/inode
counter warnings remained, without the earlier directory corruption messages.

Docker now starts normally, creates/removes new container metadata and reads
the protected kernel source cache. Four verified stopped A50 containers were
removed without deleting volumes. All three associated kernel/release volumes
remain present; other cached inputs and recovery images were retained. One
unrelated job resumed under its existing restart policy. No factory reset,
disk formatting, phone reboot or firmware/package changes were performed.

Private logs, undo evidence and removed-container records are in the task's
`work/private/docker-recovery-20261011`. The undo predates resumed Docker writes
and must not be applied blindly. Disk-device letters can change; identify the
exact VHD and UUID for any future operation. Windows still has only about
1.5 GiB free, so this does not enable the full Android image build locally.

## Owner-authorized cache cleanup follow-up, 11 October

The owner requested removal of obsolete port sources/caches and actual reduction
of Docker's Windows disk usage. Scope was checked through container status,
volume consumers, mount mappings and image ownership; no global prune was used.
All 23 remaining A50 containers were verified exited and removed without force.
The nine obsolete kernel volumes (`a50-ksrc`, `a50-ksrc-aa4`, `a50-ksrc-aa5`,
`a50-ksrc-aa6`, `a50-ksrc-aa7-isolation`, `a50-ksrc-aa8-watchdog`,
`a50-ksrc-aa9-usb-sleep`, `a50-ksrc-aa10-usb-core`, `a50-ksrc-aa11-wifi-sleep`)
and two obsolete assembled-image volumes (`a50-release-aa12-rootfs`,
`a50-release-readonly-376`) were explicitly removed with `docker volume rm`.
The old `a50-journal-reader` image and dangling A50 image `a87a3805a010` were
removed. Host bind-mounted files were not deleted.

The current `a50-ksrc-aa12-wifi-early` cache and `a50-halium-build` image remain,
along with both host Git repositories, firmware inputs, aa17 fallback, aa18
candidate, recovery images and the verified 18-package archive cohort. The two
boot image hashes still match their recorded values. Historical experiment
volumes no longer exist: recreate their sources through the recorded checkout
and build instructions if needed, rather than expecting a cached baseline.
Unrelated project volumes/images/build caches and job data were not removed.

Docker's reported logical volume usage fell from 56.1 GB to 9.584 GB; stopped
container writable layers fell from about 845 MB to zero. The data filesystem
reports about 19.4 GiB used. These are not measurements of reclaimed Windows
space. UUID/mount-checked native `fstrim` returned zero newly trimmed bytes.
Docker stopped cleanly but logged that it skipped built-in compaction. The
[standard Windows DiskPart compaction](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/compact-vdisk)
was prepared for the exact detached Docker VHD; Windows cancelled elevation
before the helper ran. No successful manual compaction is claimed.

Docker restarted normally and the unrelated job resumed under its existing
restart policy. A fresh disposable, network-disabled, read-only container
successfully read the retained kernel cache and exercised Docker metadata.
At the end of this cleanup but before the later compaction retry, the VHD was
70,573,359,104 bytes (about 65.7 GiB), with roughly 1.7 GiB free on C:. Private
inventory, scoped DiskPart instructions
and cleanup/recovery evidence remain under `work/private/docker-recovery-20261011`.
Do not run disk compaction while Docker/WSL has the VHD attached; the helper
requires Docker to be fully stopped. No phone changes occurred.

## Compaction retry, 11 October

The owner requested a retry. Docker stopped cleanly and WSL was shut down.
The elevated PowerShell `-File` helper exited without creating a result log;
the default Windows script policy appears to have prevented its execution,
but that cause was not independently captured. No script-policy change was
made. A second attempt launched native DiskPart directly with the exact scoped
input file; Windows returned "The operation was canceled by the user" at
administrator confirmation, before DiskPart launched. No successful manual
compaction is claimed. Do not assume the private PowerShell helper ran.

Some space returned automatically during shutdown: the data VHD decreased
from 70,573,359,104 to 68,777,148,416 bytes (about 1.67 GiB). After Docker was
restored, C: had 3,650,916,352 bytes free (about 3.4 GiB). The remaining job
resumed under its existing restart policy and a fresh read-only container
successfully read the preserved current kernel source. Manual compaction still
requires Windows administrator confirmation and a detached disk; native
DiskPart can consume the prepared `compact-docker.txt` without running a
PowerShell script. No further data removal or phone change was performed.

## Successful native compaction, 11 October

The owner explicitly approved another attempt. Docker stopped cleanly, WSL shut
down, and native DiskPart was launched directly against the exact detached
Docker data VHD. DiskPart exited 0. VHD file size fell from 68,777,148,416 to
24,795,676,672 bytes (about 41 GiB returned); C: free space rose to
47,606,820,864 bytes (about 44.3 GiB). Docker restarted normally and the
unrelated oci-a1-retry job resumed under its existing policy. A fresh disposable
read-only, network-disabled container verified the retained A50 kernel cache.
No phone changes occurred.
