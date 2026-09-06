#!/bin/sh
# Unblock Samsung's GPS daemon, which waits for a boot animation that a Halium
# container never runs.
#
# /vendor/bin/hw/gpsd takes its lock file, reads ONE property, and then sits in
# a 250 ms nanosleep poll loop forever: one thread, no config read, no device
# opened, no log output. The property is service.bootanim.exit - the only
# plausible candidate in the exported_system_prop context that its own strings
# reference. On stock Android SurfaceFlinger's boot animation sets it to 1 when
# it finishes. In this container nothing ever does, so gpsd waits forever.
#
# The visible symptom is one level up: the GNSS HAL connects to gpsd's abstract
# unix socket @GNSSND, gets ECONNREFUSED because gpsd never bound it, and spins
#   Critical Error: lal_state_handle_transition: curST:1 pendingST:2
# three times a second for as long as any app holds a location session.
#
# With the property set, gpsd goes from 1 thread to 12, binds @GNSSND, opens
# /dev/gnss_ipc, and real satellites arrive. See
# docs/experiments/009-gps-permissions.md.
set -eu

A="lxc-attach -n android --"

$A /system/bin/setprop service.bootanim.exit 1

# gpsd only reads the property at startup, so restart it now that it is set.
$A /system/bin/setprop ctl.restart gpsd

# Wait for gpsd to actually bind the socket the HAL needs, rather than assuming.
i=0
while [ $i -lt 40 ]; do
    if grep -q GNSSND /proc/net/unix 2>/dev/null; then
        echo "gnss: gpsd bound @GNSSND"
        break
    fi
    i=$((i + 1))
    sleep 0.25
done
if ! grep -q GNSSND /proc/net/unix 2>/dev/null; then
    echo "gnss: WARNING gpsd did not bind @GNSSND" >&2
fi

# The HAL caches its failed connection, and lomiri-location-service binds the
# HAL once at startup - so both need to come up after gpsd is ready.
$A /system/bin/setprop ctl.restart sec_gnss_service
systemctl try-restart lomiri-location-service || true
echo "gnss: done"
