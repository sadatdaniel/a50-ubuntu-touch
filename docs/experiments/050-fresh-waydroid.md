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
### Conventional package installed

Build [37191717067](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37191717067)
passed on Ubuntu 26.04 ARM. The original generator fails the actual-function
regression and the patched generator passes. Build corrections replace the
upstream Debian directory with UBports packaging rather than merging both, and
allow UBports' generated version relative to the unmangled source changelog.
All twelve official UBports patches are retained.

Candidate version:
`1.6.3-0ubports1~20260917185450.14~7ebfea8+ubports26.04.1+a50singleinstance.1`.
Candidate package SHA256:
`3f2233b1c20486e907e45932d0dca37452e29bef07ffef01534e3cfdf0aed540`.
Original package retrieved using the signed UBports repository metadata:
`c62fe6dd5cb90cf67392481e13f5e7c1170a1fd822dee6463c4c363cac17226e`.

Every extracted payload path, mode and symlink was compared. Only the actual
generator and Debian changelog differ; maintainer scripts are identical.
Package control differs only in version, with unchanged dependencies and size.
APT simulation changes exactly Waydroid, no additions/removals. The temporary
source mount was removed, then normal local APT installation succeeded.
The source checksum and regenerated native visible launcher match the candidate,
package audit is clean, no system units failed, and root is read-only again.
The native generator is now package-managed, with no runtime source bind.

`install-waydroid-single-instance.sh` checks exact versions/hashes and the
one-package plan, uses a private local APT cache, restores read-only root and
retains Android data. Place the two recorded packages under the script's
private userdata directory before using it. `--rollback` installs the verified
original package through normal APT. The script refuses a remaining source bind;
restore the temporary experiment first. A first installation attempt with a
relative archive path failed before changing packages; the established absolute
path/local cache convention corrected it. Rebuilding later may change archive
hashes with build metadata/tooling; compare payloads and update the guarded hash
after review rather than bypassing it.

A full system reboot changed the kernel boot ID. The installed candidate source
checksum, native single-instance entry and package version survived without a
source mount. AppArmor remains enabled, package audit is clean, root read-only
and no system units failed. Native LAL launch reached Android-ready; the user
is exercising close/reopen after this reboot. Visible post-reboot repetitions,
wider lifecycle testing and upstream submission remain pending.
Network comparisons are recorded separately in [052](052-waydroid-network.md).

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

## Post-reboot failure and second candidate

The user reports first close followed by a failed immediate reopening, a later
successful click, then icon disappearance after the next close. This falsifies
any claim that candidate .1 completely resolves Waydroid lifecycle behavior.
Android-ready startup took 23–27 seconds in the two recorded sessions; both
closed normally. At failure, session/container are stopped, the main desktop
entry exists with NoDisplay=false and Gio considers it visible. Lomiri logs
missing launcher-model entries and stop events for an app it no longer manages.

