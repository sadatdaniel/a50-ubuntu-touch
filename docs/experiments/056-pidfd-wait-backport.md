# Existing pidfd wait backport: reproducible release candidate

10 October 2026. The phone remains on aa17. A bounded real child-process probe
confirms working pidfd creation/polling but EINVAL from waitid(P_PIDFD), including
nonblocking wait and exit-status retrieval. NetworkManager's native dispatcher
logs the same GLib error and unknown child status. This is a process-monitoring
compatibility defect, not proof it caused the suspected Waydroid background
crash. No network configuration, authentication package or phone kernel changed.

Upstream Linux [3695eae](https://github.com/torvalds/linux/commit/3695eae5fee0605f316fbaad0b9e3de791d7dfaf)
and its [v5.10 implementation](https://github.com/torvalds/linux/blob/v5.10/kernel/exit.c)
provide the conventional completion of the vendor tree's existing helpers.
The earlier reference patch in 006 is now replaced with valid patch hunks and
accurate provenance; its old spinner/LightDM claim is not evidence for this test.

The permanent build home, exact source/config/image hashes, cache guards and
probe are in [a50-halium/docs/pidfd-wait.md](https://github.com/sadatdaniel/a50-halium/blob/main/docs/pidfd-wait.md).
The clean build adds --pidfd-wait explicitly and records it in the manifest.
Cached aa18 compile/link succeeds without downloads, and the existing boot
packer verifies the unchanged aa17 header/ramdisk and partition fit.
Candidate boot SHA256:
81f172febf16ebc8d132565f5bda3de8c6200df177647d8034d8a34971ec9776.
It is unflashed; fresh full reproduction and positive phone tests remain.

Before adoption, require a guarded boot test with aa17 rollback and owner
available, positive syscall results, normal health/security, dispatcher status,
USB/suspend regression and Waydroid background testing. Preserve vendor/TWRP.
The sleep observer pins aa17 and needs an explicit aa18 guard before that test.
No rootfs downgrade, GLib workaround, authentication bypass or route change.

The current sample has no native kernel OOM entries, an empty Android crash
buffer and no Android ANR since session boot; available memory is about 1.6 GiB.
Waydroid's original process identities remain and Android is booted. This
connected sample is not an unplugged background-sleep or long-use stability pass.
The owner cannot repeat the physical test now; observer units/holds are removed,
normal suspend startup is active, root RO, AppArmor Y, audit clean, failed units
zero. Short/long background tests, complete camera GSI, clean image and OTA remain.
