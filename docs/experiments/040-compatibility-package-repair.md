# 040 — Complete the compatibility package dependency set

3 October 2026. Status: offline recovery repair passed; normal-boot UI validation pending.

The user ran the experimental compatibility installation after successfully
choosing a private credential through the corrected Settings panel. `tar`
1.35+dfsg-4ubuntu0.4+a50openat2.1 and the official signed `libexiv2-27-compat`
package installed and configured. The camera plugin now resolves its shared
libraries. These observations do not establish working camera capture.

The three QtMir packages were unpacked but left unconfigured. Their native
ARM64 build used newer UBports dependencies than rootfs 376: specifically,
`liblomiri-content-hub1` requires version
2.2.3+0~20261002220132.55+ubports26.04.1~1.gbpf9f0ad, while the phone contained
the September 18 build. The first installer did not resolve the complete
dependency set before modifying the image. Its read-only remount also failed
with "mount point is busy", leaving the root writable. Do not repeat that
installer or claim it succeeded completely.

## Conventional repair

`scripts/experiments/stage-content-hub-repair.sh` downloads these matching
packages through the private signed UBports APT index, records SHA256 hashes,
and simulates installation together with the exact local QtMir packages:

- liblomiri-content-hub1
- libcontent-hub1 (the installed compatibility package)
- lomiri-content-hub
- qml-module-lomiri-content
- qml-module-ubuntu-content (the installed compatibility package)

All five use the October 2 version above. Total download: 306 kB. The simulated
repair upgrades only these five packages, configures the three local QtMir
packages at their `+a50mir1.1` versions, removes nothing, and leaves 126 other
updates untouched. Existing installed dependencies satisfy the remainder.
Do not bypass dependencies or substitute the unpatched repository QtMir build.

`scripts/experiments/repair-compatibility-packages.sh` verifies the staged
hashes, repeats dependency resolution as root, installs from local files with
network downloads and package removals prohibited, checks `dpkg --audit`, and
asserts the expected package states and QtMir version. The user authenticates
in the phone Terminal; no credentials are collected over USB. The script
attempts to restore the root read-only and clearly reports if a controlled
reboot is still needed. It does not restart the display session.

## Release requirements

The conventional Settings package build is now reproducible through the
existing native Ubuntu 26.04 ARM64 workflow's `settings` choice. [Run 37134674283](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37134674283) succeeded, including the targeted Qt 5 validator check. Its three runtime packages total approximately 1.15 MB and have been verified and staged on the phone. Source is
pinned to official d10c4792deb79e9c995bbb0b9eecd1226338a1ef; only the QtQuick
2.4 to 2.14 import correction is applied. A targeted Qt 5 validator reproducer
runs in CI; the full upstream integration suite is not represented as passed.

Before rebuilding the public image, resolve and install the complete package
set in the image build, retain source and dependency manifests, and validate
the ordinary Settings page, onboarding, administrator authentication, camera,
Recents, and a clean reboot without the private panel or library overrides.
The published final image must include verified fixes before first boot.
The repaired development phone alone is not a final image or an OTA channel.


The final staged repair also includes those three matching Settings packages.
The complete local-package simulation upgrades eight packages, configures the
three custom QtMir packages, removes nothing and requires no further dependency
upgrade. Private preflight and installation logs are saved on userdata.

When Terminal could not reopen, an offline recovery route was prepared in
`scripts/experiments/repair-packages-twrp.sh`. It backs up and compares the
existing `/data/ubuntu.img` before modifications, preserves the backup on
userdata, binds the existing home/extrausers/log directories, uses the standard
Debian chroot policy to prevent service startup, and reuses the package repair
with a guarded `--offline` option. The guard refuses offline mode on the
currently booted system root. Vendor, recovery and credentials are not written.
The completed recovery result is recorded below. Preparation and syntax
validation alone are not proof of execution. This wrapper is for this development image,
not the final installation procedure.


## Recovery execution result

The user returned the phone to TWRP. The 5,452,595,200-byte Ubuntu image backup
was copied to userdata and verified byte-for-byte before package changes. The
initial recovery attempts stopped before package installation: Android's
inherited PATH/TMPDIR were unsuitable for the chroot, and `--no-download`
requires local debs to be in APT's archive cache already. The wrapper now uses
a clean Linux environment and the hash-checked packages populate the normal
archive cache before preflight. No dependency bypass or further download was
used.

The actual offline APT transaction then passed: eight matching packages
upgraded, all three custom QtMir packages configured, no removals, all 13 named
package state assertions passed, and `dpkg --audit` produced no findings. The
Settings import is verified at 2.14 in its package-owned file. The camera plugin
has no unresolved libraries. The image copy of the temporary root diagnostic unit was removed. Normal boot
subsequently exposed a migrated copy under userdata-backed `/etc/systemd/system`;
its authenticated cleanup is staged, and the wrapper now also handles that copy.
Chroot mounts and service-start policy were cleaned up.

APT emitted a missing-devpts terminal-log warning and a missing `_apt` sandbox
account warning in recovery; neither prevented the verified package operation.
The repair now explicitly disables APT's optional dpkg pseudo-terminal logging
for this headless operation. No persistent authentication/sudo policy changed.

Vendor SHA256 remained
`48f5e9bfb9ef2dfd032ec7c92986ac1c8886abe7d658430b57ccacb5e3cffe3b`;
recovery remained
`8535a9d9193243412fcefc0e6f1ba585d60e1533e65069867444a49d0287e51f`.
The private temporary Settings manifest was renamed with a disabled extension
after package verification. The diagnostic ADB marker remains on userdata
until normal developer authorization is established; it must not be part of
a final installation. Normal boot passed with the packaged QtMir library, no private library override,
a read-only root, and an empty package audit. Terminal still could not reopen
until its saved hidden state was repaired; the user then confirmed it opens.
Settings/camera and repeated lifecycle validation remain open; see experiment 041.
