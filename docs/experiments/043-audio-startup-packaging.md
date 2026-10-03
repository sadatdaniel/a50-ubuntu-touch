# Audio startup links lost in the image overlay

3 October 2026, fresh Ubuntu Touch 26.04 image. YouTube playback was silent
on both sink.fast and sink.primary-out. Streams were unmuted and running.
PulseAudio mapped only the 12,088-byte generic audio.primary.default.so stub;
there was no HIDL wrapper or hwbinder descriptor. Android's Samsung audio
service itself was running.

Both existing audio services were disabled/inactive. Their multi-user.target.wants
entries were ordinary files, including an obsolete copy of the route unit.
Git recorded those entries as mode 100644, so the committed-tree tarball
builder faithfully shipped ordinary files. This was a port packaging defect,
not evidence that a new Ubuntu package broke speaker playback.

The same defect affected a50-gnss-unblock.service. All three committed entries
are corrected to mode 120000 with relative targets ../SERVICE. Release builds
already use git archive, which preserves this metadata even on Windows.
No new boot service or hand-written mixer routing is introduced.

[systemd's documented enablement](https://github.com/systemd/systemd/blob/main/man/systemd.unit.xml)
creates symbolic links for WantedBy dependencies. The live, authenticated
scripts/experiments/audio-startup.sh backs up and validates the known bad
entries, removes only those ordinary files, uses systemctl enable for the
existing audio units, starts the existing HIDL bridge, restarts user audio,
and starts the existing primary-output routing service. Stage as /home/phablet/fix
and run `sudo.ws sh fix`. It does not weaken authentication or alter vendor.

The user ran the live startup repair. Both audio units are enabled/active,
and their dependency entries are now symbolic links. Root remains read-only.
This does not establish working audio: after the restart the HIDL wrapper
fails to resolve libaudiohal.so, leaving only the dummy SCO output.
Playback, microphone and normal reboot tests remain outstanding.
The historical host HIDL wrapper/linker configuration adaptation is unchanged;
its upstream replacement investigation remains a release task. No audio
stability or video-stop fix is claimed from startup enablement alone.

Regression: `python3 scripts/experiments/test-startup-links.py` checks the
committed overlay archive; pass the built device tarball as an argument to
check the delivered artifact. Before the correction it fails on the audio
startup entry. After committing the correction all dependency entries must
be links. Port-owned system unit links must resolve to units in the overlay;
the existing datetime link targets a unit supplied by the upstream package,
so its target is intentionally outside the device-only archive.

Backups and repair output are private under /home/phablet/a50-audio-startup.*.
To roll back the live startup metadata, disable the two services and restore
the saved ordinary entries. Reboot to discard the existing bridge's temporary
host mount and generated linker configuration change. Release rollback uses
the previously tested device image. Do not publish raw logs or recordings.


## Remaining namespace setting, prepared but unverified

The earlier working installation had a PulseAudio service drop-in which
unset HYBRIS_USE_VENDOR_NAMESPACE. It was not included in the fresh overlay.
The current upstream session sets that variable, and libhybris selects
/vendor/bin/yes as its configuration identity when the variable exists.
Without the variable it selects /system/bin/app_process64. See the
[installed-source linker implementation](https://github.com/libhybris/libhybris/blob/7079712/hybris/common/q/linker_main.cpp).
This port loads a system HIDL wrapper to reach Samsung's 32-bit audio service,
so the earlier system-namespace setting must also be restored and validated.
The generated linker configuration still contains the earlier sphal allowlist
entries; namespace selection is a separate missing prerequisite.

scripts/experiments/audio-namespace.sh prepares the narrow user-service
configuration, refuses to overwrite an existing override, restarts audio,
selects the primary output, and checks the process mappings and hwbinder
descriptor. It runs as phablet without sudo and does not alter authentication.
Remove the created user drop-in, reload the user service configuration and
restart PulseAudio to undo this experiment. Its successful execution, audible
result and permanent image integration are still pending.

Automatic approval review's allowance was exhausted on the first attempt,
so that change was not executed. After the user requested continuation and
review recovered, USB was offline. Normal ADB reconnection did not restore
access; a cable reconnect was requested. No reboot or TWRP requested.
