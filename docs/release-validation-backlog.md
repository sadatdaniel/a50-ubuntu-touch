# Release validation backlog

Updated 2026-10-04. Ubuntu Touch 26.04 only. This remains a development port.
Research existing upstream implementations first; prefer supported UBports
configuration and narrowly scoped device adaptations. Record source references,
reproduction, validation and rollback for every fix, and publish the scripts.

| Area | Current evidence | Required before stable release |
| --- | --- | --- |
| Suspend/resume | aa12 plus supported repowerd Wi-Fi hooks completed 35 automatic cycles, zero resume failures; user confirmed screen/touch | Calendar timer passed across sleep; repeated cycles, network recovery, screen-on inhibition, service restart and battery drain; reproducible permanent enablement. Fresh aa13 completed two deep cycles totaling 89.765 seconds, zero failures; screen/touch and Wi-Fi association recovered. aa17 follow-up completed four deep cycles (87.409 seconds), zero failures, with automatic USB recovery and normal screen/touch/Wi-Fi association. Tested activation is now packaged in the overlay but its clean-boot behavior remains pending ([048](experiments/048-fresh-unplugged-sleep.md)) |
| AppArmor | Real allowed/denied file-access probe passes on aa12 and the fresh aa13 installation (3 October); normal biometry/location permissions worked in earlier tests | Final image must boot the hardened kernel by default, remove testing bypasses, verify application confinement after clean install and OTA |
| Authentication | Installed polkit's supported legacy helper fixed password validation; duplicate local account removal fixed swipe; user confirmed PIN/swipe | Resolve fresh LockSecurity.qml import failure ([039](experiments/039-lock-security-import-regression.md)); isolated correction and full temporary panel pass; user chose a private credential, conventional Settings package installed and read-only reboot passed; failed-auth CPU loop, hidden-state reopening repair and shared fix candidate are tracked in [041](experiments/041-authentication-and-terminal-runtime.md). Test passphrase/PIN/swipe and reboot/OTA; preserve authentication protection and package-managed ownership |
| First-run setup | Clean 26.04 image 376 reaches setup with touch confirmed after aa13 USB fix, supported ubuntu.img layout, native LXC hooks, schedtune correction and Samsung/upstream ION rule | Wizard display is user-confirmed with the current-source QtMir test library ([037](experiments/037-clean-wizard-mir1-scaling.md)); swipe-only onboarding completed. Normal QtMir packages installed and read-only reboot passed; resolve Recents rendering, user-chosen credentials, normal developer authorization, remove temporary diagnostics, second boot |
| Recovery and OTA | Unified recovery candidate built and checked offline; TWRP backup retained; no candidate recovery flash yet | Conventional layout/build pipeline, safe recovery boot test, signed local OTA, second update and userdata preservation, signed channel hosting, installer configuration |
| Waydroid | Old install: Gio/LAL listed the missing launcher with no service restarts. Fresh install: official initialization completed; native visible launcher opens, Android 13 boot and basic routing/DNS pass; third close/reopen failed with Android still running. Native single-instance runtime candidate passes three user reopens; conventional package build/install passed, source bind removed and real reboot persistence passed; post-reboot user test failed (delayed reopening and missing icon); second candidate preserves launcher file, regression passes and hardware validation pending ([050](experiments/050-fresh-waydroid.md)) | Reproduce launcher disappearance and distinguish drawer cache from desktop-file changes; repeated launches/stops, network/audio, sleep/wake, compositor restart, extended use; remove stopgap adaptations only after valid replacements |
| USB recovery and detection | Debugging needed a Developer Mode toggle after deep sleep. Native manager startup without old -r/-f passed, then timed rollback restored baseline; no confirmed cable cycle under the candidate | aa16 native USB ONLINE events and adbd lifecycle passed; stale DWC3 pull-up state still blocked enumeration. aa17 passed three awake reconnects and USB recovery after four real deep cycles, without Developer Mode toggles. Native USB configuration replaces -r/-f. Test awake reconnect, sleep/reconnect, modes and clean boot ([049](experiments/049-usb-native-cable-detection.md)) |
| Bluetooth keyboard | aa13 lacks RFCOMM despite its enabled kernel config. The standard RFCOMM/BNEP/HIDP correction is included in aa16/aa17. Actual RFCOMM/L2CAP socket creation passes on aa16. K380 pairs and user confirms typing on aa17; Linux input device exists ([051](experiments/051-bluetooth-keyboard.md)) | Validate keyboard idle/typing/reconnect/suspend. Missing RFCOMM is evidence of a kernel defect, not proof of the keyboard cause |
| Graphical Restart and Recents | User reports Restart reloads the shell; normal authenticated reboot changes kernel boot ID. Recents distortion remains reported | Trace the normal menu/window-close path; verify a real boot-ID change. Correct rendering against the installed Mir/Qt family using upstream evidence |
| Telephony and location | Earlier modem/permission work is documented; full fresh-image functionality is not established | Calls, SMS, mobile data, hotspot, GNSS and emergency behavior where safely testable; document unavailable features accurately |
| VPN | Untested | Supported VPN configuration, routing/DNS, reconnect and sleep/wake |
| Libertine | Untested | Container creation, package install, application launch/input and reboot persistence |
| Factory reset | Untested | Disposable test data or verified backup; recovery operation, clean onboarding and no unintended partition loss |
| Camera/video and audio | Exact open Halium PR 84 shared AudioFlinger accessor correction passed three user Stop/playback tests with picture and sound; all three private samples decode cleanly ([044](experiments/044-recording-audioflinger-backport.md)). YouTube audio survives reboot ([043](experiments/043-audio-startup-packaging.md)) | Full pinned GSI build [37172560900](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37172560900) failed on runner disk capacity at 68%; a larger conventional build environment is required. Library mounts disappeared on aa16 reboot. Validate complete Android image, cold boot, recording modes, calls/media/Bluetooth routing and sleep. aa15 realtime configuration is validated on aa16/aa17 descendants; RTKit grants audio priority 5 ([045](experiments/045-post-audio-health.md)) |
| Notifications | Fresh installation has qml-module-lomiri-notifications 1.4.0 (September 21 build), push service 0.100.3 and live shell notification interface; end-to-end test outstanding | Delivery while awake/asleep, wake behavior and application permissions |
| Charging estimate | User reports inaccurate lock-screen time to full; low priority | Compare lock-screen, indicator and battery-provider values at the same time; fix the responsible layer using upstream behavior |
| Fingerprint | Driver and enrollment path exist; successful capture/enrollment unproven | Investigate last; preserve calibration and trusted firmware; advertise unavailable unless verified |

