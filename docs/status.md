# Status

Latest Restart follow-up: the original four-app combination still crashes
with a50state.3 and official QtMir. The corrected native trace captures SIGBUS
in TopLevelWindowModel::closeAllWindows; a shared stable-ID snapshot candidate
and actual-function ASan regression pass in native build 38061616400.
All four a50state.4 packages are installed and survive a true reboot with an
exact installed-library/archive match. AppArmor Y, read-only root, clean audit,
no failed units and automatic suspend startup pass. The original four-app
menu Restart now passes twice with changed kernel boot IDs and Samsung logos;
the second test runs without the debugger. Both return with zero shell restarts. See [055](experiments/055-restart-close-all-windows.md).

Current checkpoint: 10 October 2026. Development port, not a stable release.

Normal installed suspend startup now passes the bounded unplugged test:
nine deep cycles, 76.719 seconds asleep, zero failures, automatic authorized
USB recovery, user-confirmed screen/touch and actual Wi-Fi HTTPS recovery.
Installed activation also survives repowerd restart. Temporary collectors,
inhibitors and holds are removed; final failed-unit count is zero. Screen-on,
container-death, battery/soak and clean-image/OTA checks remain (048).

Official QtMir ac3ee9 packages replace the local Mir1 DPR workaround and
survive a true reboot. The exact upstream Recents revert fixes proportions in
a user/screenshot-confirmed runtime test. Native ARM64 build 38047817398 passes;
all four conventional Lomiri packages are installed and survive a full reboot
without QML binds, retaining the app reopening backport. The user confirms correct previews and three post-reboot close/reopens
each for Terminal and Settings; a private screenshot agrees and shell
automatic restart count remains zero. Root is read-only, AppArmor is
enabled, audit is clean and no system units fail. One power-menu Restart now
completed a real kernel reboot with Settings/Terminal; repeat the original
Gallery/OpenStore/Morph/YouTube combination before closing the earlier SIGSEGV.
The existing tested autosuspend helper/unit are now permanently installed and
activate normally after a full reboot; normal-startup unplugged validation
now passes as recorded above. Final-image validation remains.
See [048](experiments/048-fresh-unplugged-sleep.md),
[053](experiments/053-upstream-qtmir-scaling.md) and
[054](experiments/054-recents-upstream-revert.md).

OTA is not enabled. Final package/image integration, complete corrected camera
GSI, unified recovery, signed update tests and clean-install/soak checks remain
release blockers. Existing device and unmerged shared fixes must travel in the
image build; a temporary runtime bind or GitHub script does not provide OTA
persistence. Fingerprint and final handoff files remain deferred.

Previous checkpoint: 4 October 2026.
aa17 now passes three awake native USB reconnects and a real four-cycle
deep-suspend/resume test (87.409 seconds, zero failures), recovering authorized
USB without Developer Mode toggles. Screen/touch and Wi-Fi association return.
Actual AppArmor allow/deny, RFCOMM/L2CAP socket creation and normal audio RTKit
scheduling pass. The old -r/-f USB workaround is removed through supported
device configuration, with source fixes, regression and guarded reproduction
published. Remaining charging-mode warning, MTP and clean-image/soak checks are
in [the evidence](experiments/049-usb-native-cable-detection.md).

Fresh Waydroid now initializes through the official defaults; the user confirms
the native icon appears and Android stays open. Basic routing/DNS passes.
The third close/reopen failed while Android stayed running; a supported native
single-instance setting passes three user reopens and icon persistence in a
reversible runtime test. The conventional package build passed and is installed
with a verified official rollback; root is read-only and the source bind removed.
The installed fix survives a real system reboot without a source mount.
Post-reboot user test failed: a launch worked after waiting, but the icon
then disappeared although its file remained visible. A second candidate removes
unnecessary desktop unlinking; its stronger regression and conventional build
pass. Package .2 is installed and survives a real reboot. The user confirms
all three ordinary drawer close/reopens work and the icon stays visible. Four
recorded native launches reach Android-ready. Sleep/audio and wider lifecycle
checks remain ([050](experiments/050-fresh-waydroid.md)).
F-Droid fixed-peer downloads reproduce a slow server on both Ubuntu and Android;
other Android peers are much faster. General browsing/search validation remains
open; no network settings were changed ([052](experiments/052-waydroid-network.md)).
The K380 paired and user-confirmed keyboard input works; actual idle/reconnect/
sleep tests remain ([051](experiments/051-bluetooth-keyboard.md)).

