# 040 — Complete the compatibility package dependency set

3 October 2026. Status: repair staged and simulated; authenticated execution
and clean-boot validation pending.

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
existing native Ubuntu 26.04 ARM64 workflow's `settings` choice. Source is
pinned to official d10c4792deb79e9c995bbb0b9eecd1226338a1ef; only the QtQuick
2.4 to 2.14 import correction is applied. A targeted Qt 5 validator reproducer
runs in CI; the full upstream integration suite is not represented as passed.

Before rebuilding the public image, resolve and install the complete package
set in the image build, retain source and dependency manifests, and validate
the ordinary Settings page, onboarding, administrator authentication, camera,
Recents, and a clean reboot without the private panel or library overrides.
The published final image must include verified fixes before first boot.
The repaired development phone alone is not a final image or an OTA channel.
