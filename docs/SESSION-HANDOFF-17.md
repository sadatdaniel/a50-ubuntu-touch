# Session 17 — video mode failure on aa6 (2026-09-12)

User confirmed live camera preview, then reported that entering video / starting recording closes or crashes Camera. Photo capture and video recording are not verified working.

Read-only inspection around 12:19 CEST found the same camera process (46689) still alive, sleeping in `binder_ioctl_write_read`; media-hub (7350) also remained alive. This may be a blocked camera operation rather than process termination; a single wait-channel sample does not prove a deadlock. Camera logs report unknown viewfinder resolutions and unsupported image size `QSize(-1, -1)`. These messages alone do not establish the cause.

Trust-store explicitly returned `answer: granted` for this camera request. Media-hub resolved the enforced `camera.ubports_camera_4.1.1` profile correctly. No recent denial or segfault appeared in the targeted dmesg scan. The Android crash buffer contains the already-known provider abort at 12:12:53 CEST, before the reported video failure; do not attribute that earlier abort to the later video action.

Local private diagnostic scripts and output are under `a50-ut-out/session-14/read-video-*.sh` and `video-crash-summary.txt`. Attempted to foreground the existing camera through lomiri-app-launch; the command remained running at the last check. No fixes or kernel changes made for this failure yet.

Next: capture the blocked process threads and Android service state, consult upstream Qt Ubuntu camera backend / Halium video recording guidance, and reproduce with timestamped logs. Preserve the successful aa6 preview/AppArmor state. Suspend remains unverified. The on-disk boot remains aa1 fallback as documented in session 16.
