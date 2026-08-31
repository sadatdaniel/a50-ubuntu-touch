# a50-ubuntu-touch

**Ubuntu Touch 26.04 for the Samsung Galaxy A50** (SM-A505F, Exynos 9610,
codename `a50`, Android 11 vendor base `RP1A.200720.012`).

> **Status: nothing has booted Ubuntu Touch on this device yet.**
> This repository currently holds a `deviceinfo` whose values were verified
> against images that *have* booted it, the reading behind those choices, and
> the risks that stand in the way. See [`docs/status.md`](docs/status.md) for
> exactly what is proven and what is not.

## What this is

An Ubuntu Touch port, built the way UBports builds ports: a `deviceinfo` file,
an `overlay/`, a `ramdisk-overlay/`, and a four-line `build.sh` that clones
[`halium-generic-adaptation-build-tools`](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools)
and gets out of the way.

```bash
./build.sh -b workdir                                        # kernel + boot.img + device tarball
./build/prepare-fake-ota.sh out/device_a50.tar.xz ota        # + rootfs and Halium GSI
./build/system-image-from-ota.sh ota/ubuntu_command images    # -> images/{boot,rootfs,system}.img
```

There is deliberately no bespoke build system here. The sibling Droidian port
hand-wrote a recovery installer before discovering Droidian's real convention
and had to throw it away; [`docs/conventions.md`](docs/conventions.md) is the
record of reading UBports' and Halium's guides *first* this time.

* **Method:** standalone kernel · **Halium:** 11 (Android 11 base) ·
  **Release:** `26.04-1.x`

## What it is built on

| Repo | What it gives this port |
|---|---|
| [a50-halium](https://github.com/sadatdaniel/a50-halium) | The device base. A reproducible, CI-gated, boot-verified kernel (`Image` = `074aad86…`), the patch series, and the device facts. **Read `docs/starting-a-new-port.md` and `device/samsung-a50/device-facts.md` there before this file.** |
| [a50-droidian](https://github.com/sadatdaniel/a50-droidian) | A *working* Linux port of this device — display, touch, Wi-Fi and audio. Read it for **how each piece of hardware was diagnosed**. The diagnoses transfer; the Debian packaging does not. |

The single most useful thing inherited from those two is not code. It is that
the hard parts of this device are already understood: `/dev/ion` permissions,
the 32-bit-only audio HAL, `p2p0` versus `wlan0`, `CONFIG_VT` without fbcon,
and a bootloader that ignores the boot image command line.

## How this repository works

Same as its siblings: **verify → document → commit.** Small commits, one
variable per test, and failures written down as carefully as successes.

Two conventions specific to this repo:

* **Every value in `deviceinfo` is marked `[V]`, `[C]` or `[?]`** — verified
  against a real artifact, required by upstream convention, or an untested
  guess. A `[?]` is a bug until it is resolved. Nothing is left unmarked.
* **Experiments get written up**, in `docs/experiments/`, with the question
  first and the result second, whether or not they worked. The script that
  produced each result is committed next to it, in the form that produced it.

## The short version of what is known

* **The upstream boot image tooling works on this device.** Verified: UBports'
  `mkbootimg` reproduces a known-good A50 boot image byte for byte, save for a
  digest field, once the addresses are expressed in the form it accepts.
  ([experiment 001](docs/experiments/001-bootimg-header.md))
* **The kernel is the open problem.** UBports' tooling builds kernels with a
  bare `make <defconfig>`; on this device that produces kernels that compile
  cleanly and never boot. Why, and the experiment that settles it, are in
  [`docs/kernel.md`](docs/kernel.md).
* **AppArmor is new work.** Droidian never needed it; Ubuntu Touch will not run
  apps without it.

## Licence

GPL-2.0, matching the kernel source and the sibling repositories. No
proprietary vendor blobs are committed here.
