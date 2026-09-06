# Cutting a release

A release of this port is **one file**: a recovery-flashable zip that installs
a boot image and a rootfs and nothing else. This file is how it is built, what
is verified, and where the build deliberately departs from UBports' own
scripts.

## Two builds, every release

| | |
| --- | --- |
| `ubuntu-touch-a50-<release>-<date>.zip` | the normal one: the published Ubuntu Touch rootfs plus this port, SSH off |
| `ubuntu-touch-a50-<release>-devel-<date>.zip` | the debug one: the same, plus sshd with password and root login, root's password set, `usb-tethering` enabled, `ADBD_SECURE=0` |

Ship both. Until the port has been tested by people who are not its author, the
debug build is the one to point testers at - a bug report with a journal in it
is worth ten that say "it did not boot".

`scripts/release/add-devel-access.sh` is the whole difference, and it does not
reuse upstream's devel-flashable trick: `prepare-fake-ota.sh` writes
`/etc/init/ssh.override` and `/etc/init/usb-tethering.conf`, which are upstart
jobs, and a 26.04 rootfs has no `/etc/init` at all. Those files would be
created, released and silently ignored. Everything in `add-devel-access.sh` was
checked against the units that are in the image - including preferring
`ssh.service` over `ssh.socket`, because `lxc-android-config-disable-ssh-socket.service`
is enabled and disables the socket on first boot by design.

The password is weak and documented on purpose. Do not quietly change it: the
README, the motd, `/etc/a50-image-variant` and the installer's own output all
say `1234`.

## What a release contains

```
ubuntu-touch-a50-26.04-1.x-YYYY-MM-DD.zip
├── META-INF/com/google/android/update-binary   TWRP entry point (a shell script)
├── META-INF/com/google/android/updater-script  a stub; nothing uses it
└── install/
    ├── a50-install.sh    the install, readable and dry-runnable on its own
    ├── boot.img          kernel + Halium initramfs
    ├── rootfs.img.gz     Ubuntu Touch 26.04 + Halium 11 GSI + this port
    ├── manifest.txt      what this build is made of
    └── SHA256SUMS        of the UNCOMPRESSED artifacts
```

`SHA256SUMS` covers what lands on the device, not what sits in the zip, because
that is what the installer reads back and compares.

## Prerequisites

