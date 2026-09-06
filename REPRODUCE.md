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

## Fastest path: the installer

Since 2026-09-06 there is a recovery-flashable zip that does the whole thing —
boot partition and rootfs, from a phone on stock Android. That is the
[README](README.md), not this file, and it needs nothing below.

**It has not been flashed on a phone yet.** Everything in this document has,
which is why it is still here.

## Fast path: a new kernel on an existing install

```sh
# on the device, over SSH
dd if=boot-a50-<release>.img of=/dev/sda14 bs=4M; sync
# ALWAYS read back and verify before rebooting
dd if=/dev/sda14 bs=1M count=53 2>/dev/null | head -c <size> | sha256sum
```

`/dev/sda14` is the boot partition and is writable from running Ubuntu Touch —
no TWRP round trip. Keep a known-good image on `/userdata` first.

Then apply the userspace fixes (step 4) **if the install predates
2026-09-06**. Newer images ship them: the overlay is installed into the rootfs
and applies itself at boot. The kernel alone is not enough — audio, telephony
and the speaker routing are userspace configuration.

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
docker run --rm -v a50-ksrc:/src/kernel/src -v "$PWD:/src" -v /path/to/a50-fw:/fw \
    a50-halium-build ./build/build-kernel.sh --profile full --firmware /fw --out /src/out

# pack it, reusing a known-good header + the Halium ramdisk from the donor
./build/make-boot-image.sh --port ubports --image out/Image --donor boot.img
```

`--profile full` is what this port ships: the four base patches plus five more,
`CONFIG_EXTRA_FIRMWARE`, `CONFIG_RFKILL` and the `anbox-*` binder devices. The
default, `--profile base`, builds only the base kernel — which is what Droidian
runs, and which has no Bluetooth and no built-in audio firmware.
(`build-a50-release-kernel.sh` still exists as a wrapper for `--profile full`;
older manifests name it.)

`make-boot-image.sh` takes the donor's header and ramdisk and replaces only the
kernel, and **refuses a donor belonging to the other port** — the two ramdisks
are not interchangeable and the wrong pairing reaches the bootloader and then
stops silently. Take the donor from a50-halium's `a50-ubports-halium-*`
release.

Underneath, `pack-boot-image.py` patches only `kernel_size` / `ramdisk_size` —
S-Boot ignores the header `id` digest (experiment 001). Boot partition limit is
**57,671,680 bytes**; the script refuses to write a larger image rather than let
`dd` truncate it silently.

### 4. Apply the userspace fixes

On the device, from this repo:

```sh
sudo ./scripts/apply-device-workarounds.sh
```

and install the `overlay/system/` tree (it mirrors `/`). This is **not optional** -
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
| `usr/lib/udev/rules.d/99-a50-gnss.rules` | `/dev/gnss_ipc` comes up `0600 root:root`; the vendor `init.gps.rc` wants `0660 system system` and `gpsd` runs as user `gps` |
| `etc/systemd/system/lomiri-location-service.service.d/50-a50-trust-store.conf` | AppArmor profile resolution cannot work with no AppArmor, so every location session is refused |
| `usr/local/bin/a50-gnss-unblock.sh` + service | **`gpsd` waits forever on `service.bootanim.exit`**, which a Halium container never sets - the single reason GPS produced nothing |

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

# GPS: the unblock ran, gpsd is alive, and its socket is bound
systemctl is-active a50-gnss-unblock.service                  # active
GP=$(pgrep -x gpsd)     # NOT pgrep -f: that matches your own ssh command line
ls /proc/$GP/task | wc -l                                     # 12, not 1
ls -l /proc/$GP/fd | grep gnss_ipc                            # open
grep -c GNSSND /proc/net/unix                                 # 2

# GPS: real satellites (hold a location session open while this runs)
lxc-attach -n android -- /system/bin/logcat -d | grep -E "num_svs|gnssLocationCb"
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
