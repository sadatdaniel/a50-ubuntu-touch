# Session handoff 13 - camera permissions, cutout, official OTA path

2026-09-12. Preserve handoffs 07-12. User requests reproducible image publication,
new handoff, camera error diagnosis, notch configuration and UBports OTA release
conventions. Existing suspend/resume objective remains active.

## Camera evidence

Normal aa4 boot is still running (boot ID 208560ab-091a-4e69-ac9e-0f6ed52fd980).
At 02:16:51 camera launch caused media-hub PID 6656 to abort:
`apparmor::Context cannot be created for empty name.` The camera process has
profile `camera.ubports_camera_4.1.1 (enforce)`. The kernel exposes no AppArmor
features/network directory. Missing socket peer labeling is the next concrete
problem; an empty permissions list is consistent with authorization failing
before a grant is recorded, but is not independently diagnosed yet.

## Next build (already running)

Docker a50-kbuild-aa5, ID 9676546189bc42831df7168d4bb2748cdc91986a4a3b05b312e1e8d862278926,
source volume a50-ksrc-aa5, output a50-halium/out-aa5, --profile full --apparmor
ubports --firmware /fw. New mode applies the two exact upstream 4.14 AppArmor
socket patches and selects CONFIG_DEFAULT_SECURITY=apparmor via the existing
step2 helper. aa4 and its source volume are untouched. Build script syntax
passed. Source changes still need commit/push and build/device verification.

## Publication and OTA

aa4 staged under a50-ut-out/session-13/aa4-release with boot.img, Image,
System.map, build-manifest.txt, actual kernel.config, firmware checksums and
REPRODUCE.md. Target kernel commit 2b1c523. Keep it a development baseline,
not an OTA/stable release. Public donor verified from GitHub release asset
digest: a50-ubports-halium-2026-09-06/boot.img, SHA256 90c281f8... .

Read UBports finalization/recovery/local OTA docs and cloned official adaptation
tools to a50-ut-out/session-13/adaptation-tools at
5112934e3db4af048beb191750b6f35b151f7a7f. Existing port explicitly disables
recovery; build.sh clones unpinned tools; custom release scripts are not yet a
validated OTA path. Need unified recovery, verified fstab, actual system size
and layout checks, local OTA test, then installer/channel registration.
Do not overwrite TWRP or move userdata until recovery artifacts and backups
are prepared and verified. Do not publish the local-OTA signature bypass.

Read display-cutout guide: physical-pixel DeviceInfo rectangles and panel height.
Current a50.yaml has no cutout keys. Need vendor geometry or helper measurement;
do not copy another phone's notch dimensions. Notch work remains pending.

Next health sample due 02:44 CEST. Current Wi-Fi address 192.168.179.86;
USB 10.15.19.82. On-disk boot is aa1 fallback; currently executing aa4.
