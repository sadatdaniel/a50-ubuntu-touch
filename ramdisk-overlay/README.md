# `ramdisk-overlay/` — device fixes for the halium-boot initramfs

`make-bootimage.sh` builds the boot ramdisk by taking the upstream halium-boot
initramfs and **appending a second cpio archive made from this directory**.
Later entries win, so a file placed here at the same path replaces the upstream
one. That is the sanctioned way to patch the initramfs; do not fork it.

This directory is **empty on purpose**. The four fixes below are known to be
needed on this device under Droidian, but Ubuntu Touch downloads a *different*
initramfs (`initramfs-tools-halium`, `dynparts` release) whose `init` and
`scripts/halium` are not the same file. Copying Droidian's overlay in blind
would be exactly the "an identical error string is not an identical cause"
mistake this project has already paid for.

**The procedure is: fetch the upstream ramdisk, unpack it, read its `init`,
then port each fix to what is actually there — one at a time, boot-testing
each.**

```sh
curl -L -o initrd.img \
  https://github.com/halium/initramfs-tools-halium/releases/download/dynparts/initrd.img-touch-arm64
mkdir x && cd x && gzip -dc ../initrd.img | cpio -idmv
```

## The four fixes, and why each is expected to be needed again

Full diagnoses in [`a50-droidian/docs/boot.md`](https://github.com/sadatdaniel/a50-droidian/blob/main/docs/boot.md);
the editable text of the working Droidian ramdisk is tracked at
`a50-droidian/initrd/tree/`.

### 1. `mknod ${rootmnt}/dev/kmsg c 1 11` before `exec run-init`

The session-defining bug. `devtmpfs` does not create `kmsg` in the real root's
`/dev` the way it does for the initramfs's own. systemd needs `/dev/kmsg` very
early — before the journal socket exists — as its bootstrap logging fallback,
and without it calls a silent `exit(1)`. The kernel then panics, because that
is genuine PID 1 exiting:

```
Attempted to kill init task group! exitcode=0x100
```

A clean `exit(1)`, not a crash. **This is a property of the device's kernel and
of systemd, not of Droidian**, so Ubuntu Touch's systemd is expected to hit it
identically. Check first; it is the single highest-value thing in this list.

### 2. Skip the `/proc` and `/sys` moves

Real systemd mounts both itself during early startup. Skipping the moves fixed
a separate reproducible crash on this device. Whether UT's initramfs even does
the moves has to be read, not assumed.

### 3. Force `BOOT_MODE=halium`

This device reports `androidboot.mode=charger` whenever USB is connected —
which it always is while debugging — and stock `identify_boot_mode()` reads
that as `BOOT_MODE=android`, sending boot down a different, uninstrumented path
roughly half the time depending on charger-detect timing.

Not upstream-correct: it is a debugging determinism override, and it should not
survive into a shippable image. But during bringup it removes an entire class
of "why did that boot differently" and it is worth having from the first boot
attempt.

### 4. Fall back to `/dev/sda32` when the partition search finds nothing

`mountroot()` looks for by-name symlinks. This device's minimal
`systemd-udevd` never creates them, so the search always comes back empty.

The correct fix is real udev rules, and there is a useful lead: **`/dev/disk/by-partlabel/`
IS populated on this device** even though both Android `by-name` directories
are absent — `boot=sda14`, `recovery=sda15`, `misc=sda19`, `userdata=sda32`.
So a rule keyed on partlabel is likely to work, and would be a genuine
improvement over Droidian's hardcoded fallback rather than a copy of it.

## Getting the boot messages out

Droidian's ramdisk carries a USB RNDIS gadget and a raw shell on
`192.168.2.15:23`. Upstream halium-boot offers a telnet debug shell on the same
address when boot fails — the UBports guide's own instruction is
`telnet 192.168.2.15`. Same address, and one is a known-working reference for
the other if it does not come up.
