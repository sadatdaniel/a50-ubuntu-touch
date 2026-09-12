# Session handoff 16 - aa6 boot validation

2026-09-12 12:08 CEST. Handoffs 07-15 preserved. Earlier usage-limit review
blocked further checks; user resumed and tools work again.

aa6 completed successfully at 08:30 CEST, exit 0. Build began 07:35, so total
elapsed time was about 55 minutes. Source a50-halium ac4c288; full/ubports.
Kernel Image SHA256 3c96c0ff64b441426346e0dd376f42c13389c9e9efe7750713fbff5efb44699c.
Actual config: DEFAULT_SECURITY=apparmor, SECURITY_APPARMOR=y,
HARDENED_USERCOPY=y. All corrected socket lifecycle code compiled.

Packed with the existing verified donor 90c281f8... using make-boot-image.sh.
boot-aa6.img: 55,851,008 bytes, SHA256
005a3b57b65bc988888bb57ba6bae86dff94cdf547616bd0250eee3ab3d6455c.
Ramdisk unchanged, SHA256 e78e8cb8d5269e81852a1b417d0b28c98f2c4bce8bcb035e2cab19bd9cfd9ac4.

At 12:08 phone still on aa4, uptime 9h55m, available memory 1830 MiB, swap
482/2815 MiB. USB CONFIGURED and SSH working. Guards staged in
/userdata/a50-session14; syntax passed; no guard unit installed yet.
Next: verify upload, arm early restore/capture, flash with image-sized read-back,
normal Android boot, verify fallback restoration and direct SO_PEERSEC probe.
Then test actual camera authorization. Suspend remains untested.

Waydroid lifecycle fix 3f29bc9 is pushed and tested: new socket binds after shell
restart, user confirmed UI. No reinstall. Cutout remains user-confirmed working.
Next health sample due 12:38 CEST.

## aa6 normal boot passed

Flashed 55,851,008 bytes; full image-sized read-back matched 005a3b57... .
Boot ID 3cc1346a-73e9-4ca9-803e-4494c2fbb8a1. Guard restored aa1 on disk at
12:11:29; fallback prefix c57250fa... verified. Android boot_completed=1,
lightdm/AppArmor active. Peer probe now reports unix_mediation=yes and
peer_label=unconfined, replacing aa4's errno 92. Running kernel is aa6.

Camera app launched and remains confined/running. Media-hub successfully loads
the shutter sound; its previous empty AppArmor context abort is gone. CLI
lomiri-app-launch itself aborted with `Lost our connection with the registry`
after reporting Started; distinguish that CLI abort from the application.
Asked user whether camera preview/permission prompt/error is visible; pending.

Separate camera HAL failure at 12:12:53: Samsung provider SIGABRT in
SehLegacyCameraProviderImpl_4_0::sTorchModeStatusChange called from
HAL3_camera_device_open. Abort text: unchecked HIDL return,
Status(EX_TRANSACTION_FAILED): DEAD_OBJECT. Do not bypass permissions or patch
away the abort without investigating which callback client died.

Saved /userdata/a50-session14/aa6-dmesg.txt, aa6-journal.txt and
aa6-android-logcat.txt. Cleanup completed: original capture unit restored,
temporary guard/drop-in/wants removed, root RO. On-disk boot remains aa1;
keep this distinction explicit before any reboot or suspend test.