Full Android image build failed at 68% on server disk capacity; no complete
camera-corrected GSI exists yet. A larger conventional builder path is prepared,
but no machine is registered or paid service provisioned. Previous camera
library test mounts ended on reboot. Image/startup integration, Waydroid stability,
OTA/recovery and other release checklist items remain; fingerprint last.
Read [the latest handoff](SESSION-HANDOFF-20.md) and
[release backlog](release-validation-backlog.md). Older checkpoints below
describe earlier installations/builds.

---


Current checkpoint (3 October 2026): the clean 26.04 test image now reaches
the setup wizard, and the user confirmed touch works. The aa13 USB configfs
fix, supported ubuntu.img layout, native LXC hooks and partition-probe typo
correction resolved the early startup failures. Matching Samsung/upstream
ION permissions resolved the remaining desktop allocation failure. The current-source QtMir compatibility build now renders the wizard correctly,
and the user completed onboarding with swipe-only unlocking. Normal QtMir and Settings packages plus their complete signed dependency set
are installed; package audit is clean and the second boot has a read-only root
with no private QtMir override ([040](experiments/040-compatibility-package-repair.md)).
Tar and the official camera compatibility library are installed. The corrected
lock-security page previously allowed the user to choose a private credential.
Terminal's saved hidden window state prevented reopening; a backed-up targeted
repair restored it and the user confirmed it opens. The first shared Lomiri package candidate passed compilation and storage tests
but failed the phone dependency preflight without changing installed packages.
An existing upstream window-state correction is now the preferred backport;
its regression and matching-header native ARM build passed. All four packages
are installed with a clean audit and read-only reboot. The user completed
repeated Terminal/Settings close/reopen checks; the shell remained up with
zero restarts. Wider lifecycle and clean-image/OTA checks remain open ([041](experiments/041-authentication-and-terminal-runtime.md)).
Official Action API dependencies restored Camera loading; the user confirmed photo capture. Video Stop freezes and remains under investigation. Removing a duplicate device HIDL argument restored audio module initialization; a clean reboot still reproduced the video Stop lock. The first upstream lookup backport compiled and removed the callback wait, but Stop still blocks on an AudioFlinger session release. Existing Halium PR 84 addresses both through the shared accessor; its exact-source application check passed and a replacement build is being prepared ([044](experiments/044-recording-audioflinger-backport.md)). YouTube silence also exposed incorrectly packaged audio startup links, corrected in Git; startup links and the missing namespace setting are restored, and the user confirmed normal YouTube sound before and after reboot. Both corrections are in the image overlay ([043](experiments/043-audio-startup-packaging.md)) ([042](experiments/042-camera-dependencies-and-video-stop.md)). The migrated temporary diagnostic unit has been removed through normal authentication.
Ordinary Settings, repeated app lifecycle and shell crashes remain under test.
Recents previews remain distorted and Waydroid is not initialized. See [display comparison](experiments/037-clean-wizard-mir1-scaling.md),
[tar compatibility](experiments/038-tar-openat2-compatibility.md) and
[fresh diagnostics](experiments/039-lock-security-import-regression.md). Fresh AppArmor allow/deny enforcement passed. Native automatic suspend
activation and runtime repowerd restart passed; fresh unplugged sleep/USB
recovery and permanent activation remain open ([047](experiments/047-fresh-suspend-startup-and-readonly-health.md)). A native read-only destination condition resolves the newly observed midnight package-backup failure in runtime and image overlay.
See [release validation](release-validation-backlog.md), [USB diagnosis](experiments/034-clean-boot-usb-configfs.md),
[startup layout](experiments/035-clean-startup-layout.md) and
[ION access](experiments/036-clean-boot-ion-permissions.md). Earlier bring-up
evidence below is historical; this is still a development port.

**Current checkpoint: 2026-10-02.** Development port, not a stable release.

- aa12 plus supported repowerd Wi-Fi preparation completed 35 automatic suspend
  cycles, with zero resume failures. Screen/touch recovery was user-confirmed.
  Three earlier attempts aborted on wake events. The calendar timer passed across-sleep validation; permanent
  integration remain open; see [the measured result](experiments/026-repowerd-wifi-preparation.md).
- The Wi-Fi preparation is now in the build overlay. Disabled-radio, reconnection
  and repowerd restart checks passed; fresh-boot activation remains pending.
  See [overlay validation](experiments/029-wifi-overlay.md).
