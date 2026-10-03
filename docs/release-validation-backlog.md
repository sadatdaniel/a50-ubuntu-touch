# Release validation backlog

Updated 2026-10-03. Ubuntu Touch 26.04 only. This remains a development port.
Research existing upstream implementations first; prefer supported UBports
configuration and narrowly scoped device adaptations. Record source references,
reproduction, validation and rollback for every fix, and publish the scripts.

| Area | Current evidence | Required before stable release |
| --- | --- | --- |
| Suspend/resume | aa12 plus supported repowerd Wi-Fi hooks completed 35 automatic cycles, zero resume failures; user confirmed screen/touch | Calendar timer passed across sleep; repeated cycles, network recovery, screen-on inhibition, service restart and battery drain; reproducible permanent enablement |
| AppArmor | Real allowed/denied file-access probe passes on aa12; normal biometry/location permissions work | Final image must boot the hardened kernel by default, remove testing bypasses, verify application confinement after clean install and OTA |
| Authentication | Installed polkit's supported legacy helper fixed password validation; duplicate local account removal fixed swipe; user confirmed PIN/swipe | Resolve fresh LockSecurity.qml import failure ([039](experiments/039-lock-security-import-regression.md)); isolated correction and full temporary panel pass; user chose a private credential, conventional Settings package installed and read-only reboot passed; failed-auth CPU loop, hidden-state reopening repair and shared fix candidate are tracked in [041](experiments/041-authentication-and-terminal-runtime.md). Test passphrase/PIN/swipe and reboot/OTA; preserve authentication protection and package-managed ownership |
| First-run setup | Clean 26.04 image 376 reaches setup with touch confirmed after aa13 USB fix, supported ubuntu.img layout, native LXC hooks, schedtune correction and Samsung/upstream ION rule | Wizard display is user-confirmed with the current-source QtMir test library ([037](experiments/037-clean-wizard-mir1-scaling.md)); swipe-only onboarding completed. Normal QtMir packages installed and read-only reboot passed; resolve Recents rendering, user-chosen credentials, normal developer authorization, remove temporary diagnostics, second boot |
| Recovery and OTA | Unified recovery candidate built and checked offline; TWRP backup retained; no candidate recovery flash yet | Conventional layout/build pipeline, safe recovery boot test, signed local OTA, second update and userdata preservation, signed channel hosting, installer configuration |
| Waydroid | Old install: Gio/LAL listed the missing launcher with no service restarts. Fresh install: package present, no initialized Android images/user launcher; official setup pending | Reproduce launcher disappearance and distinguish drawer cache from desktop-file changes; repeated launches/stops, network/audio, sleep/wake, compositor restart, extended use; remove stopgap adaptations only after valid replacements |
| Bluetooth keyboard | User reports unsolicited disconnect/reconnect | Capture controller/connection logs; idle, typing, reconnect and suspend tests |
| VPN | Untested | Supported VPN configuration, routing/DNS, reconnect and sleep/wake |
| Libertine | Untested | Container creation, package install, application launch/input and reboot persistence |
| Factory reset | Untested | Disposable test data or verified backup; recovery operation, clean onboarding and no unintended partition loss |
| Camera/video and audio | Fresh photo capture user-confirmed after official Exiv2 and Action API packages. Video Stop freezes. Duplicate HIDL argument removed. Correct startup links and system HIDL namespace restore normal YouTube sound, user-confirmed before/after reboot ([043](experiments/043-audio-startup-packaging.md)). Clean-reboot recorder trace blocks on an unused AudioFlinger lookup; an existing Halium 13 correction is the backport candidate ([042](experiments/042-camera-dependencies-and-video-stop.md)) | Capture/playback, call and media routing, Bluetooth audio, recovery after sleep |
| Notifications | Current push packages installed; end-to-end test outstanding | Delivery while awake/asleep, wake behavior and application permissions |
| Charging estimate | User reports inaccurate lock-screen time to full; low priority | Compare lock-screen, indicator and battery-provider values at the same time; fix the responsible layer using upstream behavior |
| Fingerprint | Driver and enrollment path exist; successful capture/enrollment unproven | Investigate last; preserve calibration and trusted firmware; advertise unavailable unless verified |

The conventional calendar-timer workaround passed auto9. Clean setup now renders after experiments 034–036; complete onboarding and a second boot,
then rerun confinement and suspend startup on the fresh image. Waydroid must be
installed and validated without the erased old Helper/Android state. Close the
OTA release blockers and remaining functional checks above.
Do not call a single successful run a stable release.

`agent.md` and `first_contact.md` are explicitly deferred until this checklist is
resolved, per the user's request. They must consolidate environment/tooling,
repositories and revisions, build/staging/recovery procedures, all development
stages, validation evidence and remaining operational instructions. Until then,
keep this backlog, status and experiment records current. Never put credentials,
account hashes, private device logs or calibration backups in public documents.

Relevant evidence: [offline build](experiments/024-offline-release-build.md),
[wake-count diagnosis](experiments/025-automatic-suspend-wakeup-handshake.md),
[supported Wi-Fi hook test](experiments/026-repowerd-wifi-preparation.md).
