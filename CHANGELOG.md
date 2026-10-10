# Changelog

## 2026-10-10 — adopt existing upstream display corrections

- Replaced the local QtMir DPR package with official Mir1 scaling guards;
  exact three-package transaction and full read-only reboot pass. Published
  guarded installation/rollback and source-linked evidence.
- Exact upstream Lomiri Recents revert fixes stretched previews in a private
  screenshot/user-confirmed runtime test. Added reversible reproduction and a
  current-source native package build profile retaining the reopening backport.
  Native ARM64 build, exact four-package installation and full reboot
  persistence pass. User confirms correct previews and three close/reopens
  each for Terminal and Settings; screenshot and zero shell restarts agree.
- One two-app graphical Restart completes a real reboot, but the original
  four-app combination still crashes. Native trace captures SIGBUS in the shared
  close-all function; prepared stable-ID snapshot patch and actual-function
  ASan regression. Native ARM64 regression/build/install/full reboot pass;
  two original four-app power-menu tests now complete real kernel reboots,
  including a repeat without the debugger. Post-boot security/startup checks pass.
- Installed the existing overlay autosuspend startup helper/unit; normal full
  reboot activates Android autosuspend. New unplugged validation remains.
  OTA remains disabled and release gates open.

## 2026-10-04 — shared recording fix and fresh-image validation

- Initialized fresh Waydroid using official defaults and verified Android images;
  native icon/first launch are user-confirmed and basic Internet/DNS passes.
  Added guarded setup reproduction and recorded exact inputs. K380 now pairs
  and user-confirmed input works; published metadata-only diagnostics.
  Waydroid lifecycle/audio/sleep and keyboard idle/reconnect remain open.
  Reproduced third-reopen failure with Android still healthy; a one-line native
  single-instance setting passes generator regression and is in a reversible
  hardware test; all three user reopens and icon checks pass. Added exact-source
  patch, regression, rollback script and conventional package build. Build and
  one-package installation now pass against a verified original signed package;
  root is read-only and the temporary source bind removed. Installed source and
  native entry survive a real reboot, but the user reproduced delayed reopening
  and icon loss. A second candidate removes unnecessary launcher unlinking; its
  stronger regression and build pass. Candidate .2 is installed and persists
  across a real reboot; all three user drawer close/reopens and icon persistence
  pass afterward. Longer-use, sleep/audio/network and clean-image tests remain. Documented matched F-Droid server tests; no network setting changed.

- aa16 boots with actual AppArmor enforcement, RFCOMM availability and working
  RTKit audio scheduling. Native USB supply events now report removal/reinsert,
  but Samsung's stale DWC3 pull-up state blocked enumeration. Published the
  narrow upstream ordering adaptation, actual-function regression and guarded
  aa17 build/flash/native USB test scripts. aa17 boots with screen/touch working;
  three awake cable cycles and four real deep cycles now recover USB without
  Developer Mode toggles. Actual confinement and normal scheduling pass.
  Removed old rescue/always-connected settings through supported device config;
  clean image, other USB modes and longer soak remain.
- Full pinned Android build failed on runner storage at 68%; no complete image
  or new GSI pin exists. Larger conventional build capacity is required. Camera
  mounts ended on kernel reboot; previous video success was a temporary test.

- Confirmed awake USB cable failure independently of suspend. The upstream
  Android detector recognized removal but not reinsertion; native trace showed
  no USB supply events. Published guarded ten-minute experiment/rollback scripts.
  Preparing the existing Samsung cable-notification correction as an unflashed
  kernel candidate; no permanent detector workaround is installed.

- Installed matching upstream window-state packages; repeated app reopening
  was exercised. Normal YouTube audio survived reboot. AppArmor's temporary
  file allow/deny test passed. Wider first-boot and OTA validation remain.
- Replaced the failed one-call recording experiment with exact Halium PR 84's
  shared AudioFlinger accessor correction. Both ABIs built and passed original
  interface/dependency comparisons. The user confirms three Stop/playback tests
  with picture and sound; three private samples decode cleanly. Added a pinned
  upstream full-image build option; reboot/image validation remains, with the
  original GSI lock and vendor image retained.