- AppArmor allow/deny enforcement passed. The guarded test boot restores the old
  fallback image on disk; a reboot into that fallback is not an AppArmor-enabled
  release configuration.
- Clean non-development rootfs and unified recovery candidates were built and
  checked offline. Fresh onboarding, recovery boot, local OTA, channel and
  installer validation remain outstanding.
- Authentication and swipe fixes are confirmed on the development installation.
  The user clarified that Waydroid disappears from the application drawer; an Android crash is not established. The full current checklist is the
  [release validation backlog](release-validation-backlog.md).

## Previous checkpoint: September 22
**Checkpoint: 2026-09-22.** This remains a development port, not a
validated final release. The September 10 inventory below is historical; the
following checkpoint supersedes its AppArmor, suspend, authentication, and
recovery claims.

- **AppArmor:** aa10 and aa11 boot with AppArmor and hardened usercopy. A real
  enforcing-profile allow/deny test passed. Biometry and location services run
  without testing bypasses in runtime overrides. Final-image cleanup remains.
- **Suspend/resume:** aa11 passed freezer, device, and core diagnostics and
  returned from three full suspend attempts without counted resume failures.
  Normal Wi-Fi preparation yielded two 0.011-second sleeps. Preparing earlier
  yielded 0.970 seconds with MIF power-down. Sustained and automatic screen-off
  sleep are not yet validated. Packet-triggered wakes are not established bugs;
  broader wake characterization is deferred at the user's request.
- **Wi-Fi timing:** aa12 source `a50-halium bb78a3b` moves preparation before the
  freezer and restoration after resume/abort. Mock callback tests pass; fresh
  kernel compilation and guarded hardware testing passed the staged diagnostics. A connected-Wi-Fi deep sleep lasted 11.065 seconds; another was immediate and a third aborted at alarmtimer. Automatic screen-off suspend remains unvalidated. See [aa12 evidence](experiments/022-aa12-early-wifi.md).
- **Authentication:** the supported installed polkit legacy helper is configured;
  settings accept credentials. Removing a backed-up stale duplicate local
  account fixed swipe-only unlocking; the user confirmed it works. Fresh-image
  and post-OTA behavior still require validation.
- **Recovery and updates:** conventional UBports recovery/installer/OTA work is
  in progress. TWRP is backed up and remains untouched. System partition sizing,
  recovery packaging, signed local OTA, channel hosting and installer integration
  are still required; GitHub artifacts alone are not an update channel.

## Remaining release agenda

1. Validate earlier Wi-Fi preparation, automatic screen-off suspend and wake,
   and networking after resume. Check long-idle drain before release.
2. Build a clean reproducible image with security/authentication fixes and no
   development permission bypasses; test first-run setup and credential changes.
3. Complete recovery packaging while preserving TWRP access; validate a local
   OTA, a second update, and userdata preservation before enabling a channel.
   Complete UBports Installer configuration and conventional build integration.
4. Stabilize Waydroid. Test Bluetooth keyboard reconnect behavior, VPN,
   Libertine, reset, remaining camera/video and audio paths, and notifications.
   Revisit the reported charging estimate and spontaneous screen wakes when
   reproducible; neither report currently has a proven common cause.
5. Investigate fingerprint last. Capture/enrollment remains unproven.

See [aa11 hardware evidence](experiments/021-aa11-wifi-sleep.md) and
[session handoff](SESSION-HANDOFF-20.md) for the current experiments.

## Historical inventory: September 10
**Last updated: 2026-09-10 (evening).** Ubuntu Touch boots, reaches the UI, and has
working audio, Bluetooth, calls, SMS, mobile data, GPS, USB, a Wi-Fi hotspot
and Waydroid. There is a recovery-flashable installer, and **it has not been
flashed on a phone yet**. This file is the honest inventory.

