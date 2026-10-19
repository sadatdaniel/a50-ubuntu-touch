# Release validation backlog

Updated 2026-10-17. Ubuntu Touch 26.04 only. This remains a development port.
Research existing upstream implementations first; prefer supported UBports
configuration and narrowly scoped device adaptations. Record source references,
reproduction, validation and rollback for every fix, and publish the scripts.

| Area | Current evidence | Required before stable release |
| --- | --- | --- |
| Suspend/resume | aa12 plus supported repowerd Wi-Fi hooks completed 35 automatic cycles, zero resume failures; user confirmed screen/touch | Calendar timer passed across sleep; repeated cycles, network recovery, screen-on inhibition, service restart and battery drain; reproducible permanent enablement. Fresh aa13 completed two deep cycles totaling 89.765 seconds, zero failures; screen/touch and Wi-Fi association recovered. aa17 follow-up completed four deep cycles (87.409 seconds), zero failures, with automatic USB recovery and normal screen/touch/Wi-Fi association. The exact overlay helper/unit are now installed and activate after a full normal reboot; current-image normal-startup test passes nine deep cycles (76.719 seconds), zero failures, automatic USB, screen/touch and Wi-Fi HTTPS recovery; installed activation survives repowerd restart. Screen-on, container-death, battery/soak and rebuilt clean-image validation remain ([048](experiments/048-fresh-unplugged-sleep.md)) |
| AppArmor | Real allowed/denied file-access probe passed on aa16/aa17; the overnight aa17 check retained AppArmor enabled with a clean audit ([049](experiments/049-usb-native-cable-detection.md), [057](experiments/057-overnight-observation.md)) | Verify confinement and permissions in the clean candidate and after OTA, with testing bypasses absent |
| Authentication | User-confirmed PIN/swipe transitions work on the running port after the AccountsService duplicate-account correction; polkit uses its kernel-4.14-compatible supported legacy helper | Recheck passphrase/PIN/swipe, permissions and first-run behavior in the actual clean candidate and after OTA; do not change the approved authentication model ([041](experiments/041-authentication-and-terminal-runtime.md)) |
| First-run setup | Setup wizard and touch worked after the native Samsung ION rule; language-list clipping was corrected; PIN and swipe-only were user-tested | Repeat the full wizard on the clean integrated image with user-selected credentials; verify normal developer authorization and a second boot ([037](experiments/037-clean-wizard-mir1-scaling.md)) |
| Reproducible inputs | GSI 1542 is gone from Jenkins (~30-build retention); only the local copy remains. all 18 cohort archives preserved on host; fresh-rootfs cohort install passes after the installer `--no-download` fix; fresh rootfs downgrades QtMir/Settings and differs from the phone in 184 other packages ([060](experiments/060-upstream-input-retention.md)) | Durable release-asset archive of GSI, rootfs and cohort; gated fresh-rootfs cohort test passes; re-pin the corrected GSI to a current build with PR 84 |
| Recovery and OTA | Unified recovery candidate built and checked offline; TWRP backup retained; no candidate recovery flash yet | Conventional layout/build pipeline, safe recovery boot test, signed local OTA, second update and userdata preservation, signed channel hosting, installer configuration |
| Waydroid | Native single-instance launcher survives full reboot and three user drawer close/reopens; existing window passed both short unplugged sleep and overnight resume; Android 13 official image initialized ([050](experiments/050-fresh-waydroid.md), [057](experiments/057-overnight-observation.md)) | Camera-provider loop fixed by system-overlay `.rc` ([061](experiments/061-waydroid-camera-overlay.md)); daemon fd leak fix `fdclose.1` installed, soak then lock ([062](experiments/062-waydroid-fd-leak.md)); revalidate on clean image; extended use, network throughput, compositor restart and repeat sleep/return; Android camera remains unsupported |
| USB recovery and detection | aa17 native DWC3 state fix passes awake cable reconnects and unplugged suspend/USB recovery; no Developer Mode toggle was needed in the latest tests ([049](experiments/049-usb-native-cable-detection.md)) | Validate remaining USB modes and repeat from the clean candidate image |
| Bluetooth keyboard | aa13 lacks RFCOMM despite its enabled kernel config. The standard RFCOMM/BNEP/HIDP correction is included in aa16/aa17. Actual RFCOMM/L2CAP socket creation passes on aa16. K380 pairs and user confirms typing on aa17; Linux input device exists ([051](experiments/051-bluetooth-keyboard.md)) | Validate keyboard idle/typing/reconnect/suspend. Missing RFCOMM is evidence of a kernel defect, not proof of the keyboard cause |
| Graphical Restart and Recents | Installed a50state.4 snapshot fix plus official QtMir scaling/Recents changes survive full reboot; correct previews and Terminal/Settings reopen confirmed. Original four-app graphical Restart passed twice with Samsung logos, changed boot IDs and zero Lomiri restarts ([053](experiments/053-qt-mir-dpr.md), [054](experiments/054-recents-preview-scaling.md), [055](experiments/055-restart-close-all-windows.md)) | Recheck on the clean candidate image and after OTA; validate logout/shutdown and broader app combinations |
| Telephony and location | Earlier modem/permission work is documented; full fresh-image functionality is not established | Calls, SMS, mobile data, hotspot, GNSS and emergency behavior where safely testable; document unavailable features accurately |
| VPN | Untested | Supported VPN configuration, routing/DNS, reconnect and sleep/wake |
| Libertine | Untested | Container creation, package install, application launch/input and reboot persistence |
| Factory reset | Untested | Disposable test data or verified backup; recovery operation, clean onboarding and no unintended partition loss |
| OOM and memory pressure | Isolated 64 MiB memory-cgroup test killed only its disposable worker; a later allocation succeeded ([058](experiments/058-isolated-oom-recovery.md)) | This does not prove global OOM or Android LMK handling; obtain the pending owner responsiveness report and consider a bounded user-level pressure test only after reviewing risk |
| Camera/video and audio | **Fixed upstream:** Halium PR 84 merged; GSI 1585 pinned. Owner confirms record → Stop → playback, sound and lock screen from a cold boot without temporary mounts ([063](experiments/063-gsi-1585-camera.md)) | Repeat recordings and after reboot; call/Bluetooth/sleep audio on 1585; confirm in the clean candidate image |
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
