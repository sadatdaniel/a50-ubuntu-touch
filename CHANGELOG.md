# Changelog

## 2026-09-12 — suspend investigation in progress

- Verified the phone remains on aa1 fallback; aa6 security configuration was
  checked directly in the preserved compiled source volume.
- Identified an uninitialized ABOX QoS log argument; the enormous printed
  request value does not establish an actual excessive frequency request.
- Prepared an opt-in, freezer-only ABOX notifier isolation build. Mocked
  notifier tests pass; kernel build and hardware validation remain pending.
  This is a diagnostic experiment, not a suspend fix or OTA release.
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
