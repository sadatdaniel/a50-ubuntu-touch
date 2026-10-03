# Camera dependencies, video stop and audio initialization

Checkpoint: 3 October 2026. Ubuntu Touch 26.04, camera.ubports 4.1.1,
cameraplugin-aal a167428, aa13 kernel. This is development validation.

## Photo capture restored using official dependencies

After installing the official libexiv2-27-compat package, the Camera click
could load its native plugin but failed before opening the HAL:
`module "Lomiri.Action" is not installed` at camera-app.qml:21.

The app imports Lomiri.Action 1.1. The conventional correction installs the
official `liblomiri-action-qt1` and `qml-module-lomiri-action` packages from the
signed 26.04 archive, with no application patch or account reset. Both have
version `1.2.2+0~20260619091020.22+ubports26.04.1~1.gbp82e7ca`.

SHA256:

- liblomiri-action-qt1: b36c578718d811cea94ccaca0fe6195be6c47e453e416df718a22c5e72d822c8
- qml-module-lomiri-action: 6de2b6581035be4670294a9a01b13ab69a0e234d7bdcf91e2d804f84f477ae4f

The staging simulation selected exactly two new packages, no upgrades and no
removals. The user installed them using normal administrator authentication.
Package versions and clean audit were verified over USB; root returned to
read-only. The user confirmed Camera opens and a photograph was taken.
The journal also confirms the picture-save event. Do not publish the picture.

Sources: [Action API](https://gitlab.com/ubports/development/core/lomiri-action-api)
and [official package](https://packages.ubuntu.com/resolute/qml-module-lomiri-action).

Reproduction scripts: `stage-camera-deps.sh` and `camera-deps.sh` under
scripts/experiments. They use the prepared private signed-index APT probe and
verify exact package checksums, architecture, versions and dependency closure.
For manual phone use, stage the installer as `/home/phablet/fix` and run
`sudo.ws sh fix`. Keep typed filenames short. These packages must be included
by normal package installation in the next image build before first boot;
this live repair alone does not complete image integration.

## Video stop remains under test

The user started a video, but Stop froze the app. At 19:27:19 CEST the backend
logged a zero-byte microphone-pipe write; at 19:27:20 it entered
`AalMediaRecorderControl::stopRecording()` with no subsequent completion.
Repeated observations found the live main thread waiting in
`binder_ioctl_write_read`, rather than a new camera process crash. A recording
file exists, but its existence does not prove a finalized playable video.

The read-only `cam-log.sh` collected private camera thread stacks, bounded
Android logs and service state. Android log timestamps use UTC while the
desktop journal uses CEST. The later camera stack shows lifecycle suspension
because Terminal was foreground; it must not be mistaken for the original
freeze. Android's camera dump still reports RECORD and recent RecordThread
warnings report buffers not being retrieved. The bounded log buffer was
already flooded, so it does not preserve the original stop transaction.

The exact installed [upstream backend](https://gitlab.com/ubports/development/core/hybris-support/qtubuntu-camera/-/blob/a167428/src/aalmediarecordercontrol.cpp)
calls Android stop synchronously before stopping its microphone producer.
Its existing comment explicitly explains that reversing this order can block
the MPEG4Writer join. Do not apply a speculative thread-order patch.
Earlier aa6 video blocking remains documented in SESSION-HANDOFF-17.md.

## Verified duplicate audio configuration fixed

The fresh rootfs's package-owned `/etc/pulse/touch.pa` already supplies
`hidl_args='helper=false'`. The device YAML also supplied
`PulseaudioModulesDroid_ExtraHidlArgs: helper=false`. Upstream discovery
concatenates these inputs. PulseAudio's journal confirmed the resulting
`helper=false helper=false` argument failed parsing and initialization; only
the dummy SCO sink and source remained available.

Removed only the redundant device YAML key. Kept the upstream touch.pa file
and the device's required `use_legacy_stream_set_parameters=true` CardArgs.
The authenticated live `audio.sh` validates the known configuration, creates
a private backup, edits only that key, and returns root to read-only.
After the normal user audio service restart, module-droid-discover,
module-droid-card-30 and module-droid-hidl load successfully. The HIDL argument
is now exactly `helper=false`; real `sink.primary-out`, `sink.fast` and
`source.primary-in` are present. No audio package downgrade or new service.

Sources: [official DeviceInfo guidance](https://docs.ubports.com/en/latest/porting/configure_test_fix/device_info/Pulseaudio-module-droid-discover.html)
and [discovery implementation](https://gitlab.com/ubports/development/core/hybris-support/pulseaudio-module-droid-discover/-/blob/5bdf4ff10dc6642f3bb222bdfc854f38fb0342ac/module-droid-discover.c).

This verifies audio initialization, not audible routing, call audio or video
stop. Reopening Camera after stopping the original hung app did not restore
recording: the replacement process remained alive, blocked on Binder before
the audio-producer-start log, with the real microphone source RUNNING.
It was not a newly observed SIGSEGV. A bounded native backtrace of Android's
minimediaservice shows Camera3 output threads waiting in queueBuffer and
dequeueBuffer calls, while a diagnostic dump waits on the Surface mutex.
These stacks locate blocked operations but do not identify the responsible
component. The first failed recording may have left shared services stuck;
a clean reboot and recording/stop/playback retest are required before
attributing the result to the corrected audio configuration. Do not claim the
audio fault caused the stop freeze until that test and subsequent evidence
establish the link. Restore the private saved YAML to roll back the live
change and restart the user audio service; release rollback uses the previous
tested device image. Keep raw logs and media private.
