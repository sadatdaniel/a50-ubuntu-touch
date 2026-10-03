# 036 — Clean boot ION permissions

Status: Samsung/upstream rule applied; user confirmed that the setup wizard
appears and touch works. Setup completion, second boot, clean-image AppArmor
and suspend validation remain pending. Ubuntu Touch stays 26.04.

## Recorded failure and diagnosis

aa13 removes the earlier USB configfs NULL dereference; Android now starts.
The root system compositor renders its spinner, but Lomiri and the lightdm
greeter exit with `buffer allocation failed`. Persistent logs show normal
power-off through systemd-logind after a power-key event, rather than a new
kernel panic. Battery reported 100% in recovery.

A temporary systemd diagnostic boot captured actual host device permissions
and Android logcat, then returned to TWRP automatically with the normal
`systemctl reboot --force --reboot-argument=recovery` mechanism. Host /dev/ion
was 0600 root:root; both phablet and lightdm failed O_RDWR opens with EACCES.
Mali and binder nodes were already accessible. The container has its own /dev,
so its vendor permissions do not automatically give host applications access.
No authentication change was needed for this collection.

## Existing implementation reused

The preserved Samsung vendor /vendor/etc/ueventd.rc explicitly sets
`/dev/ion 0666 system system`. Existing UBports 70-manta.rules uses the same
ION policy. Copy that native udev rule into the A50 overlay:

```
ACTION=="add", KERNEL=="ion", OWNER="system", GROUP="system", MODE="0666"
```

Source: overlay/system/usr/lib/udev/rules.d/99-a50-graphics.rules. It ships
through the existing device tarball/rootfs builder. No allocator replacement,
boot-time chmod loop, root desktop, or confinement bypass is introduced.

Upstream reference checked at a5cc1a6ee30ac86a5389b38edf15e2a327c29f7a:
https://gitlab.com/ubports/development/core/hybris-support/lxc-android-config/-/blob/main/usr/lib/lxc-android-config/70-manta.rules

The installed upstream Android platform reports this error when gralloc's
allocation fails, returns no buffer or gives a zero stride:
https://gitlab.com/ubports/development/core/hybris-support/mir-android-platform/-/blob/main/src/platforms/android/server/gralloc_module.cpp

## Validation and reproduction

Before the change: both unprivileged ION opens fail; repeated desktop/greeter
buffer allocation failures prevent setup. After installing only the ION rule
and rebooting the same image/kernel, the user confirmed setup and touch work.
Run `sudo sh scripts/experiments/check-graphics-access.sh` to check both actual
desktop users' ION opens. It closes the descriptor without reading or issuing
GPU ioctls. Runtime ownership and repeat-boot checks are still pending.

The previous installer ZIP predates this rule and experiments 034/035. Rebuild
from current source before sharing. The temporary diagnostic unit must be
removed from the test phone before final validation; it is not in the release
overlay. Its second capture leaves setup running and retains authentication.
Raw journals, logcat and device identifiers remain private.

Rollback: remove only 99-a50-graphics.rules and reboot; expect the original
clean desktop allocation failure. Vendor, recovery, credentials and userdata
are not changed by this rule.
