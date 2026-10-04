# Fresh Waydroid initialization

4 October 2026. Ubuntu Touch 26.04, installed Waydroid 1.6.3, aa17 kernel.
This is setup and validation in progress, not a stability claim.

## Supported setup

The [UBports user guide](https://docs.ubports.com/en/latest/userguide/dailyuse/waydroid.html)
ships the package on Halium 9 and newer devices and instructs users to run
`waydroid init`, then refresh the app drawer. Android images and writable state
are separate from the Ubuntu Touch system image. No separate Waydroid Helper,
Google services, custom channel, or full Halium rebuild is needed for this step.

Before this test the package was installed, but `/var/lib/waydroid` had no
configuration or images. The system was read-only, AppArmor enabled, and no
system service had failed. Userdata had 96 GiB free. The native anbox binder,
hwbinder and vndbinder devices were present. Host VNDK 30 selects HALIUM_11.

The installed initializer was inspected before execution: it retrieves official
channel manifests, checks each archive SHA256 before extraction, and writes a
normal user-owned `Waydroid.desktop`. Its container service is D-Bus activated;
the package wrapper deliberately removes an old boot-enabled container service.
The port's old user session service was disabled and inactive during setup.
It was not enabled for this test.

## Reproduction

Use the normal `waydroid init` procedure for end users. For an administrator
reproducing this A50 test, `scripts/experiments/init-waydroid.sh` adds only
vendor, binder and userdata capacity checks before that same command. It refuses
an incomplete existing configuration and does not reset an initialized install.
Use normal administrator authentication; no credentials belong in the script.

The live initialization ran as a temporary systemd unit with a 30-minute limit,
starting at 10:32 Berlin. It exited successfully. It did not remount the system
or write the phone's vendor or recovery partitions.

Official channel inputs selected during this run:

| Input | Value |
| --- | --- |
| System channel | `https://ota.waydro.id/system/lineage/waydroid_arm64/VANILLA.json` |
| System archive | `lineage-20.0-20260927-VANILLA-waydroid_arm64-system.zip` |
| System archive size | 912267974 bytes |
| System archive SHA256 | `5fb8179ed4455f45919c5a2bfbfdd1591619295994ad321217f03bb1dcfc53a7` |
| Vendor channel | `https://ota.waydro.id/vendor/waydroid_arm64/HALIUM_11.json` |
| Vendor archive | `lineage-18.1-20260402-HALIUM_11-waydroid_arm64-vendor.zip` |
| Vendor archive size | 42868809 bytes |
| Vendor archive SHA256 | `5b48a2771e77ff9085862f58b5c9d852d439d5e57dd38ea33b58381c2b14ca48` |

These channels can change. The recorded hashes identify this test; a later run
must record its actual inputs instead of assuming it receives identical images.

Extracted `system.img`: 1994985472 bytes, SHA256
`ba4da2882999bc09a63eab5f2b02a77cdce13df0b72b98fea58a4d7ccb125f4d`.
Extracted `vendor.img`: 92676096 bytes, SHA256
`11591fbcd87fe5ed71d3bce5b2a2c0b60121a7936edef7834a305c817f7f4a1c`.
The latter is Waydroid's userdata image, distinct from the phone's vendor partition.

## Result and remaining checks

The generated user entry has `Exec=waydroid show-full-ui`, `NoDisplay=false`,
phablet ownership and mode 0644. Fresh Gio discovery reports it visible.
No old launcher wrapper or desktop reconciliation script was applied. The system
remains read-only with AppArmor enabled, no failed system units and 94 GiB free
in userdata after setup.

The user confirmed the drawer icon appears and Android stays open. The running
session is the native `waydroid show-full-ui` process, with the old custom user
session service still inactive and zero container-service restarts. Android 13
reports `sys.boot_completed=1`. Two packets each to an Internet IP and a DNS
hostname succeeded with zero packet loss; this establishes basic routing/DNS,
not all application networking. The guarded setup script passed shell syntax
and its already-initialized branch on the phone without resetting anything.

The user then closed/reopened twice successfully; the third reopening failed.
Capture at 10:45:43 Berlin showed the Android session/container RUNNING,
`sys.boot_completed=1`, an empty crash buffer and zero container-service
restarts. The native visible desktop file still existed. Android's launcher had
an active surface. The initial session's host process/unit remained alive,
while later timestamped launcher units exited. Lomiri logged applicationRemoved
with appIndex not found, and a surface from an app outside its launcher model.
These observations establish a host launcher/window lifecycle failure; they do
not prove an Android crash or the precise cause of the earlier missing icon.

### Native single-instance candidate

Inspected lomiri-app-launch source revision
`2ab7196467fde3140796274f70d31263b1d6a003`: Desktop reads
`X-Lomiri-Single-Instance`, Base::getInstance returns a stable empty instance
instead of a timestamp when it is true, and the systemd backend uses its
existing second-exec path when a unit already exists. Sources:
[desktop parsing](https://gitlab.com/ubports/development/core/lomiri-app-launch/-/blob/2ab7196467fde3140796274f70d31263b1d6a003/liblomiri-app-launch/application-info-desktop.cpp),
[instance identity](https://gitlab.com/ubports/development/core/lomiri-app-launch/-/blob/2ab7196467fde3140796274f70d31263b1d6a003/liblomiri-app-launch/application-impl-base.cpp),
[systemd launch](https://gitlab.com/ubports/development/core/lomiri-app-launch/-/blob/2ab7196467fde3140796274f70d31263b1d6a003/liblomiri-app-launch/jobs-systemd.cpp).

The installed generator omits this native key. A one-line candidate adds
`X-Lomiri-Single-Instance=true` to its main Waydroid entry while preserving the
native Exec and visibility handling. `check-waydroid-single-instance.py` executes
the actual extracted generator for visible/hidden/visible regeneration: original
fails the identity assertion, candidate passes. No fake keepalive process,
desktop polling, or custom session service is introduced.

`waydroid-lomiri-single-instance.patch` applies to the installed source.
Original generator SHA256:
`cc0c23d6c7849a108ecbdf800129899993186f6cba9e0d0d2f4edad916ef595e`.
Candidate generator SHA256:
`5fdb97bccca110ae88389121001bf41055bad9721e68b663042344421867dec4`.

`test-waydroid-single-instance.sh apply CANDIDATE_FILE` checks those hashes,
preserves the desktop entry, stops the stale session normally, and binds the
candidate read-only over the generator for this boot. It then regenerates the
entry using the installed function. This was applied at 10:53 Berlin; the root
filesystem stayed read-only. The user confirms all three requested closes/reopens work and the icon stays
visible. The native stable single-instance unit was verified, and the flag
survived Android-ready launcher regeneration. This remains a temporary runtime
test, with wider stability and packaged reboot validation open.
`test-waydroid-single-instance.sh restore` stops the test session, unmounts the
candidate, verifies original source and restores the desktop backup. Reboot
removes the source mount; native regeneration then restores package defaults.
Android data is retained. The targeted hardware check passes. The existing compatibility-package workflow
now has a Waydroid option to build this one-line change using upstream source
5b7e2e71be3f6bfaaaab3b461251dacaf1ce4991 and UBports packaging
7ebfea8f880a2d7c9c641070fe3cb273fa6c268d, preserving all twelve UBports patches.
Package build/install/reboot validation and upstream submission remain pending.

Repeated close/reopen, container restart, Android application network/audio, sleep/wake,
compositor restart, reboot and extended use remain unvalidated. The older port
camera-provider stop adaptation is still installed; its need must be checked
separately before removing it. Do not claim a completely stock runtime yet.
The former missing-icon report remains unresolved until reproduced or exercised
through the required lifecycle checks. Use the existing
`scripts/experiments/check-waydroid-launcher.sh` before refreshing or restarting
if it recurs; raw output stays private.

For rollback of this setup, stop the user session normally with
`waydroid session stop`. This initialization does not change the ROM, kernel or
vendor partition. Retain images and userdata for diagnosis; there is no automatic
delete or forced reinitialization. No paid cloud resource was created.
