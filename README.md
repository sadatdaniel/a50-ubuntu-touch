# Ubuntu Touch for the Samsung Galaxy A50

**SM-A505F · codename `a50` · Exynos 9610 · Ubuntu Touch 26.04 · Halium 11**

A community port. Not endorsed by, affiliated with, or supported by the UBports
Foundation or by Samsung. Built the way UBports community ports are built - a
`deviceinfo`, an `overlay/`, and
[`halium-generic-adaptation-build-tools`](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools)
- and packaged as a single recovery-flashable zip, because this device has no
fastboot.

> **Read [What works](#what-works) before installing.** The camera does not work
> in Ubuntu Touch and the fingerprint reader does not enrol. Everything else
> that makes a phone a phone does.

---

## Specifications

| | |
| ---: | :--- |
| **Model** | Samsung Galaxy A50, SM-A505F (`a50dd`, dual SIM) |
| **SoC** | Samsung Exynos 9610 (`universal9610`), 10 nm |
| **CPU** | Octa-core, 4x Cortex-A73 @ 2.3 GHz + 4x Cortex-A53 @ 1.7 GHz |
| **GPU** | Mali-G72 MP3 |
| **RAM** | 4 GB (`MemTotal: 3651020 kB`) |
| **Storage** | 128 GB UFS (`sda`, 127,943,049,216 bytes) |
| **Display** | 6.4" Super AMOLED, 1080 x 2340, `ro.sf.lcd_density=420` |
| **Battery** | 4000 mAh, non-removable |
| **Kernel** | Linux 4.14.194 |
| **Shipped Android** | 9 (Pie); this port is built against the **Android 11** vendor image |

---

## Firmware

Ubuntu Touch runs against **Samsung's own stock vendor partition** - the
Android 11 `/vendor` provides the audio, camera, GNSS, RIL and sensor HALs that
libhybris loads. The installer deliberately does not touch it. So the phone
must be on stock Android 11 **before** you install, and the port has only been
tested against one build:

| | |
| ---: | :--- |
| Vendor fingerprint | `samsung/a50dd/a50:11/RP1A.200720.012/A505FDDS9CWA2:user/release-keys` |
| Bootloader | `A505FDDS9CVJ1` |

Get there by flashing the stock A505F Android 11 firmware with Odin (Frija,
SamFirm or samfw.com will fetch it) before you start. **Older Android 9 or 10
vendor images are untested and will probably not work** - the HAL interfaces
differ.

Only the `SM-A505F` variant has been tested. Other A50 variants (`A505FN`,
`A505G`, `A505U`, `A505W`) share the SoC and are likely close, but nobody has
tried, and the US carrier variants may not permit an unlocked bootloader at all.

---

## Before you install

You will lose everything on the phone. Back it up first.

1. **Unlock the bootloader.**
   Settings, About phone, Software information, tap *Build number* seven times;
   then back to Developer options and enable **OEM unlocking**.
   Power off, hold **Volume Up + Volume Down** while plugging in USB to reach
   Download mode, and hold **Volume Up** to confirm the unlock. The phone
   factory-resets itself. Boot Android once more and check that Developer
   options shows **OEM unlocking greyed out and on**; if it does not, the
   unlock did not take and nothing below will work.

2. **Install TWRP.**
   Use the official `a50` build from
   [twrp.me/samsung/samsunggalaxya50.html](https://twrp.me/samsung/samsunggalaxya50.html)
   and flash `twrp-*-a50.img` as `AP` in Odin, with *Auto Reboot* **off**.
   Then boot straight into recovery - **Volume Up + Power** - the first time.
   Letting stock Android boot once restores the stock recovery, and you have to
   do it again.

3. **Format data.**
   In TWRP: **Wipe, Format Data, type `yes`.**
   This is not the same as "wipe data", and it is not optional. Samsung's
   `/data` is file-based-encrypted; until it is formatted TWRP cannot write to
   it, and the installer will refuse to run.

---

## Install

Download the zip from
[Releases](https://github.com/sadatdaniel/a50-ubuntu-touch/releases), copy it to
the phone (SD card, internal storage, or `adb push` from TWRP), then:

**TWRP, Install, select `ubuntu-touch-a50-*.zip`, swipe.**

It takes about ten minutes: 6 GB of rootfs are written to `/data`, then read
back and hashed. Then **Reboot, System**.

The installer writes exactly two things, and verifies both by reading them back:

| what | where |
| --- | --- |
| `boot.img` - kernel + Halium initramfs | the `boot` partition (`sda14`, 57,671,680 bytes) |
| `rootfs.img` - Ubuntu Touch 26.04 + Halium 11 GSI + this port | `/data/rootfs.img`, loop-mounted as `/` |

It does **not** touch `vendor`, `system`, `efs`, `modem`, `recovery` or the
bootloader. TWRP stays installed and remains the way back.

First boot takes two to five minutes. If it does not reach the setup wizard,
plug in USB and `telnet 192.168.2.15` - the Halium initramfs runs a debug shell
there when the rootfs will not mount.

### Two builds: pick one

| zip | what it is |
| --- | --- |
| `ubuntu-touch-a50-26.04-1.x-<date>.zip` | the normal one. SSH off, ADB locked, exactly the published Ubuntu Touch rootfs plus this port |
| `ubuntu-touch-a50-26.04-1.x-devel-<date>.zip` | **the debug one.** Same port, but you can get a shell into it before it has finished booting |

**Use the debug build if you are testing the port**, which right now is
everybody — see the warning at the top of the
[release](https://github.com/sadatdaniel/a50-ubuntu-touch/releases). It is the
difference between a bug report that says "it did not boot" and one that has a
journal in it.

The debug build differs in exactly five things, all of them in
[`scripts/release/add-devel-access.sh`](scripts/release/add-devel-access.sh):

* `sshd` is enabled at boot, with password authentication and root login
  allowed (a drop-in over the shipped `PasswordAuthentication no`)
* **root's password is `1234`**
* `usb-tethering.service` is enabled, so USB networking comes up on its own
* `ADBD_SECURE=0` — ADB works without host-key verification
* `/etc/motd` and `/etc/a50-image-variant` say all of this on the device itself

> **It is not a daily driver.** Anyone who can reach the phone over USB can be
> root on it. Do not put a SIM you care about in it, and do not leave it on a
> network you do not control. `passwd root` and
> `rm /etc/ssh/sshd_config.d/99-a50-devel.conf` turn most of it off.

### Getting a shell on the debug build

Plug in USB. The phone brings up an RNDIS interface and answers on
**10.15.19.82** — that is `usb-tethering`'s own default, not a local choice —
so from the PC:

```sh
ssh root@10.15.19.82         # password: 1234
adb shell                    # or this; no key to authorise
```

On Windows, if the interface comes up without an address, give the PC the other
end from an elevated shell:

```
netsh interface ip set address "Ethernet 2" static 10.15.19.100 255.255.255.0
```

(substitute the adapter's real name from `netsh interface show interface`; it
has to be re-added when the phone re-enumerates).

What to collect for a bug report:

```sh
journalctl -b --no-pager                 # everything, this boot
journalctl -b -p warning --no-pager      # just the complaints
systemctl --failed
dmesg | tail -100
lxc-attach -n android -- /system/bin/logcat -d -b all    # Android HAL errors
                                                         # appear NOWHERE else
systemctl status a50-container-prepare.service   # did the port's own setup run?
cat /etc/a50-image-variant
```

`lxc-attach … logcat` is the one people miss. HAL failures do not reach the
journal or `dmesg` at all, and processes outside the container that load
Android libraries through libhybris log there too.

**If it never gets that far** — no `10.15.19.82`, no ADB — the Halium
initramfs runs a telnet debug shell on **192.168.2.15** over USB when the
rootfs will not mount. `telnet 192.168.2.15`, then look at `/proc/last_kmsg`
and whether `/tmpmnt/rootfs.img` is there.

### Going back to Android

TWRP, Wipe, Format Data, then flash stock firmware with Odin as usual. The port
never modifies anything Odin does not overwrite.

---

## What works

Everything below was checked on the device, not inferred. The detail behind
each line is in [`docs/status.md`](docs/status.md) and the numbered experiments
in [`docs/experiments/`](docs/experiments).

- [x] Boots to the Lomiri UI, and survives reboots
- [x] Display, touch, backlight, rotation
- [x] Wi-Fi, including the indicator and hotspot
- [x] **Mobile data** - 2G/3G/4G, registers on LTE, both SIM slots defined
- [x] **Phone calls**
- [x] SMS
- [x] Signal strength indicator (needed an RSRP-appropriate `signalStrengthRange`)
- [x] **Audio** - speaker, ringtone, media, in-call
- [x] **Bluetooth**, including **A2DP** audio to earbuds
- [x] **GPS** - real satellites, a position once a second, from a cold boot
- [x] Location sessions for apps (Pure Maps, uNav)
- [x] **Waydroid** - Android 13 apps, with its own binder domain compiled in
- [x] Sensors: accelerometer, proximity, light
- [x] USB: ADB, MTP, charging
- [x] SSH (enable it in Settings, About, Developer mode)
- [x] OpenStore, after the 26.04 libxml2 SONAME co-install
- [x] Morph browser, including Google Maps

### Not working

- [ ] **Camera in Ubuntu Touch.** The hardware, the kernel driver, Samsung's
      HAL and libhybris all work - 16 preview and 33 picture sizes are read
      correctly from Ubuntu Touch. The fault is upstream: `qtubuntu-camera`
      0.5.1 implements only the legacy `QCameraViewfinderSettingsControl`,
      while Qt 5.15 asks for `ViewfinderSettingsControl2`, so Qt gets an empty
      resolution list, computes `QSize(-1,-1)` and segfaults.
      **Waydroid's camera does work**, because it uses Android's Camera2 and
      never touches Qt. [experiment 014](docs/experiments/014-camera.md)
- [ ] **Fingerprint enrolment.** The panel's high-brightness mask layer is
      solved by a kernel patch and the TEE comes up, but Samsung's trustlet
      never brings the ET713 sensor out of reset, so the HAL never issues
      `INT_TRIGGER_INIT` and no DRDY interrupt is ever registered. This unit
      has no fingerprint calibration data under `/mnt/vendor/efs`, which may be
      the cause. [experiment 012](docs/experiments/012-fingerprint.md)
- [ ] **AppArmor.** Not built - a kernel making it the default LSM did not
      boot. App confinement is therefore absent, and two services
      (`lomiri-location-service`, `biometryd`) run with their AppArmor caller
      checks bypassed. **Treat this port as not security-hardened.**
- [ ] **OTA updates.** There is no system-image channel for this device, so
      Settings, Updates will find nothing. Reflash to update.
- [ ] Untested: Bluetooth HFP (calls over Bluetooth), wired headphones,
      earpiece routing, VoLTE, NFC.

### Waydroid

Waydroid is already in the Ubuntu Touch 26.04 rootfs, so there is nothing to
install. Initialise it once, on Wi-Fi - it downloads about 2 GB:

```sh
sudo waydroid init
```

It picks the right images by itself: LineageOS 20 (Android 13) `VANILLA`, with
the **`HALIUM_11`** vendor image that matches this port's Android 11 vendor
base. Those images land under `/var/lib/waydroid`, which Ubuntu Touch mounts
from userdata, so they do not consume the 6 GB rootfs.

Everything else Waydroid needs on this device is already shipped: the `anbox-*`
binder devices are compiled into the kernel (this 4.14 tree has no binderfs),
a systemd *user* unit starts the session with the right bus, and Waydroid's
crash-looping camera provider is disabled.

Only the `Waydroid` launcher icon is shown, deliberately. In single-window mode
Waydroid exposes a single Android surface, so opening a second app steals the
surface from the first. Start Android apps from inside Android.

---

## Build it yourself

Everything needed is in git, plus one thing that cannot be: Samsung's
proprietary firmware blobs, which are extracted from the device itself.

```sh
git clone https://github.com/sadatdaniel/a50-ubuntu-touch
git clone https://github.com/sadatdaniel/a50-halium
```

### 1. The kernel

The shipped kernel is built by **a50-halium**, not by the adaptation tools, and
that is deliberate - see [`docs/kernel.md`](docs/kernel.md). It is reproducible:
the same pinned source, toolchain commit and `SOURCE_DATE_EPOCH` produce a
byte-identical `Image`.

```sh
cd a50-halium
docker build -t a50-halium-build build/
# once, on the phone, for the eight proprietary blobs:
#   ./build/extract-vendor-firmware.sh /tmp/a50-fw
docker run --rm -v a50-ksrc:/src/kernel/src -v "$PWD:/src" -v /path/to/a50-fw:/fw \
    a50-halium-build ./build/build-a50-release-kernel.sh --firmware /fw --out /src/out

# known-good-boot.img is any boot image that has booted this device - take
# `boot.img` from this repository's releases. Only its header and ramdisk are
# reused; the kernel is replaced.
./build/pack-boot-image.py known-good-boot.img out/Image - boot.img
```

Checked, not assumed: repacking the published `boot.img` with the published
`Image` and `-` for the ramdisk reproduces `90c281f8…` byte for byte. So a
third party needs only this repository, a50-halium, the public kernel fork,
and one release asset — plus the eight firmware blobs, which come off their
own phone.

The kernel tree cannot be checked out on Windows (`aux.c` is a reserved name)
and an NTFS checkout mangles its symlinks - build with the source on a Docker
volume.

### 2. The flashable zip

```sh
cd a50-ubuntu-touch
sudo ./scripts/release/build-device-tarball.sh --boot ../a50-halium/out/boot.img
sudo ./scripts/release/build-rootfs-image.sh  --device-tarball out/device_a50.tar.xz
     ./scripts/release/make-installer-zip.sh  --version "$(date -u +%F)"

# ...or the debug build: same thing, plus sshd, a root password, USB
# networking and unlocked ADB
sudo ./scripts/release/build-rootfs-image.sh  --device-tarball out/device_a50.tar.xz --devel
     ./scripts/release/make-installer-zip.sh  --version "$(date -u +%F)" --variant devel
```

Needs root and a loop device, so run it in a container if the host cannot
oblige. The Ubuntu Touch rootfs and the Halium 11 GSI are downloaded from
UBports; nothing proprietary is redistributed.
[`docs/RELEASING.md`](docs/RELEASING.md) has the long version, including the
two places where this port has to deviate from upstream's scripts, and why.

### 3. The upstream path, for comparison

`./build.sh` runs UBports' own tooling end to end - it builds the kernel too.
**That kernel has never been boot-tested on this device**, which is exactly why
releases do not use it. Closing that gap is the port's largest open task.

---

## How this repository is organised

| | |
| --- | --- |
| [`deviceinfo`](deviceinfo) | the port's parameters. Every value is marked `[V]` verified, `[C]` convention or `[?]` untested guess, with the evidence in the comment |
| [`overlay/system/`](overlay/system) | the port's userspace, mirroring `/`. Installed into the rootfs by the device tarball |
| [`installer/`](installer) | the recovery-flashable installer |
| [`scripts/release/`](scripts/release) | what builds a release |
| [`docs/status.md`](docs/status.md) | the honest inventory: what is proven, how it was checked, and what is not |
| [`docs/experiments/`](docs/experiments) | one file per investigation - question first, result second, failures included |
| [`REPRODUCE.md`](REPRODUCE.md) | getting from stock to this port's state without this repository's author |

Sibling repositories:

| | |
| --- | --- |
| [a50-halium](https://github.com/sadatdaniel/a50-halium) | the kernel: pinned source, the patch series, the reproducible build |
| [a50-droidian](https://github.com/sadatdaniel/a50-droidian) | a Droidian port of the same device. The **diagnoses** transfer; the Debian packaging does not |

The working rules, which are why the docs read the way they do: search for the
known fix before improvising; read the source that is installed, not upstream
master; "returned 0" is not "worked"; an absent log line is not evidence; one
variable per test; write up failures as carefully as successes.

---

## Licence

GPL-2.0, matching the kernel source and the sibling repositories. No
proprietary vendor blobs are committed or redistributed here.
