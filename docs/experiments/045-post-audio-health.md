# Post-audio reboot health checkpoint

3 October 2026, aa13 kernel and Ubuntu Touch 26.04. Speaker playback is
user-confirmed normal before and after the ordinary authenticated reboot.
Both system and user managers report zero failed units. Package audit is
clean and root is read-only. Root has about 1.3 GiB free; userdata about
97 GiB. No new kernel/shell crash was found in the checked boot journal.
These checks are bounded diagnostics, not proof of complete system stability.

AppArmor is enabled (Y). The fresh boot journal contains enforced D-Bus
denials for the confined YouTube application attempting desktop Chromium
screen-inhibition/MPRIS APIs and content-hub HandlerActive. This demonstrates
active mediation, but the full controlled allow/deny probe and app-function
checks remain required. Do not disable AppArmor to silence these denials.

RealtimeKit repeatedly reports that it cannot make itself realtime. Its
CAP_SYS_NICE is present, while its CPU cgroup cpu.rt_runtime_us is zero and
CONFIG_RT_GROUP_SCHED=y. This is a scheduling lead, not an audio routing fix.
The [official Halium kernel checker](https://github.com/Halium/halium-boot/blob/master/check-kernel-config)
lists CONFIG_RT_GROUP_SCHED among disabled options. A conventional kernel
configuration correction should be evaluated with the next kernel candidate;
no live CPU-budget or privilege workaround was applied at this checkpoint.

Bluetooth reports unsupported advertising-monitor reset and an RFCOMM voice
gateway socket failure. CONFIG_BT_RFCOMM, BT_RFCOMM_TTY, BT_HIDP, UHID and
BT_BREDR are already enabled, so blindly adding those flags cannot explain
this instance. Profile/socket initialization and keyboard reconnection remain
unverified. OBEX also reports a missing Evolution Sources5 registry service.
These warnings are recorded, not claimed resolved.

Fresh suspend/resume, Bluetooth keyboard, microphone/calls and remaining
release checklist validation are still open. The remote recording-library
build is the immediate camera dependency. No new kernel or Android framework
library was installed during this health check. Keep raw phone logs private.

At 22:55 CEST the load average was about 17, while a three-sample vmstat
check reported 98–100% CPU idle, no swap activity and zero I/O wait in the
interval samples. Seventeen tasks appeared in D state: eight tz workers,
scsi_srpmb_work, ree_time, tz_iwsock and six simpleinteractive workers.
This does not show CPU saturation or prove these workers are faulty.
Their wait paths need privileged bounded diagnostics before any kernel fix
is justified; no process was terminated or scheduling setting changed.