* Docker, or any Linux host where you can be root and use a loop device.
* A boot image built by [a50-halium](https://github.com/sadatdaniel/a50-halium)
  — `build/build-kernel.sh --profile full --firmware DIR`, then
  `build/make-boot-image.sh --port ubports`. Or take one straight from that
  repository's `a50-ubports-halium-*` release, which is also the donor the
  packer wants. **The kernel that ships must be one that has been booted on
  the device.**
* About 10 GB of scratch space. The rootfs image is 6 GB and is compressed to
  roughly 1.3 GB.

## The three steps

```sh
# 1. the device tarball: partitions/boot.img + the port's userspace
sudo ./scripts/release/build-device-tarball.sh --boot /path/to/boot.img --out out

# 2. the rootfs image: UT rootfs + Halium GSI + the device tarball, in one ext4
sudo ./scripts/release/build-rootfs-image.sh --device-tarball out/device_a50.tar.xz --out out

# 3. the flashable zip
./scripts/release/make-installer-zip.sh --out out --version "$(date -u +%F)" \
    --manifest /path/to/a50-halium/out/build-manifest.txt

# then the debug build: steps 2 and 3 again, with --devel / --variant devel
sudo ./scripts/release/build-rootfs-image.sh --device-tarball out/device_a50.tar.xz --out out --devel
./scripts/release/make-installer-zip.sh --out out --version "$(date -u +%F)" \
    --variant devel --manifest /path/to/a50-halium/out/build-manifest.txt
```

Step 2 overwrites `out/rootfs.img`, so build and zip one variant fully before
starting the other. Each image is 6 GB and each zip is about 1.3 GB, so budget
roughly 16 GB of scratch for both.

In a container, all three at once:

```sh
docker run --rm --privileged \
    -v "$PWD:/repo" -v a50-build:/w -v /path/to/artifacts:/s \
    ubuntu:22.04 bash -c '
        apt-get update -qq && apt-get install -y -qq --no-install-recommends \
            curl ca-certificates xz-utils e2fsprogs git zip unzip pigz
        cd /repo
        ./scripts/release/build-device-tarball.sh --boot /s/boot.img --out /w/out
        ./scripts/release/build-rootfs-image.sh --device-tarball /w/out/device_a50.tar.xz --out /w/out
        ./scripts/release/make-installer-zip.sh --out /w/out --version "$(date -u +%F)"
    '
```

`build-device-tarball.sh` takes `overlay/system` from **`git archive HEAD`**,
not from the working tree, so a release always corresponds to a commit. Pass
`--dirty` while iterating. (There is a second reason: a working tree checked
out on Windows has symlinks whose absolute targets git-for-windows has
rewritten — `/run/...` becomes `/c/run/...` — which would ship a broken
`/etc/resolv.conf`.)

## Where this deviates from upstream, and why

Upstream's `prepare-fake-ota.sh` and `system-image-from-ota.sh` are the
reference. `build-rootfs-image.sh` is those two collapsed into one, with two
forced changes:

1. **The rootfs comes from the system-image pool, not from Jenkins.**
   `prepare-fake-ota.sh` only knows the release names `focal` and `24.04-1.x`.
   This port is on `26.04-1.x`, so the script resolves the newest published
   `rootfs-*.tar.xz` from the live channel index. That is the same tarball the
   OTA server hands a real device, which is better provenance than "last
   successful CI build", not worse.

2. **The Halium GSI is selected by `deviceinfo_halium_version`, not by
   `deviceinfo_bootimg_os_version`.** Upstream switches on the latter. On this
   device that field is `12.0` — the value the boot-verified image actually
   carries — while the Halium base is 11, so upstream's switch would reject the
   build outright. The halium version is the semantically correct read of the
   same intent.

Both deviations are in the script's header comment as well, so nobody has to
find this file to understand them.

A third difference is not a deviation but a limitation: **the kernel is not
built by the adaptation tools.** `./build.sh` (upstream's path) does build one,
and it has never been boot-tested on this device — see `docs/kernel.md`. Until
it is, the release ships a50-halium's kernel and the CI `build` job is a
compile check, not a source of releases.

## What is verified, and what is not

Verified in the build, every time:

| check | where |
| --- | --- |
| the boot image fits the 57,671,680-byte partition | `build-device-tarball.sh` refuses otherwise |
| every port file is present in the finished image, with its mode | mount the image and look; see the check list below |
| the Halium GSI is present as `android-rootfs.img` | same |
| `/etc/resolv.conf` points at NetworkManager, not at a build-host DNS | same |
| the installer detects the right partitions, verifies both artifacts, and reads the boot partition back | run the zip against loop devices under `busybox sh` |

For a debug build, also check the five things `add-devel-access.sh` changes -
the drop-in, the enabled units, `ADBD_SECURE`, and that the hash in
`/etc/shadow` really is the documented password:

```python
import crypt
line = [l for l in open("/mnt/img/etc/shadow") if l.startswith("root:")][0]
h = line.split(":")[1]
assert crypt.crypt("1234", h) == h
```

That check earned its place: the first version of the script verified its own
work with `grep -q "^root:\$6\$"`, which is not the pattern it looks like - the
shell strips the backslashes and grep reads the trailing `$` as an anchor. It
failed on a `/etc/shadow` that had been written correctly.

The installer test below is worth doing before every release, because it is the
only thing that exercises the installer with the same toolbox TWRP has:

```sh
# fake partitions, busybox applets first on PATH, then run the zip's own script
truncate -s 57671680 boot.part && BOOTLOOP=$(losetup --show -f boot.part)
truncate -s 8G data.part && mkfs.ext4 -qF data.part && DATALOOP=$(losetup --show -f data.part)
mkdir -p /data /dev/block/by-name && mount $DATALOOP /data
ln -sf $BOOTLOOP /dev/block/by-name/boot
ln -sf $DATALOOP /dev/block/by-name/userdata
busybox --install -s /bb && PATH=/bb:$PATH
ZIP=out/ubuntu-touch-a50-*.zip /bb/sh -c '
    ui_print() { echo "  | $1"; }; abort() { echo "  !! $1"; exit 1; }
    TMP=/tmp/a50-install; mkdir -p $TMP
    unzip -o "$ZIP" install/a50-install.sh -d "$TMP" >/dev/null
    . "$TMP/install/a50-install.sh"'
```

**Not verified, and the release notes must say so:** that this exact zip has
been flashed in real TWRP on a phone that was on stock Android beforehand. The
kernel it carries is boot-proven, and every file in the rootfs has been
checked, but "installs from a clean phone and boots" is an end-to-end claim
that only an end-to-end test can make. Do not write it until someone has done
it.

## Publishing

```sh
gh release create <tag> -R sadatdaniel/a50-ubuntu-touch \
    -t "<title>" -F notes.md \
    out/ubuntu-touch-a50-*.zip out/boot.img out/SHA256SUMS out/manifest.txt
```

Ship `boot.img` alongside the zips: an existing install can be updated by
writing just that, from a running system, with no recovery round trip.

Both zips go in the same release, and the notes have to say which is which.
A tester who flashes the debug build without knowing what it is has put a phone
with a known root password on their network.
