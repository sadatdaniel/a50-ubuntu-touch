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
failure or success. Installation uses `--no-download`, `--no-remove` and
`--no-install-recommends`. The simulated plan may touch only cohort packages;
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

The complete corrected camera GSI still needs the external builder (250 GiB
free prerequisite). The local PC ran out of space during this audit, so no
large image build was attempted. Docker reported a read-only metadata
filesystem/I/O error; small regressions used the existing WSL Linux environment.
An old host installer ZIP was removed only after confirming its identical
SHA256 copy on the phone; source caches, recovery images and volumes were
preserved. Stopped-container cleanup requires Docker recovery. Do not restart
Docker without accounting for the two unrelated running jobs.

aa18 remains unflashed while the owner is away. Full image installation,
clean installation and [official recovery/OTA testing](https://docs.ubports.com/en/latest/porting/finalize/UBports_recovery.html)
remain release blockers. No stable-release or automatic-update claim follows
from this audit.
