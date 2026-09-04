# Provisioning notes — things a fresh install needs

Everything here is a one-time (or after-reflash) operation on the device
itself. It is not part of the build, and none of it belongs in `overlay/`
because it changes storage or state rather than shipping a file.

For the runtime *workarounds* — the ones standing in for kernel fixes — see
[`scripts/apply-device-workarounds.sh`](../scripts/apply-device-workarounds.sh)
instead.

## The rootfs image is 4 GB and that is genuinely tight

A fresh install lays down `/userdata/rootfs.img` at about 4 GB, loop-mounted
at `/`. That is roughly the UBports norm and is not a mistake: on Ubuntu Touch
the things that grow without bound do **not** live on the rootfs.

| Path | Filesystem | Why it does not fill the rootfs |
|---|---|---|
| `/home`, `/userdata` | `/dev/sda32`, 111 GB | user data, photos, downloads |
| `/var/lib/snapd`, `/snap` | `/dev/sda32` | snaps are bind-mounted onto userdata |
| click apps | under `/home` | app installs land on userdata |

So the rootfs holds only the OS. It gets tight for one specific reason:
**Ubuntu Touch expects OTA image updates, not `apt`.** Running `apt upgrade`
is off the beaten path and is what runs it out of room:

```
More space needed than available … 353 kB > 0 B
you don't have enough free space in /var/cache/apt/archives/
```

### Reclaim first, before resizing

On this device the journal alone had reached **525 MB** after a heavy
debugging session — more than twice the free space:

```sh
journalctl --vacuum-size=50M     # freed 483 MB here
apt-get clean
rm -rf /var/lib/apt/lists/*      # apt update regenerates these
```

Then cap it so it cannot recur, which matters on a small rootfs:

```sh
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/50-a50-cap.conf <<'EOF'
[Journal]
SystemMaxUse=50M
SystemMaxFileSize=10M
RuntimeMaxUse=16M
EOF
systemctl restart systemd-journald
```

### Growing the rootfs image

`/userdata/rootfs.img` is a plain file on a 111 GB partition, and ext4 grows
online, so this needs no reboot and no unmount:

```sh
truncate -s 8G /userdata/rootfs.img   # grow the backing file
losetup -c /dev/loop0                 # make the loop device see the new size
resize2fs /dev/loop0                  # grow the filesystem into it
df -h /
```

Result here: `4.0G/211M free` → `7.9G/4.0G free`.

**8 GB, not 32 or 64.** Nothing on the rootfs grows without bound (see the
table above), so a larger image would just take space from the partition that
actually stores data. Growing again later is easy; shrinking is not.

Confirm the loop device before running this — it is `loop0` here, but
`losetup -a` is the authority:

```
/dev/loop0: [66320]:32 (/userdata/rootfs.img)      <- the rootfs
/dev/loop1: … (/var/lib/lxc/android/android-rootfs.img)   <- the Android GSI
/dev/loop2: … (/data/per_boot/zram_swap)
```

## OpenStore on 26.04 — FIXED by co-installing the old SONAMEs

**Resolved.** OpenStore runs on 26.04; the section below records the wrong
turns taken first, because two of them are traps worth not repeating.

Ubuntu 26.04 ships libxml2 2.15, which bumped the SONAME
`libxml2.so.2` -> `libxml2.so.16`. That is an Ubuntu-wide change, not a UT
one, and it breaks any click built against the older framework. It is a
**known upstream 26.04 issue** - other testers report the identical error,
and `morph-browser` is hit by it too.

Differing SONAMEs are *designed* to co-exist, so the fix is simply to
install the genuine old libraries alongside the new ones:

```sh
# source them from the 24.04 rootfs image rather than downloading
mount -o loop,ro /userdata/rootfs-24.04.img /mnt/r24
L=/usr/lib/aarch64-linux-gnu
cp -a /mnt/r24$L/libxml2.so.2.9.14 $L/ && ln -sf libxml2.so.2.9.14 $L/libxml2.so.2
cp -a /mnt/r24$L/libicu*.so.74* $L/
ldconfig
```

`libicuuc.so.74` and friends are needed because libxml2 2.9 links ICU 74;
the dependency surfaces only once libxml2.so.2 is in place. After both,
`ldd` on the OpenStore binary reports nothing missing and the app launches
and stays up.

`libsnapd-qt.so.1` needs no action - the click already bundles its own copy
in `lib/aarch64-linux-gnu/`, it simply is not on the loader path when the
binary is run by hand.

### Two things NOT to do

* **Do not symlink a renamed library to the old name.** Pointing
  `libsnapd-qt.so.1` at `libsnapd-qt-2.so.1` links and starts, then dies
  with `corrupted size vs. prev_size` - the ABI differs and it corrupts the
  heap. Co-installing the *genuine* old library is safe; aliasing a
  different one is not.
* **Do not switch the whole rootfs for this.** 24.04-2.x was built and
  booted for this reason and **bootloops at ~15s** on this device, needing
  TWRP to rename the images back. The image is kept at
  `/userdata/rootfs-24.04.img` and is useful precisely as the source of
  these libraries; `deviceinfo` remains on 26.04-1.x.

### Search before improvising

This cost a rootfs build and a bootloop that a web search would have
avoided: the SONAME bump and the co-install fix are both publicly
documented. Check for a known fix before building anything.

## Appendix: the original (wrong) reading of the OpenStore failure

Not a port bug, and not AppArmor — other click apps (Terminal, the
preinstalled set) launch fine. The preinstalled OpenStore 4.1.0 targets the
`focal` / `ubuntu-sdk-20.04` framework and links `libsnapd-qt.so.1`, while the
26.04 rootfs ships only the renamed `libsnapd-qt-2.so.1`:

```
./openstore: error while loading shared libraries: libsnapd-qt.so.1:
cannot open shared object file: No such file or directory
```

4.1.0 is the newest OpenStore, so there is no newer build that fixes it — the
mismatch is inherent to running a focal-framework click on a 26.04 rootfs.

**Do not symlink `libsnapd-qt.so.1` → `libsnapd-qt-2.so.1`.** Tried: it links
and starts, then dies with `corrupted size vs. prev_size` — the ABI differs
and it corrupts the heap. Reverted.

This is the "26.04 churn" [`conventions.md`](conventions.md) warned about when
choosing the release. Options are to bundle a genuine focal `libsnapd-qt.so.1`
into the click's own `lib/` (which is already how it carries
`libsnapd-glib.so.1`), or to fall back to the documented 24.04-2.x rootfs.
