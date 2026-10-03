# 035 — Self-contained image layout and read-only container startup

Status: userspace regression checks passed, staged on the phone; full fresh
boot pending the USB kernel fix in experiment 034. Ubuntu Touch stays 26.04.

## Image filename

The exact aa12 Halium ramdisk's identify_file_layout() selects separate images
on userdata when it sees rootfs.img. In that layout it tries to load Android
from /userdata/android-rootfs.img, although this clean image embeds Android at
/var/lib/lxc/android/android-rootfs.img inside Ubuntu. The separate Android
image does not exist after Format Data, so /android is incomplete and Android
partition setup cannot finish. The recorded journal shows failed directory
creation and dependent container jobs failing.

Use the ramdisk's existing self-contained ubuntu.img layout. The installer now
writes /data/ubuntu.img and rejects a conflicting /data/rootfs.img before any
boot partition write. On the test phone the already-verified root image was
renamed after the offline filesystem updates; no vendor or recovery write was
performed. This is still a userdata image boot test, not OTA partition migration.

## Native LXC hook

The previous runtime mount.sh overlay came from /run, which the Halium ramdisk
mounts noexec. Replace that generated executable with a generated configuration:
copy the current packaged LXC config and append another lxc.hook.mount line,
invoking the packaged A50 adaptation using /bin/sh. Bind only the configuration
onto /var/lib/lxc/android/config. The upstream executable mount hook stays
unchanged and runs first; the A50 hook runs second in the same LXC mount namespace.

Native LXC documentation:
https://linuxcontainers.org/lxc/manpages/man5/lxc.container.conf.5.html

An isolated native liblxc start test used a read-only configuration directory,
noexec /run, two runs of preparation, and a minimal BusyBox container. It verified
exact upstream/A50 hook order, one appended A50 hook, unchanged upstream mount.sh,
and restoration of the original config after unmounting. The tiny container
initially needed its /dev directory and null device added to the test fixture;
the corrected complete run passed. This validates LXC wiring, not Android HALs.

## Upstream cgroup typo

Both the installed 26.04 package script and current upstream source have a
nonbreaking space between || and true in the first schedtune probe. If mkdir
fails, Bash tries to run a command named NBSP+true and exits 127 under -e.
That exact failure is in the failed-boot journal. fix-partition-probe.py changes
only this known token, accepts the already-fixed version, and refuses an
unrecognized script. It runs in the normal rootfs build; package versions stay
unchanged. A regression extracted the actual probe block, forced mkdir failure,
and confirmed clean fallback and unmount. Applying the correction twice passed.

Checked upstream source:
https://gitlab.com/ubports/development/core/hybris-support/lxc-android-config/-/blob/main/usr/libexec/lxc-android-config/mount-android-partitions

## Current phone state

TWRP remains installed. Patched /data/ubuntu.img remains root:root/0600, size
5,452,595,200. Offline filesystem hash after these three file changes:
885f7d752e28c9818ec7744449d80af548cc920f9dbd8c42a3d043d870746b85.
This is a development probe modified in recovery; rebuild the distribution
installer from current source before sharing. The original test ZIP remains
available privately but has the earlier layout and startup defects.

Kernel 034, first onboarding, second boot, AppArmor, native suspend startup,
USB reconnect/mode testing and final conventional OTA migration remain pending.
