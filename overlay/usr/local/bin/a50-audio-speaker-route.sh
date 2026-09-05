#!/bin/sh
# Pin Ubuntu Touch playback to the droid output that this device can sustain.
#
# The droid card exposes sink.primary-out and sink.fast. After a PulseAudio
# restart the default drifts to sink.fast, the low-latency output, whose small
# buffer the ABOX path cannot sustain: playback then breaks up in bursts and
# sounds like it is being fast-forwarded. sink.primary-out is the verified-good
# one - pcm0p tstamp advancing, avail_max healthy, no xruns, and no NACKs in
# the ABOX DSP log at /sys/kernel/debug/abox/log-00.
#
# NOTE: this script deliberately does NOT touch the ABOX mixer.
#
# Earlier versions set the speaker route by hand
# (ABOX UAIF2 SPK = SIFS0, the vendor's route-sifs0-to-uaif2). That was needed
# only while PulseAudio was loading a *stub* audio HAL and nothing was
# programming the mixer at all. Once the real hidl_compat wrapper loads - see
# a50-audio-hidl-compat.service - the HAL programs its own routing from
# /vendor/etc/mixer_paths.xml, and it wins, because it re-routes on every
# stream change:
#
#     SPUS OUT0 = SIFS0   UAIF0 SPK = SIFS0        (codec)
#     SPUS OUT7 = SIFS1   SIFS1 = SPUS OUT7   UAIF2 SPK = SIFS1   (speaker)
#
# Writing the mixer from here is therefore both redundant and harmful: the HAL
# owns those controls, and rewriting UAIF2 SPK or the rate/width controls while
# a stream is running corrupts playback - the same fast-forward artefact.
# Verified on hardware: with the HAL working and this script touching nothing
# but the default sink, audio is correct.
set -u

PH_UID=32011

log() { echo "a50-audio-route: $*"; }

pa() {
    su - phablet -c "XDG_RUNTIME_DIR=/run/user/$PH_UID pactl $1" 2>/dev/null
}

# Wait for PulseAudio to be up with the droid card loaded.
i=0
while ! pa 'list short sinks' | grep -q 'sink.primary-out'; do
    i=$((i + 1))
    if [ $i -ge 60 ]; then
        log "sink.primary-out never appeared - is the droid card loaded?"
        exit 0
    fi
    sleep 2
done

pa 'set-default-sink sink.primary-out' >/dev/null
for s in $(pa 'list short sink-inputs' | awk '{print $1}'); do
    pa "move-sink-input $s sink.primary-out" >/dev/null
done

log "default sink pinned to sink.primary-out"