Current UBports packaging branch still resolves to the pinned 7ebfea8 revision.
Its makeWaydroidDesktopFile unlinks the main entry before recreating it on every
Android-ready notification. Inspected Lomiri XdgWatcher::onFileChanged treats
an inode no longer watched as appRemoved; lomiri-app-launch's legacy store also
handles deletion separately from modification. This is a specific candidate
cause, not yet hardware proof. Upstream issue
[39](https://gitlab.com/ubports/development/core/lomiri/-/issues/39)
documents another Waydroid desktop-update/drawer problem; it is related context,
not proof it is the identical failure or an available merged correction.

The .2 candidate removes only the unnecessary two-line unlink block while
retaining the native single-instance key, command and visibility updates. It
updates the existing entry through ordinary file writing, avoiding application
removal. No polling, custom session process or frozen permissions are added.
The actual generator regression now records file removal: .1 fails; .2 passes
visible/hidden/visible updates without unlinking. Candidate generator SHA256:
`a888527e10171aecb7645bc9d8e9608a11310a7491fe0a1760e0909a1480ca65`.
Normal .2 package build and phone validation are pending. The installed .1
package and verified original rollback remain available; no .2 source mount
has been applied.

### Second candidate package and real reboot

Build [37192963426](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37192963426)
succeeded with the stronger generator regression. Version suffix
`+a50singleinstance.2`; archive SHA256
`6d5444c20afea2409c8e00aa073df4ceee2630df75af3303fbaf1ad6eaad8cb5`.
Extracted paths, modes and symlinks again differ from the signed original only
in generator/changelog. Maintainer scripts and dependencies remain identical.
Normal APT preflight/install changed only Waydroid. The installer accepts the
known base or .1 predecessor and retains `--rollback` to the signed base.
The .1 archive is retained privately as well.

A second real system reboot changed boot ID. Candidate .2 version/source hash
and visible native launcher key persist without a source bind. Package audit
is clean, AppArmor is enabled, root read-only and no system units failed.
Waydroid is STOPPED at this checkpoint: the user is opening it from the drawer
rather than an external test launch, then exercising three close/single-tap
reopen cycles with up to 40 seconds for Android startup. Visible validation
remains pending. The previous post-reboot .1 failure remains part of the record.
No automatic Waydroid boot-start service was installed; the earlier immediate
appearance after reboot was the administrator's explicit LAL test launch.

### Second candidate visible result: passed

The user confirms all three requested single-tap reopens work after the full
reboot and the icon remains visible. Native logs record four sessions started
from the drawer at 11:49:03, 11:49:40, 11:50:44 and 11:51:45 Berlin, all reaching
Android-ready in 23–25 seconds. The first and third reopens start one or two
seconds after the prior unit stops. Final session/container are RUNNING,
Android boot_complete=1 and the container wrapper has zero automatic restarts.
The desktop remains phablet-owned 0644, visible and single-instance, with the
native show-full-ui command. Installed generator still has the recorded .2
hash, package audit is clean, root read-only and no system units failed.

This closes the specific post-reboot drawer-reopen/icon test for candidate .2.
It does not establish long-use stability, immediate reopening during unfinished
shutdown, every shell restart, Android audio/peripheral behavior, sleep/wake,
all application networking, or a clean release-image/OTA result. The conventional
package must still be integrated into the final image or superseded by a
compatible upstream release; no manual repair should be required for users.

### Updated-shell lifecycle and background-sleep investigation, 10 October

The user again confirms three ordinary drawer close/reopens with the icon
visible, now on installed Lomiri a50state.4 and official QtMir ac3ee9. Native
user-unit logs record the initial Android-ready plus all three user reopen
Android-ready events, with normal stops and zero shell automatic restarts.
The generated main desktop entry retains its inode. A subsequent native
launch reaches Android boot completion; an Android HTTPS HEAD request to
the official system-image service returns 200, and the sampled Android crash
buffer is empty. Bluetooth idle testing is deferred because the keyboard is
not currently available.

The command-line lomiri-app-launch client prints Started then aborts with
Lost our connection with the registry; the application independently starts
and reaches Android-ready. This client diagnostic is retained for investigation
and is not counted as a Waydroid window crash. One notification-close ownership
warning is present in the first session. Neither is concealed or used to
justify disabling normal launcher or notification security.

Official UBports packaging HEAD remains the exact recorded
7ebfea8f880a2d7c9c641070fe3cb273fa6c268d. The upstream Waydroid HEAD checked is
[c78a305a38a9ee6ce052ce524648a8156c2e225b](https://github.com/waydroid/waydroid/tree/c78a305a38a9ee6ce052ce524648a8156c2e225b);
the upstream user-manager path history has no later change than January 26.
No newer UBports packaged replacement for the tested launcher adaptation was
identified, and no source/package update was applied during this validation.

The owner reports a separate suspected crash after extended background use
or sleep. The existing bounded normal-startup sleep observer is now armed
with Waydroid running, preserving its user-unit PID/InvocationID and Android
init PID before unplugging. The user is asked to switch to Settings without
closing Waydroid, sleep unplugged for three minutes, and return through the
existing Recents tile. Result is pending; a successful drawer relaunch does
not by itself prove background survival. The earlier normal-boot sleep logs
are preserved as auto-1-normal-boot under the private test directory. A longer
unplugged background soak remains required even if the short test passes.

The established sleep observer's optional 1800-second mode is prepared for
the reported longer background failure. It uses the same independent wake
timer and keeps the normal 90-second test behavior. Stage it only after the
current short test is collected and cleaned; keep Waydroid's existing window
in Recents, switch to a native app, and leave USB disconnected for the soak.
Compare the exact user-unit InvocationID/PID and Android init PID after wake,
then test the existing window before any relaunch. Capture native/Android crash
evidence before recovery if it fails. See 048 for bounds and cleanup.

The first cohort's user report confirms the existing window resumes, with the
same native and Android session identities. It does not establish deep sleep:
the recorder expired four seconds before cable removal and counters stayed
9 to 9. That cohort is archived as auto-1-expired-preparation. The corrected
short test allows ten minutes for preparation, records each phase, and is
armed without restarting Waydroid; actual unplugged result is pending. See
048 for the observed timing and updated short/long caller timeouts.