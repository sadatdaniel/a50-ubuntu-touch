# Status

**Last updated: 2026-09-06.** Ubuntu Touch boots, reaches the UI, and has
working audio, Bluetooth, calls, mobile data, GPS and Waydroid. There is now a
recovery-flashable installer, and **it has not been flashed on a phone yet**.
This file is the honest inventory.

> **The one claim not to make.** The release
> [`installer-2026-09-06`](https://github.com/sadatdaniel/a50-ubuntu-touch/releases/tag/installer-2026-09-06)
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
| **The debug build's access really works, as shipped** | Checked in the built image, not assumed: the sshd drop-in sorts after `50-lxc-android-config.conf` and re-enables password and root login, `ssh.service` and `usb-tethering.service` are symlinked into `multi-user.target.wants`, `ADBD_SECURE=0`, and `crypt.crypt("1234", hash) == hash` against the `$6$` line actually written into `/etc/shadow`. The installer's `variant=devel` path writes `/userdata/.force-ssh` — force-adb's own documented porter marker — and that was confirmed present after a full run. |
| **The installer does what it claims, under the toolbox a recovery has** | The finished zip was run against loop devices - a 57,671,680-byte fake boot partition and an 8 GB ext4 `/data` - with `busybox --install` applets first on `PATH` and `busybox sh` as the interpreter. It found both partitions by name, verified the payload against the shipped `SHA256SUMS`, wrote the boot partition and **read it back** to `90c281f8…`, wrote the rootfs and hashed it. Exit 0. |
| **The shipped boot image is the kernel this device runs** | `sha256(boot.img)` = `90c281f8da080f7bc1a9ec9aa822e0ae10bd19a77804717e0c3f6ea83cffd03b`, the same image staged at `/userdata/boot-known-good-waydroid.img` and running now. |
| **`overlay/` was never reaching the device tarball** | The tools do `cp -av overlay/* "${TMP}/"` and then pack only `partitions/ system/`; with the tree laid out as `overlay/etc`, `overlay/usr`, `overlay/var`, all of it landed beside those roots and was dropped. Confirmed by listing a tarball built the old way: 31 entries, all kernel-module metadata. Fixed by moving to `overlay/system/`. |
| **`use_overlaystore` would have silently dropped this port's userspace** | `/usr/libexec/lxc-android-config/mount-halium-overlay`, read on the device, skips any file whose target does not already exist (`WARNING: $targetfile doesn't exist, cannot overlay`). Most of `overlay/` is new files. Option removed, with the quoted code in `deviceinfo`. |
| **A 3584M rootfs image does not fit this port** | Measured: the 26.04 rootfs alone leaves 103 MB free in it, and unpacking the 452 MB Halium GSI then fails with `tar: … Wrote only 5632 of 10240 bytes`. `deviceinfo_system_partition_size` is 6144M, which leaves 2.0 GB free. |
| **Waydroid does not live on the rootfs** | `mount` shows `/dev/sda32 on /var/lib/waydroid`, via Ubuntu Touch's writable-paths mechanism (`/userdata/system-data/var/lib/waydroid`); `du -sh` there is 3.9 GB, none of it on `/`. The 16 GB rootfs grow done for Waydroid on 2026-09-05 was not needed. `docs/device-provisioning.md` corrected. |
| **The kernel branch `ubuntu-touch-26.04` exists** | Listed by the GitHub API on `sadatdaniel/android_kernel_samsung_exynos9610_mint`, 2026-09-06. The earlier `[?]` was stale. |
| **Ubuntu Touch boots to its UI on this device** | Wizard (language selection) renders; Mir drives the panel at 1080x2340; container `sys.boot_completed=1`; lightdm `NRestarts=0`; verified across a clean reboot. [experiment 006](experiments/006-what-we-missed.md) |
| The display blocker was misc-list corruption, not CMA and not the mutex design | Unguarded double `misc_register()` on a static `miscdevice` in `f_conn_gadget.c` makes `misc_list` circular; `MISCDBG` instrumentation caught `GOTLOCK` with no release. CMA falsified directly: 50 MB freed via `drop_caches`, `mali0` still hung. [experiment 006](experiments/006-what-we-missed.md) |
| The greeter needed `/dev/hwbinder` at `0666` | Compositor (root) worked while greeter (uid 108) failed with `gralloc-mapper is missing`; fixed by `overlay/system/usr/lib/udev/rules.d/99-a50-binder.rules` |
| a50-halium reproduces `074aad86…` from a clean checkout | Fresh `git clone`, fresh container, `sha256sum -c kernel/expected-artifacts.sha256` passes. The toolchain used for this port is therefore the right one. |
| UBports' `mkbootimg` (`LineageOS/android_system_tools_mkbootimg`, `lineage-20.0`) can pack this device's boot image | Repacked `halium-boot-canonical.img`'s own parts with the `deviceinfo` offsets: identical except the 20-byte `id` digest. [experiment 001](experiments/001-bootimg-header.md) |
| a50-droidian's overflowing offsets are genuinely rejected by that tool | `struct.error: 'I' format requires 0 <= number <= 4294967295` |
| `halium-boot-canonical.img` contains exactly the published artifacts | Its kernel hashes to `074aad86…` (a50-halium's pinned `Image`), its ramdisk to `0af4d23f…` (the canonical ramdisk) |
| The vendor base is Android 11, so Halium 11 | The kernel tree's `build.sh` exports `ANDROID_MAJOR_VERSION="r"` and `PLATFORM_VERSION="11.0.0"` |
| Every boot image header value in `deviceinfo` | Read out of an image that has booted this device |
| No SEAndroid footer, no AVB footer | Last 32 bytes of every known-good A50 boot image are zeros |
| The three artifacts the tools will download all exist | HTTP 200 on the 26.04 rootfs, the Halium 11 GSI and the halium-boot ramdisk, 2026-09-01 |
| **Audio works** | Sound out of the speaker through Ubuntu Touch's normal path, with video unaffected — confirmed by ear across clean reboots. Two fixes: `CONFIG_EXTRA_FIRMWARE`, so the DSP gets `calliope_*.bin` at probe (t = 1.43 s, before any filesystem exists here), and presenting the real `hidl_compat` wrapper to PulseAudio host-side, which needed a linker-namespace change to resolve `libaudiohal.so`. The ABOX mixer is left entirely to the HAL. [experiment 007](experiments/007-abox-firmware-too-early.md) |
| **GPS works** | Real satellites through Ubuntu Touch's own stack: `num_svs: 5`, SNR 31-40 dB, `used_in_fix_mask: 15` (four in fix) and `gnssLocationCb` delivering a position once a second, verified from a cold boot with no manual step. Three separate faults, none in the kernel: the AppArmor-gated permission check, `/dev/gnss_ipc` at `0600`, and - the real blocker - `gpsd` waiting forever on `service.bootanim.exit`, which a Halium container never sets because it runs no boot animation. [experiment 009](experiments/009-gps-permissions.md) |
| **Location sessions work** | `CreateSessionForCriteria` returns a session path as `phablet` on a clean boot, and Pure Maps registers as a client. Needed two fixes, neither in the kernel: `TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING` (AppArmor profile resolution cannot work with no AppArmor) and `/dev/gnss_ipc` at `0660 system system`, which the vendor init.gps.rc specifies and the container never applies. **This is not a GPS fix** — see the open list. [experiment 009](experiments/009-gps-permissions.md) |
| **Google Maps loads in Morph** | "cannot open intent addresses" was Morph advertising `like Android 9`, so Google served Android deep links. Measured 2 `intent://` links with the token, 0 without. [experiment 010](experiments/010-morph-intent-urls.md) |
| **Waydroid runs Android apps** | Android 13 (LineageOS 20 VANILLA) with the matching `HALIUM_11` vendor image; **F-Droid installed, running, and launchable from the drawer**. Needed: `anbox-*` binder devices compiled in (no binderfs on 4.14), a systemd *user* unit for the session (the bus address is wrong otherwise), a launcher wrapper supplying `DBUS_SESSION_BUS_ADDRESS` (without it tapping an icon silently does nothing), and Waydroid's crash-looping camera provider stopped. [experiment 013](experiments/013-waydroid.md) |
| **Fingerprint: Settings no longer crashes** | Opening Security & Privacy -> Fingerprint used to crash System Settings because biometryd refused every op with `NotPermitted` (the same AppArmor caller-profile wall as GPS). Bypassed with `BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING`; the HAL now enrolls and the TEE is up. **Capture itself does not work yet** - see the blocking list. [experiment 012](experiments/012-fingerprint.md) |
| **Updates no longer spin; PIN is not broken** | Two Settings quirks, both port behaviour not device faults: the updater misdetects Wi-Fi as GSM and refuses the Wi-Fi-only download (workaround `system-image-cli --override-gsm`; no OTA exists for a build-0 GSI anyway), and the PIN-removal dialog rejecting a correct `1234` is a known UBports 26.04 regression - the password matches both PAM stores. [experiment 011](experiments/011-settings-quirks.md) |
| **Bluetooth works** | `hci0` is `UP RUNNING` with the device's own BD address, and `bluetoothctl` discovers real nearby devices with live RSSI, and **earbuds pair and play audio over A2DP** — confirmed by the user. Needed `CONFIG_BT` + `CONFIG_BT_HCIVHCI`, restoring the HCI socket layer this vendor tree comments out, and `CONFIG_RFKILL`. The old "CONFIG_BT bootloops this device" result was a misdiagnosis — see [experiment 008](experiments/008-bluetooth-hci-sock.md). |
| **The signal strength indicator works** | Shows real bars while idle (15–20% at the test location), not only during calls. `ofono-binder-plugin` 1.1.28 maps dBm linearly between `signal_strength_dbm_weak`/`_strong` and returns a hardcoded `1` at or below the low end — and its defaults are **-100 / -60 dBm**, which suit RSSI, not the LTE **RSRP** this modem reports. Idle RSRP here is -107..-112 dBm, i.e. under the -100 floor, so it pinned to 1% and showed nothing; during a call it rose above -100 and worked. Fixed with `signalStrengthRange = -120,-75` in `binder.conf`. |
| **Mobile network works — SIM detected, registered on LTE** | `Present=true`, `ServiceProviderName="fraenk"`, `NetworkRegistration Status=registered`, `Technology=lte`, `ConnectionManager Attached=true`, on `/ril_0` of a dual-SIM device. Two config files: `OfonoPlugin: binder` in a device yaml that did not exist, and slot definitions in `binder.conf`. No kernel change. |
| **Wi-Fi works, including the UI** | Connects and lists networks. Note this happens with **no** `/dev/rfkill` and `urfkilld` inactive, which falsifies experiment 006's claim that the indicator needed `CONFIG_RFKILL`. RFKILL is built now, but for Bluetooth: `bluebinder` needs `/dev/rfkill`. `swlan0` is the interface that carries traffic. |

## Not proven, and blocking

| Open | Why it matters |
|---|---|
| **A bare `make <defconfig>` kernel does not boot this device** | It is how the tools build kernels. [`kernel.md`](kernel.md) risk 1 — the largest single risk in the port. |
| **`console=tty0` cannot be delivered via `deviceinfo_kernel_cmdline`** | S-Boot ignores the boot image command line. [`kernel.md`](kernel.md) risk 2. |
| **The tools use Google's prebuilt Clang, not the pinned Proton Clang** | A second changed variable sitting under risk 1. [`kernel.md`](kernel.md) risk 3. |
| **Does S-Boot check the boot header `id` digest?** | The one field experiment 001 could not reproduce. One boot test. |
| **AppArmor** | Not built, and a kernel adding it as default LSM **does not boot** — fails before USB enumeration. No longer blocks GPS. [experiment 009](experiments/009-gps-permissions.md), [008 appendix](experiments/008-bluetooth-hci-sock.md) |
| **Fingerprint capture** | HBM is **solved** - a 13-line kernel patch (`decon-force-mask-layer`) makes `actual_mask_brightness` go 0-&gt;255 on demand, running the vendor's own TE-synced sequence. But the sensor still reports no finger: the HAL opens a ~150 ms SPI window for the trustlet to bring the ET713 up, that fails, and it therefore never issues `INT_TRIGGER_INIT` - so no DRDY interrupt is registered and `nd cnt` can never leave 0. No fingerprint calibration data exists under `/mnt/vendor/efs`, which may be why. [experiment 012](experiments/012-fingerprint.md) |
| **The initramfs fixes have not been ported** | Four are expected to be needed. `ramdisk-overlay/README.md`. |
| **`conn_gadget` double-registration is avoided, not fixed** | The container is kept away from USB gadget configfs. The real fix is an idempotency guard in `conn_gadget_setup()`, still unwritten to the kernel branch. |
| **The `ld.config.txt` rewrite in the audio fix** | `a50-audio-hidl-compat.service` patches generated linker config on every boot so the HAL wrapper can resolve `libaudiohal.so`. `HYBRIS_USE_VENDOR_NAMESPACE` is supposed to make that unnecessary and demonstrably does not work here. Find out why and the hack can be deleted. [experiment 007](experiments/007-abox-firmware-too-early.md) §26 |
| **Headphones / earpiece** | Only the speaker path has been exercised. UAIF0 is the codec path and is untested. |
| **Camera: HAL works, app crashes** | The old "panics the kernel" hazard **does not reproduce** — all 50 V4L2 nodes opened + `QUERYCAP` with no crash, and `gst-plugin-scan` is not even installed. Everything below the app is proven working: sensor drivers probe (`cis_2x5_probe done`, deferred list empty), the Samsung HAL enumerates 3 cameras, and **from Ubuntu Touch** `android_camera_connect_by_id()` succeeds returning **16 preview + 33 picture sizes** (to 5760×4320). Fixed the app's missing `libexiv2.so.27`, without which it could not load its own QML plugin. It now reaches the camera and renders a frame, then **segfaults**: the AAL viewfinder never picks up the preview sizes the HAL offers (`QSize(-1,-1)`), and `AalImageCaptureControl::onPreviewReady()` does not exist in the installed plugin. Upstream UT media-layer mismatch, not device-specific. [experiment 014](experiments/014-camera.md) |

## Deliberately not started

* **UBports recovery.** `deviceinfo_has_recovery_partition` is false. TWRP is
  well tested on this device and is the only reliable way back, and building a
  second recovery would put that at risk for no gain.
* **The UBports Installer.** It flashes over fastboot or heimdall against a
  registered device in `ubports/installer-configs`; this port has neither a
  system-image channel nor an upstream device entry. The flashable zip is the
  substitute, and `installer/README.md` explains why the shape differs.
* **An OTA channel.** Nothing serves `26.04-1.x/.../a50`, so Settings ->
  Updates finds nothing. Updating means reflashing - or, for a kernel-only
  change, `dd` from a running system.

## A standing hazard, not a task

Getting from running Linux back to TWRP is **unreliable on this device**:
`systemctl reboot --reboot-argument=recovery` sometimes works and sometimes
reboots straight back into Linux (three successes then four failures in one
session). The AOSP bootloader control block is ignored by S-Boot — tested — and
glibc's `reboot()` cannot pass `recovery` at all.

Never end a session with the device bootlooping, and keep a known-good boot
image within reach before every flash. Published with hashes in a50-droidian,
release `boot-images-2026-09-01`.
