# Reproducing this port from nothing but GitHub

Everything needed to get a Galaxy A50 (SM-A505F) from stock to this port's
current state — working display, Wi-Fi, **audio, Bluetooth, calls and mobile
data** — is in two repositories and one release. Nothing depends on any local
machine.

| what | where |
|---|---|
| kernel, patches, build recipe | [`a50-halium`](https://github.com/sadatdaniel/a50-halium) |
| device config, overlay, runtime fixes, docs | [`a50-ubuntu-touch`](https://github.com/sadatdaniel/a50-ubuntu-touch) (this repo) |
| prebuilt boot images | this repo's [releases](https://github.com/sadatdaniel/a50-ubuntu-touch/releases) |

The one thing **not** in git is Samsung's proprietary firmware. It is extracted
from the device itself — see step 2.

---

## Fast path: flash the published image

```sh
# on the device, over SSH
dd if=boot-a50-<release>.img of=/dev/sda14 bs=4M; sync
# ALWAYS read back and verify before rebooting
dd if=/dev/sda14 bs=1M count=53 2>/dev/null | head -c <size> | sha256sum
```

`/dev/sda14` is the boot partition and is writable from running Ubuntu Touch —
no TWRP round trip. Keep a known-good image on `/userdata` first.

Then apply the userspace fixes (step 4). The kernel alone is not enough:
audio, telephony and the speaker routing are userspace configuration.

---

## Full path: build everything yourself

### 1. Build container

```sh
git clone https://github.com/sadatdaniel/a50-halium
cd a50-halium
docker build -t a50-halium-build build/
```

The kernel tree has case-colliding filenames (`xt_CONNMARK.c` / `xt_connmark.c`)
that Docker Desktop's Windows bind mount silently loses. **Build inside the
container**, never on a Windows bind mount.

### 2. Extract the vendor firmware

Proprietary Samsung blobs, deliberately not committed. Run **on the device**
(stock Android or this port):

```sh
./build/extract-vendor-firmware.sh /tmp/a50-fw
```

Copy `/tmp/a50-fw` to the build host. It must contain 8 files — the script
verifies and fails loudly if any are missing.

They are built *into* the kernel because the ABOX audio DSP requests its
firmware at **t = 1.43 s**, and this device has no filesystem of any kind until
**t = 2.08 s**. See
[`docs/experiments/007`](docs/experiments/007-abox-firmware-too-early.md).

### 3. Build the kernel and pack a boot image

```sh
docker run --rm -v "$PWD:/src" -v /path/to/a50-fw:/fw a50-halium-build \
    ./build/build-a50-release-kernel.sh --firmware /fw --out /src/out

# pack it into a bootable image, reusing a known-good header + ramdisk
./build/pack-boot-image.py known-good-boot.img out/Image - new-boot.img
```

`build-a50-release-kernel.sh` is the single authoritative recipe for what the
port ships. `build-kernel.sh` alone builds only the *base* kernel.

`pack-boot-image.py` reuses the donor image's header and ramdisk and patches
only `kernel_size` / `ramdisk_size` — S-Boot ignores the header `id` digest
(experiment 001). Boot partition limit is **57,671,680 bytes**; the script
refuses to write a larger image rather than let `dd` truncate it silently.

### 4. Apply the userspace fixes

On the device, from this repo:

```sh
sudo ./scripts/apply-device-workarounds.sh
```

and install the `overlay/` tree (it mirrors `/`). This is **not optional** —
it carries:

| file | why |
|---|---|
| `usr/local/bin/a50-audio-hidl-compat.sh` + service | PulseAudio otherwise loads a 12 KB **stub** audio HAL and silently discards every write |
| `usr/local/bin/a50-gen-mixer-paths.py` + mount hook | the vendor routes the speaker from RDMA7, a channel this DSP NACKs |
| `usr/local/bin/a50-audio-speaker-route.sh` + service | pins the default sink off the unusable low-latency output |
| `etc/deviceinfo/devices/a50.yaml` | without it ofono falls back to the legacy RIL plugin and finds no modem |
| `etc/ofono/binder.conf` | slot paths, `radioInterface = 1.4`, and the signal-strength range |
| `usr/local/bin/a50-dmesg-snap.sh` + service | boot logs are otherwise evicted before you can read them |
| `usr/lib/udev/rules.d/99-a50-binder.rules` | the greeter cannot reach the graphics HAL without it |

Reboot. Verify with step 5.

---

## 5. Verify

```sh
# audio: DSP booted, HAL connected, speaker routed
cat /sys/devices/platform/14a50000.abox/calliope_version      # rSK1
for fd in /proc/$(pgrep -u 32011 -x pulseaudio)/fd/*; do readlink $fd; done | grep hwbinder
amixer -c 0 cget name='ABOX UAIF2 SPK'                        # values=1 while playing

# bluetooth
hciconfig -a                                                  # hci0 UP RUNNING

# telephony
dbus-send --system --print-reply --dest=org.ofono /ril_0 \
    org.ofono.NetworkRegistration.GetProperties               # registered, lte, Strength

# mobile data
nmcli -t -f DEVICE,STATE device | grep ril_0                  # connected
```

---

## What is deliberately not reproducible from git

* **Samsung's firmware blobs** — proprietary; extracted from the device
  (step 2).
* **The rootfs image** — fetched by the UBports tooling, not built here.
* **`/linkerconfig/ld.config.txt`** — regenerated by `linkerconfig` on every
  boot; `a50-audio-hidl-compat.service` re-patches it each time. This is the
  one genuine hack left in the port, and
  [`docs/experiments/007`](docs/experiments/007-abox-firmware-too-early.md) §26
  explains what should replace it.