- Established opt-in runtime SSH over USB through normal authentication.
  Native suspend activation and repowerd restart lifecycle passed. Fresh aa13
  completed two deep cycles totaling 89.765 seconds with zero failures and normal
  screen/touch recovery. Packaged the tested activation helper/unit in the overlay;
  clean-boot validation remains. USB debugging needed a Developer Mode toggle.
  Published the adapted guarded test and updated the release/update checklist.
- Added a tested standard systemd writable-path condition for the immutable
  package-backup destination. Validated missingok only for two optional syslog
  rotation rules; no log-rotation timer is disabled.

See [current handoff](docs/SESSION-HANDOFF-20.md),
[recording experiment](docs/experiments/044-recording-audioflinger-backport.md)
and [fresh-image health](docs/experiments/047-fresh-suspend-startup-and-readonly-health.md).

## 2026-10-03 - conventional window-state correction

- Found the original upstream Lomiri MR 331 correction for app windows that
  remain hidden across relaunch. Replaced the experimental build's local
  storage patch with that upstream save/load correction and a regression.
- Installation preflight rejected the first package candidate's newer library
  requirements. Retained signed rollback packages and pinned the disposable
  builder to matching runtime libraries; the phone remains unchanged.

See [app lifecycle follow-up](docs/experiments/041-authentication-and-terminal-runtime.md).

## 2026-10-03 - startup dependency links and recording diagnosis

- Corrected three ordinary startup files to conventional Git symlinks for the
  existing audio and GNSS units. Added an archive regression check and a
  backed-up authenticated audio startup repair. Restored the missing HIDL
  namespace setting in the first-boot overlay; normal YouTube sound is
  user-confirmed before and after reboot.
- Clean reboot reproduced video Stop blocking. The recorder callback waits on
  an unused AudioFlinger lookup left by the Halium recording patch. Published
  the improved bounded collector and evidence; no video fix is claimed yet.

See [audio startup packaging](docs/experiments/043-audio-startup-packaging.md).

## 2026-10-03 — Camera dependencies and audio configuration

- Installed the two signed official Lomiri Action API dependencies needed by
  Camera 4.1.1. The user confirms Camera opens and photo capture works.
- Removed the redundant device HIDL helper argument already supplied by the
  upstream session configuration. Real audio outputs and microphone input now
  initialize; video Stop and playback remain under test.
- Published reproducible dependency and audio repair scripts plus a bounded
  private diagnostic collector. Manual phone commands use the short `fix` and
  `log` filenames; no media or raw device logs are published.
- Shared Lomiri hidden-state correction compiled on native ARM; its SQLite
  regression fails before the patch and passes afterward. Phone integration
  and shell crash validation remain pending. Diagnostic-unit cleanup completed.

See [Camera and audio evidence](docs/experiments/042-camera-dependencies-and-video-stop.md).


## 2026-10-03 — compatibility repair and Terminal reopening

- Completed the verified offline dependency repair: eight matching upgrades,
  three configured QtMir packages, no removals and clean package audit. The next
  normal boot uses the packaged QtMir library without overrides and read-only root.
- Current-source tar and signed camera compatibility library are installed;
  camera capture and Recents rendering still require validation.
- The conventional Settings package includes the tested QtQuick 2.14 import fix.
  The temporary Settings test manifest is disabled; ordinary UI validation remains.
- Terminal's saved hidden state prevented reopening. A private backup and one-row
  correction restored the normal authentication window; the user confirms it opens.
  A shared storage correction and SQLite regression test are prepared for native
  ARM package validation. Failed-auth CPU looping and shell crashes remain open.
- Recovery cleanup now covers the migrated diagnostic unit on userdata. Its live
  authenticated cleanup is staged; vendor and recovery hashes remain unchanged.

See [package repair](docs/experiments/040-compatibility-package-repair.md) and
[Terminal investigation](docs/experiments/041-authentication-and-terminal-runtime.md).

## 2026-09-13 â€” watchdog freezer-state development validation

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


## 2026-09-12 â€” suspend investigation in progress

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

## 2026-09-12 â€” aa6 development validation

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
