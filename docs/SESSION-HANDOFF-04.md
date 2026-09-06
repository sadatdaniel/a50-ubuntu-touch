# Session handoff 04 — Samsung A50 / Ubuntu Touch

**Written 2026-09-06.** Read this first, then [`status.md`](status.md), then the
experiment for whatever you are touching.

Earlier handoffs are kept so the progression is visible. Where they disagree,
**this file wins**: [01](SESSION-HANDOFF.md) → [02](SESSION-HANDOFF-02.md) →
[03](SESSION-HANDOFF-03.md) → 04.

---

## 0. RIGHT NOW

**There is an installer.** One recovery-flashable zip installs the port from
nothing:
[`installer-2026-09-06`](https://github.com/sadatdaniel/a50-ubuntu-touch/releases/tag/installer-2026-09-06).

**It has not been flashed on a phone.** That is the single open item and it is
the next thing to do. Everything under it is proven; the end-to-end claim is
not, and nothing in the repository claims it.

| | |
|---|---|
| Zip | `ubuntu-touch-a50-26.04-1.x-2026-09-06.zip`, 1.32 GB, sha `35e835e0…` |
| Boot image inside it | `90c281f8…` — **the kernel this device is running**, not a rebuild |
| Rootfs inside it | 6144M, Ubuntu 26.04.1 + Halium 11 GSI + the port, sha `091322c3…` |
| Dev device | unchanged. Nothing was flashed to it this session |

### How to test it (the next task)

The cheap, reversible version, on the development device. It does **not** need
TWRP and does not touch the boot partition — the zip's boot image is already
what is running:

```sh
# 1. put the new rootfs next to the old one (75 GB free on /userdata)
scp rootfs.img root@10.15.19.82:/userdata/rootfs-release.img

# 2. swap
mv /userdata/rootfs.img         /userdata/rootfs-dev.img
mv /userdata/rootfs-release.img /userdata/rootfs.img
reboot
```

The initramfs picks `/tmpmnt/rootfs.img` (`scripts/halium`,
`identify_file_layout`), so that is the whole switch. **If it does not boot**,
the Halium initramfs runs a telnet debug shell on **192.168.2.15** over USB —
`scripts/panic/telnet` in the ramdisk — from which the two names can be swapped
back. TWRP (Volume Up + Power from powered off) is the fallback to the
fallback.

Note the released rootfs has **no SSH enabled**: it is the published UBports
image, not a `devel-flashable` one. So even a successful boot needs the wizard
completed on the phone and developer mode turned on before you can log in. If
that matters, build a test image with upstream's devel overrides
(`prepare-fake-ota.sh` writes `/etc/init/ssh.override`) and label it a test
image in the notes.

The full version — TWRP, on a phone that was on stock Android, from Format Data
onwards — is what the release notes say nobody has done.

---

## 1. What changed this session

**The port's userspace was never being installed.** Three separate faults, any
one of which was enough on its own:

1. `overlay/` was laid out as `overlay/etc`, `overlay/usr`, `overlay/var`. The
   adaptation tools do `cp -av overlay/* "${TMP}/"` where `TMP` holds `system/`
   and `partitions/`, and then pack **only** those two — so every file was
   copied beside them and dropped. A tarball built the old way has 31 entries
   and all of them are kernel-module metadata. Now `overlay/system/`, which is
   what the reference port
   ([oneplus-nord-n100](https://gitlab.com/uports/h10/oneplus-nord-n100/oneplus-nord-n100))
   does.
2. `deviceinfo_use_overlaystore="true"` would have dropped it a second time.
   Read `/usr/libexec/lxc-android-config/mount-halium-overlay` on the device: it
   bind-mounts file by file onto `/` and **skips anything the rootfs does not
   already have**. Most of this overlay is new files. Removed, with the code
   quoted in `deviceinfo`.
3. Everything `scripts/apply-device-workarounds.sh` did by hand after a flash
   now ships as units. See §2.

**The image size was wrong too.** `deviceinfo_system_partition_size` was the
tools' 3584M default; the 26.04 rootfs alone leaves 103 MB free in that, and
the Halium GSI then fails to unpack. 6144M.

**OpenStore now works out of the box.** 26.04 renamed libxml2's SONAME, so the
preinstalled OpenStore and Morph could not start at all;
`scripts/release/add-openstore-compat.sh` co-installs the genuine 2.9 library
and the ICU 74 set it links, resolved from noble's own package index rather
than pinned.

**Corrections to earlier docs, both with the evidence in place:**

* `device-provisioning.md` said Waydroid's images live on the rootfs and needed
  a 16 GB grow. They do not — `/var/lib/waydroid` is a mount from `sda32` and
  holds its 3.9 GB there.
* `status.md` said the kernel branch `ubuntu-touch-26.04` did not exist. It does.

---

## 2. How the port installs itself now

Two hooks, and the split between them is not cosmetic.

**Before the container starts** — `a50-container-prepare.service`, ordered
`After=mount-android-partitions.service` and
`Before=lxc-android-config.service`, pulled in by a drop-in on the latter. It
generates the overrides that are *derived* from vendor and GSI files, and so
cannot be committed: the watchdogd-free `init.exynos9610.rc`, the
audio-HAL-restoring `init.disabled.rc`, and `mixer_paths.a50.xml`. Then it
appends **one line** to `/var/lib/lxc/android/mount.sh` sourcing
`var/lib/lxc/android/a50-mount-hooks.sh`, which is in git and holds the binds.

Why a mount hook at all: `/system` and `/vendor` are mounted separately inside
the container's mount namespace, so a bind made on the host is invisible in
there. Verified — `mountpoint /android/vendor/etc/init/init.exynos9610.usb.rc`
says "not a mountpoint" on the host while the override is live in the
container.

**After the container is up** — `usr/libexec/lxc-android-config/device-hacks`,
Ubuntu Touch's own per-boot hook, runs `a50-device-setup.sh`: unmask
`sensorfwd`, patch `touch.pa`, run `ldconfig`, fix `/dev/gnss_ipc` on a node
udev already created, enable the Waydroid session user unit.

`scripts/apply-device-workarounds.sh` is still there and still works. It is now
for a device that was flashed **before** this change; a fresh install needs
nothing.

---

## 3. Building a release

[`RELEASING.md`](RELEASING.md) is the real document. In short:

```sh
sudo ./scripts/release/build-device-tarball.sh --boot /path/to/boot.img --out out
sudo ./scripts/release/build-rootfs-image.sh --device-tarball out/device_a50.tar.xz --out out
     ./scripts/release/make-installer-zip.sh --out out --version "$(date -u +%F)"
```

Needs root and a loop device — run it in `--privileged` Docker. Two things to
know:

* `build-device-tarball.sh` takes `overlay/system` from **`git archive HEAD`**,
  not the working tree, so a release corresponds to a commit. `--dirty` while
  iterating. (Second reason: a Windows checkout has symlinks whose absolute
  targets git-for-windows rewrote — `/run/…` becomes `/c/run/…` — which would
  ship a broken `/etc/resolv.conf`.)
* Two forced deviations from upstream's scripts, both documented in the script
  headers and in RELEASING.md: the rootfs comes from the published system-image
  pool, because `prepare-fake-ota.sh` only knows `focal` and `24.04-1.x`; and
  the Halium GSI is selected on `deviceinfo_halium_version`, because upstream
  selects on `bootimg_os_version`, which here is `12.0` while the Halium base
  is 11.

**The kernel is still not built by the adaptation tools.** `./build.sh` builds
one and it has never been boot-tested — [`kernel.md`](kernel.md). That is why
releases use a50-halium's kernel and the GitLab CI is a compile check only.

---

## 4. Traps, on top of handoff 03 §4

Handoff 03's list still holds — `pkill -x` not `-f`, logcat is UTC, `strings`
cannot see module params, the kernel tree cannot live on NTFS, apt needs
`-o APT::Sandbox::User=root`, decon only re-evaluates the mask layer on a new
frame. New ones:

* **Do not mount the build image under `/tmp` in a container.** Upstream's
  trick is to mount the image at `$STAGE/system` and untar from `$STAGE`, so
  `system/…` members land in it with no copy at all. Copying instead needs a
  second full 3.6 GB and dies with "No space left on device" on the container's
  overlayfs.
* **`ldconfig -r <rootfs>` cannot work cross-architecture.** It chroots and
  execs the target's own binaries. Do it on the device instead; the loader
  finds `/usr/lib/<triplet>` without a cache entry anyway.
* **awk with an early `exit` under `curl |`** makes curl report "Failure
  writing output to destination" on every call. Cosmetic, but in a build log it
  reads as a download failure.
* **Disk.** This machine sat at 95% for the whole session. A container named
  `ut-build-env` holds 19.8 GB, about 15 GB of it three superseded scratch
  trees (`/root/ut-build`, `ut-build2`, `ut-build3`). Nothing was deleted.

---

## 5. Open, unchanged from handoff 03

Camera (an upstream `qtubuntu-camera` / Qt 5.15 interface mismatch, not this
device), fingerprint enrolment (Samsung's trustlet never brings the ET713 out
of reset), AppArmor (unbuilt; the one attempt did not boot). The root causes
are established — do not re-derive them. Untested: Bluetooth HFP,
headphone/earpiece audio.

---

## 6. Everything else

Handoff 02 §1–6 still apply verbatim: reaching the device, flashing, the basic
laws, live hazards, and runtime state that is not in git.
