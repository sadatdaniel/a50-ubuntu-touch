#!/bin/sh
# Route ABOX playback to the speaker amplifier on the Galaxy A50.
#
# Nothing in the Ubuntu Touch stack sets ABOX's routing, and it does not
# persist (there is no /var/lib/alsa/asound.state here), so this has to run
# on every boot.
#
# UAIF2 is the speaker amplifier (TFA9872). That is stated by the vendor HAL's
# own /vendor/etc/mixer_paths.xml ("UAIF2 - Speaker AMP") and confirmed by the
# kernel at boot: "tfa98xx-aif-7-34 <-> UAIF2 mapping ok".
#
# The working chain is
#     RDMA0 (hw:0,0) -> SPUS OUT0 -> SIFS0 -> UAIF2 -> TFA9872
# i.e. the vendor's own "route-sifs0-to-uaif2" path, driven from
# playback_link 0.
#
# NOT "media-speaker" as written in mixer_paths.xml. That path uses
# route-rdma7-to-sifs1 + route-sifs1-to-uaif2, and the ABOX DSP firmware
# NACKs every PCMOUT command for channel 7 - its own log says
#     [PCMOUT:WARNING] ret(-110), param(7), NACK REPLIED: 20
# and RDMA7_STATUS stays 0, so the DMA never advances and userspace gets
# -EIO out of ALSA's wait_for_avail(). Channel 0 is accepted:
#     [PCMOUT:INFO] pcm_setbuffer: addr: 0x91000000, size: 48000, count: 2
#     [PCMOUT:INFO] pcm_trigger - ch: 0, on/off: 1
set -e
C=${1:-0}
set_ctl() {
    if amixer -c $C cset "$1" "$2" >/dev/null 2>&1; then
        echo "  ok   $1 = $2"
    else
        echo "  FAIL $1 = $2"
    fi
}

echo 'UAIF defaults (from mixer_paths.xml):'
set_ctl "name='ABOX Sampling Rate Mixer Min'" 48000
set_ctl "name='ABOX UAIF2 width'" 16
set_ctl "name='ABOX UAIF2 channel'" 2
set_ctl "name='ABOX UAIF2 rate'" 48000

echo 'speaker route:'
set_ctl "name='ABOX SPUS OUT0'" SIFS0
set_ctl "name='ABOX UAIF2 SPK'" SIFS0
# ERAP/DSM is the TFA smart-amp reference the tfadsp IPC needs; addressed by
# numid because its name contains spaces that amixer will not match by name.
set_ctl numid=136 1

echo 'result:'
for c in 'ABOX SPUS OUT0' 'ABOX UAIF2 SPK'; do
    printf '  %-18s %s\n' "$c" "$(amixer -c $C cget name="$c" 2>/dev/null | grep -m1 '^  : values=')"
done
