# Changelog

## 2026-10-03 — fresh-install compatibility diagnostics

- Current-source QtMir ARM64 build restores wizard geometry; the user confirms
  correct display and completed swipe-only onboarding. Temporary library loading
  remains; Recents distortion and permanent installation/second boot are open.
- Current-source tar rebuild passes 222 upstream tests and native 4.14 archive/
  dpkg-deb extraction checks. Normal tar installation now passes; the QtMir dependency repair remains pending.
- Unlock-method Settings cannot load: the Qt 6 preparation change introduced a
  validator unavailable under its QtQuick 2.4 import. The isolated 2.14 import
  correction passes on the phone. A standard temporary panel then allowed the user to choose a private credential. A conventional ARM64 package build is now available.
- Fresh Camera lacks libexiv2.so.27; the signed 26.04 compatibility package is
  installed and the plugin resolves all shared libraries. Waydroid package is present but Android images are absent
  after the wipe. No camera/Waydroid fix or stable-release result is claimed.

The first QtMir installation left three packages unconfigured because of a newer content-hub dependency. The complete signed repair is staged and simulated; root read-only restoration and clean-boot validation remain pending.

See [fresh diagnostics](docs/experiments/039-lock-security-import-regression.md) and [package repair](docs/experiments/040-compatibility-package-repair.md).

## 2026-09-13 — watchdog freezer-state development validation

- aa8 preserves the secondary watchdog's previous enable state. Two freezer
  cycles passed with normal ABOX callbacks; the first was observed for ten
  minutes before repetition. Logs directly confirmed the timer was inactive.
- A devices-stage cycle returned but USB enumeration failed on Windows.
  Wi-Fi survived, and software reconnection restored USB without rebooting.
  The same boot remained responsive more than two hours later. USB resume,
  deep sleep and automatic suspend are not yet fixed or validated.
- AppArmor and hardened usercopy remain enabled. The aa1 recovery image is
  still on disk; aa8 is running. Waydroid reliability and camera video remain
  unresolved. No OTA or stable release is claimed.

See [experiment 020](docs/experiments/020-watchdog-freezer-state.md) and
[session handoff 20](docs/SESSION-HANDOFF-20.md).


## 2026-09-12 — suspend investigation in progress

- Verified the phone remains on aa1 fallback; aa6 security configuration was
  checked directly in the preserved compiled source volume.
- Identified an uninitialized ABOX QoS log argument; the enormous printed
  request value does not establish an actual excessive frequency request.
- Built and booted the opt-in aa7 ABOX freezer-isolation kernel with AppArmor
  enabled; user confirmed screen and touch. Automatic aa1 fallback restoration
  was verified. One diagnostic cycle then lost USB and Wi-Fi connectivity.
  Physical state and recovered logs are pending; isolation and cause are not
  established. This is not a suspend fix or OTA release.
- Resumed temporary 30-minute health captures with 48 rotating slots and
  WakeSystem=no. The timer ends on reboot.

See [session handoff 20](docs/SESSION-HANDOFF-20.md).

## 2026-09-12 — aa6 development validation

### Published

- [aa6 kernel development prerelease](https://github.com/sadatdaniel/a50-halium/releases/tag/a50-ubports-halium-2026-09-12-aa6), built from `ac4c288bfb60e862d5d52ca52a8b5d301b75dbb5`, with boot image, kernel, symbols, resolved configuration, input hashes, build manifest, reproduction instructions and checksums. An independent rebuild has not yet verified bit-for-bit reproducibility.

### Verified

- AppArmor socket peer context works on aa6; media-hub no longer fails on the camera permission context. User confirmed live camera preview. Complete AppArmor validation remains pending.
- Reconciled the phone's outdated Waydroid desktop hook with the committed version. User confirmed the launcher icon appears after refreshing the app drawer; this does not establish Waydroid reliability.
- Added an optional bounded health-capture script. Its temporary 30-minute timer was tested and ended on reboot; it is not part of the production overlay.

### Known issues

- Suspend remains broken: one aa6 freezer-stage test returned after five seconds, then the device froze and lost USB/Wi-Fi connectivity. Deep suspend was not tested. Recovery logs end after ABOX firmware restart messages without a captured panic; the cause is not established.
- User manually restarted into the preserved aa1 fallback, with AppArmor disabled. aa6 is published but is not the current on-disk boot image.
- Waydroid remains unreliable; the user reported another launch failure after recovery.
- Camera video mode remains broken and is deferred.
- Unified recovery, system-partition migration, local OTA validation and UBports installer integration remain pending. This is not an OTA or stable release.

See [session handoff 19](docs/SESSION-HANDOFF-19.md) for recovered evidence and next steps. Raw device logs remain local and are not included in Git.
