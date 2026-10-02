# Container preparation with a read-only root

October 2, 2026. The first read-only-root candidate (port edcca98, official
26.04 daily full image 376) passed its offline filesystem/security audit, but
source inspection found a fresh-boot blocker. a50-container-prepare.sh generated
vendor overrides under /var/lib/lxc/android and appended to its mount.sh. That
path is not covered by the installed writable-paths table. Existing development
files conceal this problem; a clean read-only image cannot create them.

## Fix

Generate the four derived files under /run/a50-android. The mixer generator
already accepts source/destination arguments, so use those without changing its
routing implementation. Keep packaged empty RC files in /var/lib/lxc/android.

Copy the currently installed upstream LXC mount.sh into the runtime directory,
append the existing A50 hook once, then bind-mount that runtime copy onto LXC's
normal hook path. The original package file remains unchanged. This uses the
existing LXC mount-hook ordering and mount namespace; it does not replace the
upstream script with a frozen local copy. An unexpected existing mount is
rejected, and a second invocation recognizes its own bind mount. The LXC unit
now Requires preparation, rather than merely Wants it, so a preparation failure
cannot start Android without these required device adaptations.

## Validation

Ran the candidate on the phone using unshare --mount --propagation private.
Bound /var/lib/lxc/android read-only, mounted private tmpfs at /run/a50-android,
and used the repository mixer generator. All four derived files were generated,
including valid mixer XML. Two consecutive preparation calls succeeded with
exactly one hook inclusion. After unmounting the runtime hook, the original
mount.sh hash matched. The parent's live mount namespace was unchanged; Android
was not restarted. The first attempt skipped the mixer because file transfer
had removed its executable mode; rerunning with the builder's 0755 mode passed.

The guarded reproduction is scripts/experiments/check-readonly-container.sh.
Stage the two candidate scripts at /userdata/a50-session29-aa12 and set the
expected-boot-id deliberately. This tests generation and hook installation,
not a clean container boot or the execution of every bind inside Android.
A guarded fresh boot remains required before calling this release-ready.

The edcca98 image is superseded for boot testing by this fix. Its audit passed
at 5,452,595,200 bytes with about 1.3 GiB free; rootfs SHA256 was
`a4707e89dcd2d299f5a2ae20ff97a4f35c1281a65e322cd6dc5e922d26168efc`.
It has not been flashed. The new build must include this container fix.

Rollback for a future installed deployment: stop the Android container before
unmounting the runtime hook and restoring the previous port files. Runtime
mounts disappear on reboot. Do not remove generated files while a container is
using them. The isolated validation made no such live deployment.

The isolated candidate was refreshed with the f0c4a7e device tarball and passed
another e2fsck plus script/configuration checks. No phone partition was flashed.
Final image SHA256: 8408498e80eeca0c8f3fca251dfb57a94dc23c8ce6b5ca325cbce0854874510f.
Device tarball SHA256: feaa03ff61c7bffadcbceb2604fd40524c7d09749b1551bf32df0eaf411c3dda.
Artifacts remain in Docker volume a50-release-readonly-376 under /w/out.
Official input: full image 376, rootfs-1797be4cea7f57bc920e6c874fdc501fc956e64698cfbda3853ce9b864f8ed3e.tar.xz,
SHA256 7273c2fb019f2b2a1d0eb41d141095d6a6b6cbf512e55031527e3dea1a5d3b8b,
683,412,668 bytes. The file digest was checked against the official HTTPS index.
Reproduce the image content with the existing release builders at f0c4a7e,
ROOTFS_URL pinned to that pool file, aa12 boot.img and size 5200M. As documented
for earlier candidates, filesystem timestamps/UUID prevent a byte-identical
rootfs guarantee. The refresh reused the unflashed image to conserve host disk.