The conventional calendar-timer workaround passed auto9. Clean setup now renders after experiments 034–036; complete onboarding and a second boot,
then rerun confinement and suspend startup on the fresh image. Waydroid is now initialized from fresh official images; complete its lifecycle
validation without the erased old Helper/Android state. Close the
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

## Release order and update resilience

1. Validate fresh automatic sleep, display/touch, Wi-Fi/USB recovery and power
   service restarts; package the proven activation through normal startup.
2. aa15 scheduling/protocol availability is validated through aa16/aa17; test
   actual Bluetooth keyboard input, idle, reconnect and sleep.
3. Complete the pinned Android image containing PR 84; test boot and camera
   without temporary library mounts. Integrate matching Lomiri/Settings packages
   and all validated device overlays into the normal image build.
4. Initialize the shipped Waydroid package using the
   [official UBports procedure](https://docs.ubports.com/en/latest/userguide/dailyuse/waydroid.html).
   Android images/user state are separate from the preinstalled package. Test
   launcher persistence and the former disappearance report from this clean state.
5. Validate unified recovery and the final storage layout; test two signed local
   updates and retained userdata, then a maintained signed channel and Samsung
   installer flow. See [OTA finalization](ota-finalization.md).
6. Wipe/install the candidate built from recorded inputs and test the checklist
   from first boot, with no manual repair scripts. Repeat key checks after OTA.
7. Finish remaining functional/soak checks, with fingerprint last; publish final
   developer handoff documents once the checklist is resolved.

Shared bugs should be fixed upstream. Until accepted fixes reach compatible
packages/images, maintain their exact backports and build inputs in Git. Device
adaptations belong in the kernel/device tarball and supported DeviceInfo or
startup hooks. Updates must carry those artifacts alongside the rootfs. Merely
editing the installed phone does not preserve a fix across image replacement.

Record rootfs, kernel, Android image, recovery, package versions and checksums
for each candidate; use a testing channel before promotion. Exercise clean boot
and OTA regressions against the next upstream rootfs. No process guarantees
that an upstream update cannot regress, and permanent global package freezes
are not a substitute for maintaining compatibility. Keep signature checks and
confinement enabled, vendor intact, and maintenance access opt-in.
