# 063 — Upstream camera fix: GSI 1585 replaces 1542

19 October 2026, A50 on runtime-firmware kernel rf2. Owner present.

## Upstream

[Halium/hybris-patches#84](https://github.com/Halium/hybris-patches/pull/84)
was merged on 17 October by NotKit. He reworked it: `get_audio_flinger()` now
always returns null, since neither Droidian nor Ubuntu Touch runs
AudioFlinger and every libaudioclient caller handles null. Commit `7d83d27b`
on `halium-11.0`. UBports Jenkins `generic_arm64` build **1585** (18 October)
is the first built from it; 1583/1584 still use `790b3792`.

## Image checks

Tarball `d08a92e4…` (131,790,404 bytes), archived in release
`inputs-20261017`, with sources in `scripts/experiments/gsi1585-used-repos.txt`.
`android-rootfs.img` is `da6c3373…` (473,751,552 bytes). In 1585 both
`/system/lib/libaudioclient.so` and `/system/lib64/libaudioclient.so` differ
from 1584, and the wait loop's "AudioFlinger not published" string is
absent; it is present in 1584.

## Phone test

`scripts/experiments/swap-gsi-image.sh` replaced the installed image
(1542 `e53c4d7f…`, which matched `gsi.lock`) with hash guards. The verified
1542 copy is kept at `/userdata/a50-gsi-test/android-rootfs-1542.img`. After a
cold boot: 1585 is active, root RO, AppArmor Y, zero failed units, and
Samsung's camera provider runs. **The owner confirms lock screen, sound, and
camera record → Stop → playback.** A 5.6 MB recording was written. No
temporary library mounts were used, unlike experiment 044.

`gsi.lock` now pins 1585. The custom PR 84 GSI build (about 250 GiB builder)
is no longer needed.

## Remaining checks

Repeat recordings and record again after a reboot; calls (SIM moved),
Bluetooth audio, sleep and Wi-Fi on 1585; future daily GSIs keep `7d83d27b`.

Rollback: `swap-gsi-image.sh /userdata/a50-gsi-test/android-rootfs-1542.img
e53c4d7f… da6c3373… /userdata/a50-gsi-test/android-rootfs-1542.img`, then
reboot. `gsi.lock` goes back with git.
