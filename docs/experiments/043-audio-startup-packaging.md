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

At this checkpoint the live repair is staged, not yet user-run or audibly
verified. It must be followed by playback, microphone and normal reboot tests.
The historical host HIDL wrapper/linker configuration adaptation is unchanged;
its upstream replacement investigation remains a release task. No audio
stability or video-stop fix is claimed from startup enablement alone.

Regression: `python3 scripts/experiments/test-startup-links.py` checks the
committed overlay archive; pass the built device tarball as an argument to
check the delivered artifact. Before the correction it fails on the audio
startup entry. After committing the correction all dependency entries must
be links with valid targets.

Backups and repair output are private under /home/phablet/a50-audio-startup.*.
To roll back the live startup metadata, disable the two services and restore
the saved ordinary entries. Reboot to discard the existing bridge's temporary
host mount and generated linker configuration change. Release rollback uses
the previously tested device image. Do not publish raw logs or recordings.
