# Recording Stop: existing upstream lookup correction

3 October 2026. Speaker audio now works normally before and after reboot;
video Stop remains a separate, reproducible recorder lock. Raw logs and media
stay private. This is an experimental source backport, not a validated video fix.

The Android camera_service AudioRecord callback holds the AudioSource lock
while AudioSystem::getInputFramesLost calls get_audio_flinger and waits for
media.audio_flinger. That service is absent by design in Halium's pipe-based
recording. The recorder looper needs the same lock to finish setStopTimeUs,
so the Binder Stop request never completes. See experiment 042 for the trace.

The official [Halium 13 recording patch](https://github.com/Halium/hybris-patches/blob/halium-13.0/frameworks/av/0004-halium-get-rid-of-using-AudioFlinger-for-recording.patch)
already initializes af to nullptr here, avoiding the lookup and returning the
existing zero result. The proposed Halium 11 backport reuses that exact line.
It does not change Camera thread ordering, add timers, provide a fake service,
modify vendor binaries, or introduce a recorder interposition library.

## Exact base and application check

The public [GSI 1542 source record](https://ci.ubports.com/job/UBportsCommunityPortsJenkinsCI/job/ubports%252Fporting%252Fcommunity-ports%252Fjenkins-ci%252Fgeneric_arm64/job/halium-11.0/1542/artifact/used-repos.txt)
records frameworks/av 18186d8f9b4dcaff242ae9ea9b74e6827f14a1cc and
hybris-patches 790b3792f7d58da7d3d63ad04b79e9c184262a97. The source was
retrieved from the recorded LineageOS revision, not a different AOSP tag.

Git blob checks:

- Original AudioSystem.cpp: bf98822b53f97720356a61d1da2bce3c84bea9db.
- After the existing Halium 11 recording patch: d84c49e22a93bef2b875d0066698c8a20673437e.
- After the Halium 13 line backport: 3f3e99c2cb745b2928c5ec57f75af0f98bd39979.

Both patch application checks pass on the exact base. The follow-up patch is
scripts/experiments/halium11-recording-audioflinger.patch, SHA256
c4030ecafb553fb54cd6e91046de3469e81133c48d7bb9f21c0f9dadaad4d47c.
This is a source application check; it is not compilation or phone validation.

## Conventional remote build

The [official generic-device recipe](https://gitlab.com/ubports/porting/community-ports/jenkins-ci/generic_arm64/-/blob/halium-11.0/Jenkinsfile)
selects lineage_halium_arm64-userdebug. The [shared build tools](https://gitlab.com/ubports/porting/community-ports/jenkins-ci/halium-build-tools)
apply hybris-patches before using Android's normal build system.

The experimental recording-library-test workflow uses that target and normal
patch application. Its source lock contains all 879 project revisions from
the shipped GSI build. Google's repo tool resolves the upstream manifest;
pin-gsi-manifest.py sets the recorded revisions and rejects missing projects.
Actual manifest resolution, pinning and re-initialization passed in an existing
Linux container without syncing an Android tree locally. The small self-check
also verifies missing-source rejection. No full Android download went onto the
PC or phone.

A remote hosted runner checks for at least 95 GiB free before source sync,
then builds libaudioclient for both ELF32/ELF64 targets. A mismatch in the
expected AudioSystem.cpp blob stops the build. Artifacts include portable
checksums, ELF headers/dependencies, exact built manifest and applied diff.
If the standard runner cannot provide the space, this job stops rather than
starting the source download. A larger Linux build host would then be required.

The workflow's compilation result is still pending. Do not install a different
Halium major-version library. Before any live test, verify both artifacts,
SONAME/dependency and exported-symbol compatibility, retain private originals,
and use authenticated reversible deployment. Normal reboot and repeated
record/Stop/playback with picture and sound must pass before moving the GSI pin
or claiming video works. Release integration requires the matching rebuilt GSI
through the normal image pipeline; a live library experiment alone is insufficient.

Current original-library SHA256 fingerprints on the phone:

- system/lib/libaudioclient.so (503824 bytes): 61ccb6554dcef9fdc30099a88d3c7773901e616aeefccc1845d8045d56d1e89d.
- system/lib64/libaudioclient.so (703480 bytes): ddcdf2a8e68eae5a01f91f1ab92e4175205ed38f31f0aec76e513e0992fa91f6.


First remote run 37152064170 passed capacity/prerequisite and manifest
preparation, then stopped during source sync: the pinning helper had incorrectly
used the default Lineage branch for a project whose AOSP remote specifies an
Android release tag. The helper now uses project revision, then remote revision,
then default revision, matching repo manifest semantics. Its regression covers
this AOSP case. No compilation or phone deployment occurred in that attempt.


Corrected run [37152420785](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37152420785)
passed runner preparation and manifest resolution and entered source sync.
The corrected helper also passed against the actual resolved manifest: the
compatibility/cdd AOSP project now uses refs/tags/android-11.0.0_r46. At this
checkpoint no compilation result or new phone library is available. Monitor
the run to completion before any artifact staging or deployment.
