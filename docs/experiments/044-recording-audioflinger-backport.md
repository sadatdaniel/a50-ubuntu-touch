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

The initial workflow checkpoint preceded the completed runs recorded below. Do not install a different
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

Run [37152420785](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37152420785)
compiled both architectures successfully (2091 build actions, about nine
minutes for compilation). Its artifact only contained the two initial
manifests: Android envsetup overwrote the script's generic OUT variable,
redirecting libraries and checksums into the product tree. Those outputs
were not uploaded and cannot be used for a phone test. The script now uses
a readonly task-specific artifact directory, and the workflow checks both
libraries and their checksums in the upload directory before declaring the
build successful. A replacement build is required; no new library has been
installed on the phone.

## Complete artifact and temporary hardware test

Replacement run [37154143698](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37154143698)
successfully built and uploaded both libraries, their ELF reports, checksums,
pinned manifests and the exact one-line source diff. SHA256 values:

- ARM32: 10d7fa4bdb95005f855520aa797d2ae31e68c231df94d9de9f2fd6714ee9a719
- ARM64: 3851b31f6c254f91a97e6b2c3a3aae71559abf2b83c3a78ebc19abb9b4b456fe

`check-recording-abi.py ORIGINAL_DIRECTORY CANDIDATE_DIRECTORY` uses standard
readelf and Python. The original fingerprints, candidate checksums, architecture,
SONAME, all dynamic exports/imports and ordered DT_NEEDED libraries match.
ARM32 has 1280 exports/334 imports; ARM64 has 1277 exports/333 imports.
ABI matching does not prove runtime behavior.

The user authenticated `test-recording-library.sh` via the short fix file.
The private screenshot confirms checks succeeded and the test-ready message.
The script verifies Android SDK 30 and the exact original library hashes,
copies the candidates into a private root-owned Android staging directory,
temporarily bind-mounts them inside the Android container and verifies the
active hashes before restarting only the existing camera_service. On failure
it removes its mounts; on normal reboot the test mounts disappear. Original
image files and vendor remain intact. No startup service is installed.

This temporary test is not the release implementation: a validated result
must be incorporated into the normal pinned GSI build. The user tested recording and Stop, and reported another freeze. Directly
collected native stacks prove the callback wait has gone, but reveal a second
wait during AudioRecord destruction:

```
ServiceManagerShim::getService -> AudioSystem::get_audio_flinger
 -> AudioSystem::releaseAudioSessionId -> AudioRecord::~AudioRecord
 -> AudioSource::~AudioSource -> StagefrightRecorder::~StagefrightRecorder
 -> MediaRecorderClient::release
```

The process remains alive; this evidence establishes a blocked release rather
than a proven native crash. Both active library hashes match the candidates.
The first one-line backport is therefore insufficient and is not a release fix.

## Existing shared fix: Halium pull request 84

