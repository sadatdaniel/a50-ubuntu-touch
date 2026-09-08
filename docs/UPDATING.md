# Updating

Three different questions get called "updating", and they have three different
answers. Only one of them is a switch you flip.

| | |
|---|---|
| **A new kernel** on an installed device | `dd` the boot image. No reflash, no data loss |
| **A new Ubuntu Touch rootfs** (26.04 daily → rc → stable) | rebuild the image, reflash, **wipes the device** |
| **OTA, from Settings → Updates** | does not exist for this device, and cannot until the port has a channel on a system-image server |

---

## There is no OTA, and here is the proof

Ubuntu Touch updates itself by asking `system-image.ubports.com` for
`<channel>/<device>/index.json`. This port has no device entry in any channel:

```console
$ curl -o /dev/null -w '%{http_code}\n' \
    https://system-image.ubports.com/26.04-1.x/arm64/android9plus/daily/a50/index.json
404
$ curl -o /dev/null -w '%{http_code}\n' \
    https://system-image.ubports.com/24.04-2.x/arm64/android9plus/stable/a50/index.json
404
```

The image this port builds still ships an `/etc/system-image/channel.ini`
naming that channel, because the tooling writes one and a missing one confuses
`system-image-cli` differently. So Settings → Updates will spin and then find
nothing. That is expected, it is not a bug in the port, and no amount of
retrying changes it.

Getting real OTA needs one of:

* **the port adopted by UBports**, which puts an `a50` entry on their
  system-image server and hands the build to their CI; or
* **our own system-image server** — the format is public and small (an
  `index.json` per device, tarballs in a pool, a signing key), but it is a
  service to run, not a file to publish, and GitHub Releases cannot serve it
  because the client fetches by path.

Until then, updating the userspace means reflashing, which means wiping. Say so
in every release.

---

## A new kernel: no reflash needed

This is the easy one, and it is why `boot.img` is published on its own next to
every installer zip.

```sh
# from running Ubuntu Touch, over SSH
sudo dd if=boot-a50-<version>.img of=/dev/disk/by-partlabel/boot bs=4M
sync
# read it back BEFORE rebooting - dd does not fail on a short write to a
# block device, so this is the only thing that proves it
SIZE=$(stat -c%s boot-a50-<version>.img)
sudo dd if=/dev/disk/by-partlabel/boot bs=512 count=$(( (SIZE + 511) / 512 )) \
    | head -c "$SIZE" | sha256sum
```

Keep the image you are replacing on `/userdata` first. Getting back into TWRP
from a running Linux is unreliable on this device; **Volume Up + Power from
powered off** is the dependable route.

---

## A new rootfs: what actually has to change

26.04-1.x currently publishes **only `daily`**, and `channels.json` flags it
`hidden: true`. There is no `rc` and no `stable` for it yet — 24.04-2.x has all
three, so that is what the progression looks like when it happens.

### The one-string part

```sh
./scripts/release/build-rootfs-image.sh --channel stable --device-tarball out/device_a50.tar.xz
```

or set `deviceinfo_ubuntu_touch_channel="stable"` in `deviceinfo`. The script
resolves the newest published rootfs from that channel's own index, so nothing
is pinned to a filename that will rot.

**That part is genuinely just a switch.** The rest is not.

### The part that is not

This port reaches into the rootfs in eleven places. A rootfs that changes any of
them breaks the port *silently* — the image builds, it flashes, it boots, and
one subsystem is dead. Check each against a new rootfs before releasing it.

| what the port assumes | where | how it fails |
|---|---|---|
| `/etc/pulse/touch.pa` has a line starting `load-module module-droid-discover ` | `a50-device-setup.sh` | the `sed` matches nothing, PulseAudio segfaults in a restart loop, no audio |
| `/var/lib/lxc/android/mount.sh` exists and is appendable | `a50-container-prepare.sh` | none of the container overrides bind — no audio HAL, watchdogd hangs every misc device, no display |
| `lxc-android-config` still owns `/usr/libexec/lxc-android-config/device-hacks` | `overlay/system/...` | we overwrite a packaged file; if it moves, our per-boot hook never runs |
| `device-hacks.service` is enabled and ordered after the container | overlay | same |
| `/etc/ssh/sshd_config.d/50-lxc-android-config.conf` sets `PasswordAuthentication no` | `add-devel-access.sh` | our `99-` drop-in stops winning; the debug image has no SSH |
| `/etc/default/adbd` carries `ADBD_SECURE=` | `add-devel-access.sh` | the `sed` matches nothing, ADB stays locked |
| `root` is in `/etc/shadow`, `phablet` in `/var/lib/extrausers` | `add-devel-access.sh` | root password not set |
| `lomiri-location-service` honours `TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING` | `50-a50-trust-store.conf` | every location session refused again |
| `biometryd` honours `BIOMETRYD_DBUS_SKELETON_IS_RUNNING_UNDER_TESTING` | `50-a50-testing.conf` | System Settings crashes on the Fingerprint page again |
| the rootfs ships libxml2 with the **new** SONAME | `add-openstore-compat.sh` | if it ever ships 2.9 again, we co-install a duplicate; if the ICU dependency moves, OpenStore still will not start |
| the Halium GSI from Jenkins `lastSuccessfulBuild` | `build-rootfs-image.sh` | **unpinned** — a new GSI arrives whether or not you asked for one |

That last row is worth its own line: the GSI is fetched from
`.../halium-11.0/lastSuccessfulBuild/artifact/halium_halium_arm64.tar.xz`, so
two builds a week apart are not the same image. If a build regresses and the
kernel and rootfs are unchanged, suspect it first — and record the hash of the
GSI you shipped, which `SHA256SUMS` inside the bundle does not currently do.

### The procedure

1. Build with `--channel <new>`.
2. Mount the image and walk the table above. `docs/RELEASING.md` has the
   verification pass; extend it rather than eyeballing.
3. Flash the **debug** build first — it is the one you can get a shell on when
   something in the table has moved.
4. Only then cut the normal build.

### And it wipes the device

Because there is no OTA, "moving to stable" for an existing install means
Format Data and reflash. Back up `/home/phablet` first; nothing in this port
does that for you.

---

## Which rootfs this port is on, and why

`deviceinfo_ubuntu_touch_release="26.04-1.x"`, and the reasoning — including
that 24.04-2.x was tried and **bootloops at ~15 s on this device** — is in
[`device-provisioning.md`](device-provisioning.md) and in `deviceinfo`'s own
comment. Do not switch releases casually; switching *channels* within 26.04-1.x
is the cheap move, switching to 24.04 is not.
