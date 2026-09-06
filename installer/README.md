# The recovery-flashable installer

UBports' GSI ports ship `boot.img` + `ubuntu.img` and tell you to run
`fastboot flash`. The Galaxy A50 has **no fastboot mode**: its bootloader is
Samsung's S-Boot, which speaks Odin's protocol and only accepts signed Samsung
tarballs. A custom recovery is the only way to write arbitrary images, and TWRP
is well tested on this device — so this port's equivalent of the fastboot
sequence is a flashable zip.

It writes what the fastboot sequence would write, and nothing else:

| | |
| --- | --- |
| `boot.img` | the `boot` partition, found by name, checked to be exactly 57,671,680 bytes |
| `rootfs.img` | `/data/rootfs.img`, which the Halium initramfs loop-mounts as `/` |

`vendor`, `system`, `efs`, `modem`, `recovery` and the bootloader are not
touched. Ubuntu Touch runs against Samsung's own stock Android 11 `/vendor`.

## Layout

| | |
| --- | --- |
| `META-INF/com/google/android/update-binary` | what TWRP executes. Unpacks one file and hands over |
| `META-INF/com/google/android/updater-script` | a stub, present only because some recoveries look for it |
| `install/a50-install.sh` | the install itself |

`a50-install.sh` is separate so it can be read, reviewed and run outside a
recovery:

```sh
A50_DRYRUN=1 A50_ZIP=/path/to/ubuntu-touch-a50-*.zip sh install/a50-install.sh
```

`docs/RELEASING.md` has the full harness that runs it against loop devices
under `busybox sh`, which is what the recovery actually provides.

## What it refuses to do

Each of these has cost someone a rebuild or a bricked boot somewhere, so they
are checks and not warnings:

* **A boot partition that is not 57,671,680 bytes** — that is not an SM-A505F,
  or the partition table has been changed.
* **A `/data` that will not mount** — on a phone still carrying stock Android
  it is file-based-encrypted and TWRP cannot write to it. Format Data first.
* **A `/data` that still holds an Android install** (`/data/system/packages.xml`)
  — installing over it leaves Android's encryption policy in place and Ubuntu
  Touch will not boot.
* **Too little free space** for the expanded rootfs plus 256 MB.
* **A boot partition that does not read back byte-for-byte** — `dd` returns 0
  on a short write to a block device, so the read-back is the only thing that
  proves the write. It aborts telling you not to reboot.
* **A rootfs whose hash does not match** after writing.

## Updating an existing install

You do not need this zip, or a recovery, to take a new kernel. From a running
Ubuntu Touch:

```sh
sudo dd if=boot-a50-<version>.img of=/dev/disk/by-partlabel/boot bs=4M
sync
# read it back BEFORE rebooting
sudo dd if=/dev/disk/by-partlabel/boot bs=512 count=$(( (SIZE + 511) / 512 )) \
    | head -c SIZE | sha256sum
```

Keep the image you are replacing on `/userdata` first. Getting back into TWRP
from a running Linux is unreliable on this device — `Volume Up + Power` from
powered off is the dependable route.
