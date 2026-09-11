# Session handoff 11 - completed aa4 build, boot validation pending

2026-09-12, resumed after usage-limit rejection. Handoffs 09 and 10 preserved.
Previous work made progress: source/config isolation verified, remaining
UBports AppArmor patches audited. Handoff 10 commit was rejected by automatic
approval review due to the usage limit; it remained untracked at resumption.

## Revalidated state at 01:55 CEST

- Existing a50-kbuild-aa4 finished successfully (exit 0) at 19:37:10 UTC Sep 11.
  No replacement build was started. Manifest includes security-hook-default.
- Image SHA256 ee6a4092f91719fb6f7762b4db5388528e4bc61cb9bd4c5d36df765025784684.
- Packed with the verified UBports donor using the existing packing script.
  boot-aa4.img: 55,785,472 bytes, SHA256
  8f335d564d8b50b79cb3e69cd2c4a2359223bd9225995616e23f31f5574741b6.
- Phone still on aa1, boot partition read-back c57250fa...; uptime ~5h,
  available memory 1602 MiB, swap 265 MiB, lightdm active.
- New coredump since last sample: Samsung thermal service SIGABRT at 22:10:56.
  Record for later; keep the AppArmor issue first.
- USB reports DISCONNECTED; Wi-Fi 192.168.179.85 is working. Asked owner to
  reconnect cable before flashing. Next sample due 02:25 CEST.

## Plan

Prepare the same guarded host-only boot as 09, substituting only the aa4 hash.
Keep Android masked for this first test, capture early kernel logs, and restore
aa1 on disk automatically before the failure point. Verify AppArmor and several
minutes of host stability before any separate vendor compatibility test.
Do not infer that the complete port works from a host-only boot.
