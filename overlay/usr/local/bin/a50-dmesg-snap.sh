#!/bin/sh
# Snapshot the kernel ring buffer at fixed UPTIMES (not delays from unit
# start - the unit itself only starts around t=5s, which is already late).
#
# Why this exists: the buffer holds ~8600 lines, and once the Android
# container's ueventd runs restorecon across /sys it emits thousands of
# "Could not set context" lines in about a second, evicting the entire
# boot - including the abox probe. The first snapshot is therefore taken
# IMMEDIATELY, before anything else, and is the one that matters.
dmesg > /userdata/dmesg-boot-first.txt 2>/dev/null
echo "first snapshot at uptime $(cut -d' ' -f1 /proc/uptime)" > /userdata/dmesg-boot-first.when
for t in 7 9 12 20 45 90; do
    while :; do
        now=$(cut -d. -f1 /proc/uptime)
        [ "$now" -ge "$t" ] && break
        sleep 1
    done
    dmesg > /userdata/dmesg-boot-${t}s.txt 2>/dev/null
done
