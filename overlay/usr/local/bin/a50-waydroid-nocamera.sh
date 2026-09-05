#!/bin/sh
# Stop Waydroid's camera services, which crash-loop on this device.
#
# Waydroid's vendor image ships its own android.hardware.camera.provider@2.4
# service. This device's camera does not work under the port at all (the Exynos
# FIMC-IS driver NULL-derefs in fimc_is_devicemgr_open and can panic the kernel
# - see docs/status.md), so that provider dies and Android init restarts it
# forever. Measured: its pid changed every ~6 seconds -
#
#   3214 -> 3217 -> 3221   over 12 s
#
# while the Halium container's own sec-camera-provider-4-0 stayed on pid 186.
# So the loop is Waydroid's, not the host's. It burns CPU and battery
# continuously and repeatedly pokes a driver that is known to be able to panic
# the kernel, so it is worth stopping outright.
#
# Runs as root from a waydroid-container.service drop-in, because
# `waydroid shell` requires root and the session unit is a user unit.
#
# See docs/experiments/013-waydroid.md.
set -u

# The container is started, but Android inside it is not up yet.
i=0
while [ "$i" -lt 90 ]; do
    if [ "$(waydroid shell -- getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
        break
    fi
    i=$((i + 1))
    sleep 2
done

for svc in vendor.camera-provider-2-4 cameraserver; do
    waydroid shell -- setprop "ctl.stop" "$svc" 2>/dev/null
done

# Report what actually happened rather than assuming it worked.
sleep 2
for svc in vendor.camera-provider-2-4 cameraserver; do
    echo "waydroid camera: init.svc.$svc = $(waydroid shell -- getprop "init.svc.$svc" 2>/dev/null | tr -d '\r')"
done