[Halium PR 84](https://github.com/Halium/hybris-patches/pull/84) is open and
unmerged at this checkpoint. Its author reports successful hardware recording
with audio on POCO X3 Pro/vayu using Droidian 101 and Halium 11. The exact head
is f2083f3e9cf6462dbee1c202e6ea74cf66da5f79. This is upstream proposed code with
reported testing on another device; it is not an accepted UBports update or
A50 validation.

The five-line patch checks CameraRecordService using nonblocking checkService
inside the shared get_audio_flinger accessor. If Halium recording is active,
it returns the existing null/no-service result instead of entering the infinite
AudioFlinger lookup. Thus getInputFramesLost and releaseAudioSessionId both
reach their existing null handling. Existing AudioFlinger behavior remains
when CameraRecordService is absent or gAudioFlinger is already established.
The standard Halium 11 enable-recording patch already disables acquiring the
AudioFlinger session in AudioRecord::set, but leaves the release call intact.
The shared upstream fix covers that mismatch without changing recorder order.

The replacement build uses this exact upstream patch alone, superseding the
one-line experiment rather than accumulating both patches. Applying it to the
recorded post-Halium source passes, producing AudioSystem.cpp blob
74a68fec469df1edccebfd58104045f5a3d0c10c. Patch SHA256:
02606a812de88bf71003f074ad4eb5135444cfaf54500ef730022386e78842a8.
Build script rejects another source and verifies this result. Original libraries,
ABI checks and reboot-reversible deployment remain required. Compilation and
hardware results for this replacement are pending.


Replacement run [37156894732](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37156894732)
completed both builds and uploaded all required artifacts. Compilation took
about seven minutes after source sync. Both library interfaces match the
verified originals, including all exports/imports, dependencies and SONAME:

- ARM32 SHA256: 7b0b0bcd6054e9316a9b0648db95b6f7c6468926e2b947681748164573b2ffc8.
- ARM64 SHA256: ba0433f3682b87082fb48238b01f697275861486e016b5bd46c00647cfcdc92d.

The first temporary libraries were unmounted and both original hashes verified.
The 32-bit mount needed the existing camera_service stopped before unmounting.
The reproduction script now verifies private root-owned staged copies before
mounting, stops the helper normally before replacement, waits for its state,
and starts it again after verified mounts. Failure cleanup uses the same
stop/unmount/start sequence. This avoids leaving a busy failed-test mount.
The new test remains reboot-reversible and is not a permanent image change.
Hardware record/Stop/playback validation is still required.

## A50 repeated Stop/playback validation — 4 October 2026

The user reports successful Stop and then confirms all three requested
recordings stop and play normally with picture and sound. The same kernel
boot ID and the exact PR 84 candidate hashes remain active inside Android.
The recording helper is running; its captured native stack now waits normally
in Binder rather than the previous AudioFlinger callback/destructor loops.

Three privately retained samples passed ffprobe stream inspection and full
FFmpeg video/audio decoding with exit 0 and no reported decode errors:

| Sample | Duration | Video | Audio |
| --- | --- | --- | --- |
| First Stop test | 5.192 s | H.264, 3840×2160 | AAC, stereo, 48 kHz |
| Later recording | 4.885 s | H.264, 3840×2160 | AAC, stereo, 48 kHz |
| Later recording | 3.733 s | H.264, 2336×1080 | AAC, stereo, 48 kHz |

The first audio stream contains nonzero samples (peak −45.7 dB); physical
playback is separately user-confirmed. Logs still contain Samsung preview/flush
timeout warnings. These did not prevent the observed recordings finishing and
do not justify claiming every camera mode or prolonged use stable. Media and
raw logs remain private. Post-reboot validation needs the actual rebuilt image,
because the current library mounts disappear on reboot.

## Conventional full-image candidate

The existing recording workflow now accepts full_image=true. It retains the
same pinned 879-project GSI 1542 manifest, standard Halium patches and exact
PR 84 source guard, and builds recoveryramdisk/systemimage using the generic
targets in the [UBports Halium builder](https://gitlab.com/ubports/porting/community-ports/jenkins-ci/halium-build-tools/-/blob/9ace25eaf6e71aa38a1e18f94019b19f92d547e9/build.sh).
The normal compiled simg2img tool is also built for upstream packaging.

Its [upstream build-tarball.sh](https://gitlab.com/ubports/porting/community-ports/jenkins-ci/halium-build-tools/-/blob/9ace25eaf6e71aa38a1e18f94019b19f92d547e9/build-tarball.sh)
is pinned, called without a local replacement, and creates the conventional
halium_halium_arm64.tar.xz layout. Offline e2fsck must pass; debugfs extracts
both libraries from the packaged image and cmp must match the compiled copies.
The tarball/image hashes, size, source manifest and packer commit are retained.
The runner requires 25 GiB free after source sync; it fails early if the full
build cannot fit. No source download is made on the phone or local host.

This is a candidate build, not a new registered Jenkins GSI or signed OTA.
gsi.lock remains the historical 1542 baseline. A successful candidate needs
verified installation, boot and repeated recording/playback tests before
selecting its artifact hash for a release. The generic recovery ramdisk is
not a tested A50 recovery image and must not be flashed as one. Kernel,
vendor partition, authentication and user data are unchanged by this workflow.
