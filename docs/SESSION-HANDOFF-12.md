# Session handoff 12 - aa4 survives the AppArmor panic

2026-09-12 02:07 CEST. Handoffs 07-11 preserved.

- Cable reconnect restored CONFIGURED and USB SSH at 10.15.19.82.
- Re-read UBports AppArmor guide and Android 11 init setenv documentation.
- Flashed aa4, 55,785,472 bytes; read-back SHA256
  8f335d564d8b50b79cb3e69cd2c4a2359223bd9225995616e23f31f5574741b6.
- Isolated host boot: Android masked, real udev coldplug and early capture enabled.
- Boot ID 90f4c7d5-bdf0-47ab-aa62-566d2bdb1b13; AppArmor enabled, 235 profiles
  loaded, journald active. Previous aa3 panicked at 8.7 seconds; aa4 survived.
- Guard restored aa1 on disk at 02:05:21, read-back c57250fa... verified.
  Running kernel remains aa4; subsequent reboot will run aa1.
- New warnings: Wi-Fi firmware load -11 while Android STOPPED. Capture and
  reassess with Android running; do not diagnose this as a new kernel regression yet.
- Evidence on phone: /userdata/a50-session11/aa4-host-dmesg.txt and
  aa4-host-journal.txt. Temporary guard/setup/cleanup scripts in that directory,
  mirrored in a50-ut-out/session-11. Cleanup restores the original capture unit,
  removes guard/wants and unmasks Android; it does not reboot.

Next: finish several minutes host observation, then separately test the prepared
Halium libselinux_stubs vendor-service override. Full UBports socket mediation
patches remain pending (handoff 10); do not claim full app confinement or suspend
fixed. Preserve aa1 fallback and original mount.sh before vendor test.

## Normal boot verified at 02:14

- Host-only aa4 remained alive >3 minutes. Android then started separately with
  the prepared vendor RC preload; PID 13618 stayed alive and mapped the existing
  /system/lib64/libselinux_stubs.so. No coredumps. A second service-manager PID
  belonged to Waydroid, not a restart (verified cgroups).
- Live mount.sh preserved at /userdata/a50-session11/mount.sh.before. Appended
  only the repository-equivalent vendor RC bind. Generated RC exactly matches
  the previously tested generation. Original vendor RC SHA256 remains
  8dda986d89a2ab17268872e823eaa5d3899466c6a81693eddbeebb2070cd12a8.
- Delayed Android startup required retrying compositor; Wi-Fi stayed unavailable.
  A subsequent normal aa4 boot resolved these startup-order symptoms: AppArmor,
  Android and lightdm active, sys.boot_completed=1, Wi-Fi 192.168.179.86,
  swap 2815 MiB configured, available memory 1899 MiB at first sample.
- Normal boot ID 208560ab-091a-4e69-ac9e-0f6ed52fd980. Guard restored aa1 on
  disk at 02:13:16; image-sized read-back verified. Running kernel is aa4.
- Removed all temporary guard units/wants and early-capture drop-in using
  cleanup-test.sh. Original capture unit restored; Android unmasked; root RO.
  Kept the now device-tested vendor RC override. Next reboot uses aa1 fallback.
- Evidence: /userdata/a50-session11/aa4-normal-{dmesg,journal}.txt. Copy each
  file separately with pscp (multiple remote source operands are unsupported).
- Remaining failed units: ssh.service and usb-tethering.service; USB SSH works
  through the existing initramfs listener. Do not treat these as new crashes.
- Next health sample due 02:44 CEST. Monitoring is only performed while active;
  no claim of a background timer or uninterrupted overnight sampling.

Next target: complete UBports 4.14 AppArmor socket patches, then test confined
apps/camera and only then suspend/resume. aa4 fixes the demonstrated panic;
it does not yet supply all UBports AppArmor features. The step3 helper's old
pre-console/layout hypothesis is disproven and needs its comments corrected.
Keep aa4 and its source volume intact as the next known test baseline.
