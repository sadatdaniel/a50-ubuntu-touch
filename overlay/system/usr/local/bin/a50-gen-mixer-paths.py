#!/usr/bin/env python3
"""Generate the A50's patched /vendor/etc/mixer_paths.xml.

Reads the stock vendor file and writes a corrected copy. Two changes, both
about getting media audio to the speaker amplifier on this device.

1. route-sifs1-to-uaif2: UAIF2 SPK = SIFS0, not SIFS1.

   The vendor's speaker path is RDMA7 -> SPUS OUT7 -> SIFS1 -> UAIF2. This
   ABOX DSP firmware NACKs every PCMOUT command for channel 7 - its own log
   at /sys/kernel/debug/abox/log-00 says

       [PCMOUT:WARNING] ret(-110), param(7), NACK REPLIED: 20

   and RDMA7_STATUS stays 0, so nothing ever reaches the amplifier. The HAL
   writes its audio to RDMA0 -> SPUS OUT0 -> SIFS0 (playback_link 0 in this
   same file), so the speaker has to follow SIFS0.

2. media-speaker, media-speaker2 and media-dual-speaker: drop
   route-sifs0-to-uaif0.

   With (1) applied, leaving UAIF0 on SIFS0 as well puts TWO consumers on one
   mixer output. It then drains at roughly double rate and playback sounds
   fast-forwarded. Speaker-only outputs do not need the codec.

   route-sifs0-to-uaif0 is deliberately left alone everywhere else - the
   headset combos need it, and so does every incall-* path. Removing it
   globally breaks call audio.

Why patch the HAL's own config rather than override the mixer from outside:
the HAL re-applies its routing on every stream and every call, so any external
override loses the race, and writing mixer controls mid-stream corrupts
playback (the same fast-forward artefact).
"""
import re
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "/android/vendor/etc/mixer_paths.xml"
DST = sys.argv[2] if len(sys.argv) > 2 else "/var/lib/lxc/android/mixer_paths.a50.xml"

SPEAKER_ONLY = {"media-speaker2", "media-speaker", "media-dual-speaker"}

# 3. incall paths that do NOT use the speaker: park UAIF2 on RESERVED.
#
#    `ABOX UAIF2 SPK` is a single global control, and change (1) points it at
#    SIFS0. Nothing in an earpiece or headset call path ever sets it back, so
#    it keeps whatever the last speaker playback left there - SIFS0 - and the
#    call then has UAIF0 *and* UAIF2 draining one mixer output. Same double
#    drain as (2), same fast-forwarded audio, but arriving as leftover state
#    rather than from the path itself, which is why it looks intermittent:
#    play something on the speaker first and the next call is fast.
#
#    These paths need UAIF0 (the codec carries the earpiece), so the fix is
#    the mirror of (2) - disconnect the *other* consumer instead. Item #0 of
#    that enum is RESERVED, which is the disconnected value.
INCALL_NO_SPEAKER = {
    "incall-handset",
    "incall-headset",
    "incall-bt-sco-headset",
    "incall-usb-headset",
    "incall-hearing-aid",
}

s = open(SRC).read()

old = ('<path name="route-sifs1-to-uaif2">\n'
       '\t\t<ctl name="ABOX UAIF2 SPK" value="SIFS1" />')
new = ('<path name="route-sifs1-to-uaif2">\n'
       '\t\t<!-- A50: SIFS0, not SIFS1. SIFS1 is fed from RDMA7 and this ABOX\n'
       '\t\t     DSP NACKs channel 7, so the amplifier would get nothing. -->\n'
       '\t\t<ctl name="ABOX UAIF2 SPK" value="SIFS0" />')
if s.count(old) != 1:
    sys.exit("E: route-sifs1-to-uaif2 anchor found %d times" % s.count(old))
s = s.replace(old, new)

# Paths where the speaker IS used in a call. Here UAIF2 must stay on SIFS0
# (that is the whole point of change 1), so the other consumer has to go -
# exactly as for the media-speaker paths.
INCALL_SPEAKER = {"incall-speaker", "incall_nb-dual-speaker"}

n = 0
m_ = 0


def fix(m):
    global n, m_
    name, body = m.group(1), m.group(2)
    if name in (SPEAKER_ONLY | INCALL_SPEAKER) and "route-sifs0-to-uaif0" in body:
        body = body.replace(
            '\t\t<path name="route-sifs0-to-uaif0" />\n',
            '\t\t<!-- A50: dropped, see route-sifs1-to-uaif2. Two consumers on\n'
            '\t\t     SIFS0 drain it at double rate and audio plays fast. -->\n')
        n += 1
    if name in INCALL_NO_SPEAKER:
        body += ('\n\t\t<!-- A50: UAIF2 is a global control left pointing at SIFS0 by\n'
                 '\t\t     the last speaker playback. This path needs UAIF0 on SIFS0,\n'
                 '\t\t     so disconnect UAIF2 instead or both drain it and the call\n'
                 '\t\t     plays fast. -->\n'
                 '\t\t<ctl name="ABOX UAIF2 SPK" value="RESERVED" />')
        m_ += 1
    return '\t<path name="%s">%s\n\t</path>' % (name, body)


s = re.sub(r'\t<path name="([^"]+)">(.*?)\n\t</path>', fix, s, flags=re.S)
if n != len(SPEAKER_ONLY) + len(INCALL_SPEAKER):
    sys.exit("E: dropped uaif0 from %d paths, expected %d"
             % (n, len(SPEAKER_ONLY) + len(INCALL_SPEAKER)))
if m_ != len(INCALL_NO_SPEAKER):
    sys.exit("E: parked UAIF2 in %d paths, expected %d" % (m_, len(INCALL_NO_SPEAKER)))

open(DST, "w").write(s)

# Never ship a file the HAL cannot parse - a malformed one silently loses audio.
import xml.dom.minidom
xml.dom.minidom.parse(DST)

print("a50-mixer-paths: wrote %s (speaker paths fixed: %d, XML valid)" % (DST, n))