> **The one claim not to make.** The release
> [`installer-2026-09-08`](https://github.com/sadatdaniel/a50-ubuntu-touch/releases/tag/installer-2026-09-08)
> is **untested on hardware.** Its kernel is boot-proven - it is byte-for-byte
> the image the development device runs - and the rootfs has been mounted and
> checked file by file, and the installer has been run against loop devices
> under `busybox sh`. What nobody has done is flash that zip in TWRP on a phone
> that was on stock Android beforehand, and boot it. Until someone has, the
> release says so and so does this file.
>
> The release ships **two** zips. The `-devel-` one is the same port with sshd
> enabled, root's password set to `1234`, `usb-tethering` on and
> `ADBD_SECURE=0`, so a tester who hits a failure has something to attach to
> the report. That is the one to point people at until the port has been
> installed by somebody other than its author.

## Proven

| Claim | How it was checked |
|---|---|
| **A release image can be built from git plus published UBports artifacts** | `scripts/release/` produces `device_a50.tar.xz`, a 6144M `rootfs.img` (Ubuntu 26.04.1 + the Halium 11 GSI + this port) and a flashable zip. The image was mounted and every port file checked present, executable and correctly targeted; `/etc/resolv.conf` points at NetworkManager and not at a build host's DNS; `android-rootfs.img` is in place; 0 failures. |
| **The debug build's access really works, as shipped** | Checked in the built image, not assumed: the sshd drop-in sorts after `50-lxc-android-config.conf` and re-enables password and root login, `ssh.service` and `usb-tethering.service` are symlinked into `multi-user.target.wants`, `ADBD_SECURE=0`, and `crypt.crypt("1234", hash) == hash` against the `$6$` line actually written into `/etc/shadow`. The installer's `variant=devel` path writes `/userdata/.force-ssh` â€” force-adb's own documented porter marker â€” and that was confirmed present after a full run. |
| **The installer does what it claims, under the toolbox a recovery has** | The finished zip was run against loop devices - a 57,671,680-byte fake boot partition and an 8 GB ext4 `/data` - with `busybox --install` applets first on `PATH` and `busybox sh` as the interpreter. It found both partitions by name, verified the payload against the shipped `SHA256SUMS`, wrote the boot partition and **read it back** to `90c281f8â€¦`, wrote the rootfs and hashed it. Exit 0. |
| **The shipped boot image is the kernel this device runs** | `sha256(boot.img)` = `90c281f8da080f7bc1a9ec9aa822e0ae10bd19a77804717e0c3f6ea83cffd03b`, the same image staged at `/userdata/boot-known-good-waydroid.img` and running now. |
| **`overlay/` was never reaching the device tarball** | The tools do `cp -av overlay/* "${TMP}/"` and then pack only `partitions/ system/`; with the tree laid out as `overlay/etc`, `overlay/usr`, `overlay/var`, all of it landed beside those roots and was dropped. Confirmed by listing a tarball built the old way: 31 entries, all kernel-module metadata. Fixed by moving to `overlay/system/`. |
| **`use_overlaystore` would have silently dropped this port's userspace** | `/usr/libexec/lxc-android-config/mount-halium-overlay`, read on the device, skips any file whose target does not already exist (`WARNING: $targetfile doesn't exist, cannot overlay`). Most of `overlay/` is new files. Option removed, with the quoted code in `deviceinfo`. |
| **A 3584M rootfs image does not fit this port** | Measured: the 26.04 rootfs alone leaves 103 MB free in it, and unpacking the 452 MB Halium GSI then fails with `tar: â€¦ Wrote only 5632 of 10240 bytes`. `deviceinfo_system_partition_size` is 6144M, which leaves 2.0 GB free. |
| **Waydroid does not live on the rootfs** | `mount` shows `/dev/sda32 on /var/lib/waydroid`, via Ubuntu Touch's writable-paths mechanism (`/userdata/system-data/var/lib/waydroid`); `du -sh` there is 3.9 GB, none of it on `/`. The 16 GB rootfs grow done for Waydroid on 2026-09-05 was not needed. `docs/device-provisioning.md` corrected. |
| **The kernel branch `ubuntu-touch-26.04` exists** | Listed by the GitHub API on `sadatdaniel/android_kernel_samsung_exynos9610_mint`, 2026-09-06. The earlier `[?]` was stale. |
| **Ubuntu Touch boots to its UI on this device** | Wizard (language selection) renders; Mir drives the panel at 1080x2340; container `sys.boot_completed=1`; lightdm `NRestarts=0`; verified across a clean reboot. [experiment 006](experiments/006-what-we-missed.md) |
| The display blocker was misc-list corruption, not CMA and not the mutex design | Unguarded double `misc_register()` on a static `miscdevice` in `f_conn_gadget.c` makes `misc_list` circular; `MISCDBG` instrumentation caught `GOTLOCK` with no release. CMA falsified directly: 50 MB freed via `drop_caches`, `mali0` still hung. [experiment 006](experiments/006-what-we-missed.md) |
| The greeter needed `/dev/hwbinder` at `0666` | Compositor (root) worked while greeter (uid 108) failed with `gralloc-mapper is missing`; fixed by `overlay/system/usr/lib/udev/rules.d/99-a50-binder.rules` |
| a50-halium reproduces `074aad86â€¦` from a clean checkout | Fresh `git clone`, fresh container, `sha256sum -c kernel/expected-artifacts.sha256` passes. The toolchain used for this port is therefore the right one. |
| UBports' `mkbootimg` (`LineageOS/android_system_tools_mkbootimg`, `lineage-20.0`) can pack this device's boot image | Repacked `halium-boot-canonical.img`'s own parts with the `deviceinfo` offsets: identical except the 20-byte `id` digest. [experiment 001](experiments/001-bootimg-header.md) |
| a50-droidian's overflowing offsets are genuinely rejected by that tool | `struct.error: 'I' format requires 0 <= number <= 4294967295` |
| `halium-boot-canonical.img` contains exactly the published artifacts | Its kernel hashes to `074aad86â€¦` (a50-halium's pinned `Image`), its ramdisk to `0af4d23fâ€¦` (the canonical ramdisk) |
| The vendor base is Android 11, so Halium 11 | The kernel tree's `build.sh` exports `ANDROID_MAJOR_VERSION="r"` and `PLATFORM_VERSION="11.0.0"` |
| Every boot image header value in `deviceinfo` | Read out of an image that has booted this device |
| No SEAndroid footer, no AVB footer | Last 32 bytes of every known-good A50 boot image are zeros |
| The three artifacts the tools will download all exist | HTTP 200 on the 26.04 rootfs, the Halium 11 GSI and the halium-boot ramdisk, 2026-09-01 |
| **Audio works** | Sound out of the speaker through Ubuntu Touch's normal path, with video unaffected â€” confirmed by ear across clean reboots. Two fixes: `CONFIG_EXTRA_FIRMWARE`, so the DSP gets `calliope_*.bin` at probe (t = 1.43 s, before any filesystem exists here), and presenting the real `hidl_compat` wrapper to PulseAudio host-side, which needed a linker-namespace change to resolve `libaudiohal.so`. The ABOX mixer is left entirely to the HAL. [experiment 007](experiments/007-abox-firmware-too-early.md) |
| **GPS works** | Real satellites through Ubuntu Touch's own stack: `num_svs: 5`, SNR 31-40 dB, `used_in_fix_mask: 15` (four in fix) and `gnssLocationCb` delivering a position once a second, verified from a cold boot with no manual step. Three separate faults, none in the kernel: the AppArmor-gated permission check, `/dev/gnss_ipc` at `0600`, and - the real blocker - `gpsd` waiting forever on `service.bootanim.exit`, which a Halium container never sets because it runs no boot animation. [experiment 009](experiments/009-gps-permissions.md) |
| **Location sessions work** | `CreateSessionForCriteria` returns a session path as `phablet` on a clean boot, and Pure Maps registers as a client. Needed two fixes, neither in the kernel: `TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING` (AppArmor profile resolution cannot work with no AppArmor) and `/dev/gnss_ipc` at `0660 system system`, which the vendor init.gps.rc specifies and the container never applies. **This is not a GPS fix** â€” see the open list. [experiment 009](experiments/009-gps-permissions.md) |
| **Google Maps loads in Morph** | "cannot open intent addresses" was Morph advertising `like Android 9`, so Google served Android deep links. Measured 2 `intent://` links with the token, 0 without. [experiment 010](experiments/010-morph-intent-urls.md) |
| **Waydroid runs Android apps** | Android 13 (LineageOS 20 VANILLA) with the matching `HALIUM_11` vendor image; **F-Droid installed, running, and launchable from the drawer**. Needed: `anbox-*` binder devices compiled in (no binderfs on 4.14), a systemd *user* unit for the session (the bus address is wrong otherwise), a launcher wrapper supplying `DBUS_SESSION_BUS_ADDRESS` (without it tapping an icon silently does nothing), and Waydroid's crash-looping camera provider stopped. [experiment 013](experiments/013-waydroid.md) |
| **Fingerprint: Settings no longer crashes** | Opening Security & Privacy -> Fingerprint used to crash System Settings because biometryd refused every op with `NotPermitted` (the same AppArmor caller-profile wall as GPS). Bypassed with `BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING`; the HAL now enrolls and the TEE is up. **Capture itself does not work yet** - see the blocking list. [experiment 012](experiments/012-fingerprint.md) |
| **Updates no longer spin; PIN is not broken** | Two Settings quirks, both port behaviour not device faults: the updater misdetects Wi-Fi as GSM and refuses the Wi-Fi-only download (workaround `system-image-cli --override-gsm`; no OTA exists for a build-0 GSI anyway), and the PIN-removal dialog rejecting a correct `1234` is a known UBports 26.04 regression - the password matches both PAM stores. [experiment 011](experiments/011-settings-quirks.md) |
| **Bluetooth works** | `hci0` is `UP RUNNING` with the device's own BD address, and `bluetoothctl` discovers real nearby devices with live RSSI, and **earbuds pair and play audio over A2DP** â€” confirmed by the user. Needed `CONFIG_BT` + `CONFIG_BT_HCIVHCI`, restoring the HCI socket layer this vendor tree comments out, and `CONFIG_RFKILL`. The old "CONFIG_BT bootloops this device" result was a misdiagnosis â€” see [experiment 008](experiments/008-bluetooth-hci-sock.md). |
| **The signal strength indicator works** | Shows real bars while idle (15â€“20% at the test location), not only during calls. `ofono-binder-plugin` 1.1.28 maps dBm linearly between `signal_strength_dbm_weak`/`_strong` and returns a hardcoded `1` at or below the low end â€” and its defaults are **-100 / -60 dBm**, which suit RSSI, not the LTE **RSRP** this modem reports. Idle RSRP here is -107..-112 dBm, i.e. under the -100 floor, so it pinned to 1% and showed nothing; during a call it rose above -100 and worked. Fixed with `signalStrengthRange = -120,-75` in `binder.conf`. |
| **Mobile network works â€” SIM detected, registered on LTE** | `Present=true`, `ServiceProviderName="fraenk"`, `NetworkRegistration Status=registered`, `Technology=lte`, `ConnectionManager Attached=true`, on `/ril_0` of a dual-SIM device. Two config files: `OfonoPlugin: binder` in a device yaml that did not exist, and slot definitions in `binder.conf`. No kernel change. |
| **Wi-Fi works, including the UI** | Connects and lists networks. `swlan0`, not `wlan0`, is the interface that carries traffic â€” it is the one NetworkManager activates from boot, and it is normal here, not a fault. The original note said this worked with **no** `/dev/rfkill` and `urfkilld` inactive, falsifying experiment 006's claim that the indicator needed `CONFIG_RFKILL`. That observation still stands historically but **no longer describes the device**: RFKILL is built now (for Bluetooth â€” `bluebinder` needs `/dev/rfkill`), `urfkilld` is active, and a consequence nobody intended is that **flight mode can now switch Wi-Fi off**, which it previously could not. Measured 2026-09-08: `URfkill: handle_flight_mode_killswitch: killswitch[WLAN] â€¦ Setting WLAN devices to blocked` â†’ `NetworkManager: rfkill: Wi-Fi now disabled by radio killswitch`. Harmless in itself, but it means "Wi-Fi died on its own" now has a cause that did not exist before. |
| **USB works from boot** | USB was dead from power-on â€” no RNDIS, no ADB, no gadget at all â€” and the cause was not what the first fix claimed. A `[udev]` drop-in appeared to fix it and an A/B disproved that; the real fix is `USB_MODED_HW_ADAPTATION_ARGS="-f"` in `etc/default/usb-moded.d/device-specific-config.conf`, which stops usb-moded waiting on a cable-detect this hardware never reports. Verified by reboot: RNDIS and ADB come up unattended. |
| **Call audio plays at the right pitch** | The operator's voice came through fast-forwarded and unintelligible. Two consumers were routed to SIFS0 at once: the in-call path and the speaker path, so the DSP drained one stream at twice the rate. `a50-gen-mixer-paths.py` now drops `route-sifs0-to-uaif0` from the speaker paths and reserves `ABOX UAIF2 SPK` on the non-speaker in-call paths. Confirmed by ear on a real call. |
| **Wi-Fi hotspot works** | Every NetworkManager connection add failed, not just the hotspot. `network-manager` 1.54.3 spawns `/usr/libexec/netplan/configure`, a helper introduced in netplan 1.2; the rootfs ships netplan 1.1.2 and does not have it, and NM reported the `ENOENT` as the misleading `netplan generate failed`. Archive version skew, not a device fault â€” it breaks connection adds on every device on this rootfs. Fixed with a shim forwarding to `generate`. `wlan0` reaches `type AP`, `10.42.0.1/24`, dnsmasq serves the range, `nm-shared-wlan0` MASQUERADE is installed, and a second phone associated and got an address. [016](experiments/016-hotspot-netplan.md) |

## Not proven, and blocking

| Open | Why it matters |
|---|---|
| **Suspend: any PM cycle destabilizes the system; nothing triggers suspend either** | The camera open() race is **fixed and verified** (a50-halium `fimc-is-sensor-open-race`, 80-rejection burst test). What remains is worse than 017 described: `pm_test=freezer` â€” the gentlest rung â€” still runs the full `PM_SUSPEND_PREPARE` notifier chain (ABOX powers off, firmware re-downloads, TrustZone workers get `-ERESTARTSYS`), and **3/3 freezer cycles killed the phone within ~2 min**: a kswapd panic (+19 s), an SLSI Wi-Fi scan panic (+2 min), and a silent whole-system lockup (+10 s, Wi-Fi radio off). Meanwhile 38 stressed scans plus hours of background scans never crash it. The earlier "freezer passes" and "device does not resume" claims were both half-wrong â€” the kernel *does* resume from `mem` (RSTCNT/uptime prove it); **USB, Wi-Fi and the display are what die across suspend**. `nmcli radio wifi off` does not exonerate wlbt (driver stays loaded). Separately, nothing ever auto-triggers suspend: `/sys/power/autosleep` does not exist and the suspend HAL loop is never enabled; repowerd's legacy backend has never fired. Idle drain ~38 mA. [018](experiments/018-suspend-freezer-wifi-instability.md), [017](experiments/017-suspend-camera-panic.md) |
| **A bare `make <defconfig>` kernel has not been boot-tested** | It is how the tools build kernels, so it gates official CI and an update channel. **The config half is now solved** (2026-09-09): a `savedefconfig` of the boot-proven `.config` plus `ANDROID_MAJOR_VERSION=r` reproduces that config exactly under a bare `make` â€” 1962 symbols, 0 lost, 0 gained. Without the variable 3 symbols vanish silently, one of them `CONFIG_USB_F_CONN_GADGET_NDOP`, the driver behind this port's original display blocker. So the tools need one exported variable, not a patch. **The boot test has not been done**, and the toolchain still differs (risk 3), so the `Image` is not claimed to match. [`kernel.md`](kernel.md) risk 1 |
| **`console=tty0` cannot be delivered via `deviceinfo_kernel_cmdline`** | S-Boot ignores the boot image command line. [`kernel.md`](kernel.md) risk 2. |
| **The tools use Google's prebuilt Clang, not the pinned Proton Clang** | A second changed variable sitting under risk 1. [`kernel.md`](kernel.md) risk 3. |
| **Does S-Boot check the boot header `id` digest?** | The one field experiment 001 could not reproduce. One boot test. |
| **AppArmor** | Not built, and a kernel adding it as default LSM **does not boot** â€” fails before USB enumeration. No longer blocks GPS. [experiment 009](experiments/009-gps-permissions.md), [008 appendix](experiments/008-bluetooth-hci-sock.md) |
| **Fingerprint capture** | HBM is **solved** - a 13-line kernel patch (`decon-force-mask-layer`) makes `actual_mask_brightness` go 0-&gt;255 on demand, running the vendor's own TE-synced sequence. But the sensor still reports no finger: the HAL opens a ~150 ms SPI window for the trustlet to bring the ET713 up, that fails, and it therefore never issues `INT_TRIGGER_INIT` - so no DRDY interrupt is registered and `nd cnt` can never leave 0. No fingerprint calibration data exists under `/mnt/vendor/efs`, which may be why. [experiment 012](experiments/012-fingerprint.md) |
| **The initramfs fixes have not been ported** | Four are expected to be needed. `ramdisk-overlay/README.md`. |
| **`conn_gadget` double-registration is avoided, not fixed** | The container is kept away from USB gadget configfs. The real fix is an idempotency guard in `conn_gadget_setup()`, still unwritten to the kernel branch. |
| **The `ld.config.txt` rewrite in the audio fix** | `a50-audio-hidl-compat.service` patches generated linker config on every boot so the HAL wrapper can resolve `libaudiohal.so`. The system HIDL wrapper needs the system namespace; its omitted PulseAudio override is restored and audio is reboot-verified ([043](experiments/043-audio-startup-packaging.md)). The generated linker allowlist rewrite still needs an upstream replacement. [experiment 007](experiments/007-abox-firmware-too-early.md) Â§26 |
| **Headphones / earpiece** | Only the speaker path has been exercised. UAIF0 is the codec path and is untested. |
| **Camera: HAL works, app crashes** | The old "panics the kernel" hazard **is real after all** â€” see [017](experiments/017-suspend-camera-panic.md); it is triggered by a stale `vctx` from a previous open/close cycle, which suspend/resume produces, not by enumeration. Enumeration itself is clean: all 50 V4L2 nodes opened + `QUERYCAP` with no crash, and `gst-plugin-scan` is not even installed. Everything below the app is proven working: sensor drivers probe (`cis_2x5_probe done`, deferred list empty), the Samsung HAL enumerates 3 cameras, and **from Ubuntu Touch** `android_camera_connect_by_id()` succeeds returning **16 preview + 33 picture sizes** (to 5760Ã—4320). Fixed the app's missing `libexiv2.so.27`, without which it could not load its own QML plugin. It now reaches the camera and renders a frame, then **segfaults**: the AAL viewfinder never picks up the preview sizes the HAL offers (`QSize(-1,-1)`), and `AalImageCaptureControl::onPreviewReady()` does not exist in the installed plugin. Upstream UT media-layer mismatch, not device-specific. [experiment 014](experiments/014-camera.md) |

## Deliberately not started

* **UBports recovery.** `deviceinfo_has_recovery_partition` is false. TWRP is
  well tested on this device and is the only reliable way back, and building a
  second recovery would put that at risk for no gain.
* **The UBports Installer.** It flashes over fastboot or heimdall against a
  registered device in `ubports/installer-configs`; this port has neither a
  system-image channel nor an upstream device entry. The flashable zip is the
  substitute, and `installer/README.md` explains why the shape differs.
  Nothing about this being a Samsung blocks it: `herolte` (Galaxy S7 Exynos) is
  already in `ubports/installer-configs` and installs with `heimdall:flash`,
  pulling its images from a GitHub release with sha256 checksums, which is the
  shape this port already publishes. The missing pieces are only the channel and
  the device entry. Note the guide itself stops short here â€”
  `porting/finalize/UBports_installer.rst` says *"For Halium-9.0, exact steps
  are not available at this time"* â€” so the convention has to be read off
  existing ports and `gsi-port-ci.yml` rather than the documentation.
* **An OTA channel.** Nothing serves `26.04-1.x/.../a50`, so Settings ->
  Updates finds nothing. Updating means reflashing - or, for a kernel-only
  change, `dd` from a running system.
* **The rootfs on `system` instead of `/data/rootfs.img`.** This is the one
  place the port knowingly differs from the shape UBports' own tooling
  publishes, and it is worth stating plainly because the documentation calls it
  out by name. `porting/finalize/index.rst`: *"Previously, your port has had the
  rootfs and system image coexisting on the userdata partition. These need to be
  moved to the system partition."* This port writes
  `ROOTFS_TARGET=/data/rootfs.img`, so by that definition it is pre-finalization.
  The shared port pipeline
  ([`gsi-port-ci.yml`](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools/-/blob/main/gsi-port-ci.yml))
  publishes `boot.img`, `dtbo.img`, `recovery.img` and **`ubuntu.img.zst`**, and
  established GSI ports flash that to the system partition
  (`fastboot flash system_a ./ubuntu.img`). **Measured on the device, so this is
  known to be possible rather than assumed:**

  | | |
  |---|---|
  | `system` partition | **5300 MiB** â€” a real partition; this device has no super/dynamic partition |
  | this port's image | 6144 MiB, which does **not** fit |
  | content actually in that image | ~4.1 GB, which **does** fit, with ~1.2 GB spare |

  So the move is a rebuild at a smaller size plus an initramfs that mounts the
  rootfs from `system`, not a redesign. It would also hand ~6 GB back to
  `/userdata`. Not started, not blocked.

## A standing hazard, not a task

Getting from running Linux back to TWRP is **unreliable on this device**:
`systemctl reboot --reboot-argument=recovery` sometimes works and sometimes
reboots straight back into Linux (three successes then four failures in one
session). The AOSP bootloader control block is ignored by S-Boot â€” tested â€” and
glibc's `reboot()` cannot pass `recovery` at all.

Never end a session with the device bootlooping, and keep a known-good boot
image within reach before every flash. Published with hashes in a50-droidian,
release `boot-images-2026-09-01`.
