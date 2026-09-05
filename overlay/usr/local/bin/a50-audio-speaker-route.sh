#!/bin/sh
# Bring up speaker audio on the Galaxy A50: route ABOX to the speaker
# amplifier, and pin playback to the output that can actually sustain it.
#
# ---------------------------------------------------------------- routing ---
# UAIF2 is the speaker amplifier (TFA9872): the vendor HAL's own
# /vendor/etc/mixer_paths.xml says so ("UAIF2 - Speaker AMP"), and the kernel
# confirms it at boot with "tfa98xx-aif-7-34 <-> UAIF2 mapping ok".
#
# The working chain is
#     RDMA0 (hw:0,0) -> SPUS OUT0 -> SIFS0 -> UAIF2 -> TFA9872
# i.e. the vendor's own "route-sifs0-to-uaif2", driven from playback_link 0.
#
# NOT the vendor's "media-speaker" path, which uses route-rdma7-to-sifs1 +
# route-sifs1-to-uaif2. The ABOX DSP firmware NACKs every PCMOUT command for
# channel 7 - its own log (/sys/kernel/debug/abox/log-00) says
#     [PCMOUT:WARNING] ret(-110), param(7), NACK REPLIED: 20
# and RDMA7_STATUS stays 0, so the DMA never advances and userspace gets -EIO
# out of ALSA's wait_for_avail(). Channel 0 is accepted.
#
# APPLY THE ROUTE ONCE, LATE. Nothing in Ubuntu Touch sets ABOX routing and the
# mixer does not persist (there is no /var/lib/alsa/asound.state here), but do
# NOT poll and re-apply: the audio HAL also owns these controls, and rewriting
# UAIF2 SPK or the rate/width controls while a stream is running corrupts
# playback - it sounds like the audio is being fast-forwarded. One application
# after the HAL has settled is enough.
#
# ------------------------------------------------------------ sink choice ---
# The droid card exposes sink.primary-out and sink.fast. After a PulseAudio
# restart the default drifts to sink.fast, the low-latency output, whose small
# buffer this path cannot sustain - playback then breaks up in bursts, the same
# fast-forward artefact. sink.primary-out is the one verified good
# (pcm0p tstamp advancing, avail_max healthy, no xruns), so pin it.
set -u

C=${1:-0}
SETTLE=${2:-25}
PH_UID=32011

log() { echo "a50-audio-route: $*"; }

set_ctl() { amixer -c "$C" cset "$1" "$2" >/dev/null 2>&1; }

pa() {
    su - phablet -c "XDG_RUNTIME_DIR=/run/user/$PH_UID pactl $1" 2>/dev/null
}

# Wait for the sound card to exist at all.
i=0
while [ ! -e "/proc/asound/card${C}" ] && [ $i -lt 60 ]; do
    sleep 1
    i=$((i + 1))
done
[ -e "/proc/asound/card${C}" ] || { log "card $C never appeared"; exit 0; }

# Let PulseAudio load the droid card and let the HAL program the mixer from its
# own mixer_paths.xml first; it leaves UAIF2 SPK at RESERVED and we set it
# afterwards. Applying before that happens is silently undone.
sleep "$SETTLE"

# --- the route ---
set_ctl "name='ABOX UAIF2 width'"   16
set_ctl "name='ABOX UAIF2 channel'" 2
set_ctl "name='ABOX UAIF2 rate'"    48000
set_ctl "name='ABOX SPUS OUT0'" SIFS0
set_ctl "name='ABOX UAIF2 SPK'" SIFS0
# ERAP/DSM is the TFA smart-amp reference the tfadsp IPC needs. It must be
# addressed by numid - amixer cannot match this control by name.
set_ctl numid=136 1

if amixer -c "$C" cget name='ABOX UAIF2 SPK' 2>/dev/null | grep -q ': values=1'; then
    log "speaker route applied: ABOX UAIF2 SPK = SIFS0"
else
    log "WARNING: ABOX UAIF2 SPK did not take; there will be no sound"
fi

# --- pin playback to the output that works ---
if pa 'list short sinks' | grep -q 'sink.primary-out'; then
    pa 'set-default-sink sink.primary-out' >/dev/null
    for i in $(pa 'list short sink-inputs' | awk '{print $1}'); do
        pa "move-sink-input $i sink.primary-out" >/dev/null
    done
    log "default sink pinned to sink.primary-out"
else
    log "sink.primary-out absent - is the droid card loaded?"
fi
