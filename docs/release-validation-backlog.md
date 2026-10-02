# Release validation backlog

Updated 2026-10-02. Ubuntu Touch 26.04 only. This remains a development port.
Research existing upstream implementations first; prefer supported UBports
configuration and narrowly scoped device adaptations. Record source references,
reproduction, validation and rollback for every fix, and publish the scripts.

| Area | Current evidence | Required before stable release |
| --- | --- | --- |
| Suspend/resume | aa12 plus supported repowerd Wi-Fi hooks completed 30 automatic cycles, zero resume failures; user confirmed screen/touch | Resolve timer deadline issue using upstream solution; repeated cycles, network recovery, screen-on inhibition, service restart and battery drain; reproducible permanent enablement |
| AppArmor | Real allowed/denied file-access probe passes on aa12; normal biometry/location permissions work | Final image must boot the hardened kernel by default, remove testing bypasses, verify application confinement after clean install and OTA |
| Authentication | Installed polkit's supported legacy helper fixed password validation; duplicate local account removal fixed swipe; user confirmed PIN/swipe | Clean-image and reboot/OTA tests for passphrase, PIN, swipe; preserve authentication protection and package-managed ownership |
| First-run setup | Clean non-development rootfs built and audited offline | Fresh install, setup wizard, user-chosen credentials, no development SSH/default password, second boot |
| Recovery and OTA | Unified recovery candidate built and checked offline; TWRP backup retained; no candidate recovery flash yet | Conventional layout/build pipeline, safe recovery boot test, signed local OTA, second update and userdata preservation, signed channel hosting, installer configuration |
| Waydroid | Runs apps, but user still reports intermittent crashes | Diagnose actual crashes against upstream fixes; repeated launches/stops, network/audio, sleep/wake, compositor restart, extended use; remove stopgap adaptations only after valid replacements |
| Bluetooth keyboard | User reports unsolicited disconnect/reconnect | Capture controller/connection logs; idle, typing, reconnect and suspend tests |
| VPN | Untested | Supported VPN configuration, routing/DNS, reconnect and sleep/wake |
| Libertine | Untested | Container creation, package install, application launch/input and reboot persistence |
| Factory reset | Untested | Disposable test data or verified backup; recovery operation, clean onboarding and no unintended partition loss |
| Camera/video and audio | Basic audio/calls have worked; video remains broken | Capture/playback, call and media routing, Bluetooth audio, recovery after sleep |
| Notifications | Current push packages installed; end-to-end test outstanding | Delivery while awake/asleep, wake behavior and application permissions |
| Charging estimate | User reports inaccurate lock-screen time to full; low priority | Compare lock-screen, indicator and battery-provider values at the same time; fix the responsible layer using upstream behavior |
| Fingerprint | Driver and enrollment path exist; successful capture/enrollment unproven | Investigate last; preserve calibration and trusted firmware; advertise unavailable unless verified |

The next immediate step is validating the conventional calendar-timer workaround
for systemd issue #29245, followed by completing suspend integration. Then close
the clean-image/OTA release blockers and the remaining functional checks above.
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
