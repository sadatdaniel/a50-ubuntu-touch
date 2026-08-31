# What the ecosystem expects, and where this port follows it

This project's second rule is *read the ecosystem's conventions before
designing anything* — it exists because a hand-written recovery `update-binary`
had to be thrown away when Droidian's actual convention (Debian packages plus
`package-sideload`) turned up afterwards.

So this file is the result of reading the Halium and UBports porting guides
before writing anything here, and it exists so the next session does not have
to read them again to know what was decided.

Read in full on 2026-09-01:

* UBports porting guide, source form (`ubports/docs.ubports.com`, branch
  `master`, `porting/**`): `introduction/{Intro,Preparations,Setting_up}`,
  `build_and_boot/{index,H9_setup_sources,H9_build,standalone_kernel_build,Halium_install,Boot_debug}`,
  `configure_test_fix/{index,Apparmor,Display,Wifi,Sound,Bluetooth,Lomiri,Overlay,USBModed}`,
  `finalize/*`, `UpdatePortsFor2004`
* `gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools`
  at `d5838d5` — `build.sh`, `build-kernel.sh`, `setup_repositories.sh`,
  `make-bootimage.sh`, `prepare-fake-ota.sh`, `deviceinfo.sample`
* `docs.halium.org` porting guide (upstream Halium's own guide is older than
  UBports' — it still describes LineageOS 12.1/14.1 — so where the two differ,
  UBports' is the one that applies)

## The decisions this fixes

### The port is a `deviceinfo` repository, not a build system

An Ubuntu Touch port of a device like this one is **a repository containing a
`deviceinfo` file, an optional `overlay/`, an optional `ramdisk-overlay/`, and
a four-line `build.sh` that clones the shared tooling**. Everything else —
fetching the kernel, the toolchain, the Halium GSI, the rootfs, packing the
boot image, building the device tarball — belongs to
`halium-generic-adaptation-build-tools` and is not ours to write.

`build.sh` here is verbatim from `UpdatePortsFor2004.rst`. Do not replace it
with our own logic. That instruction is the entire lesson of the Droidian
`update-binary`.

### Standalone kernel method, Halium 11, Ubuntu Touch 26.04

| Choice | Why |
|---|---|
| **Standalone kernel method** | One of three methods in the guide. It needs only a kernel plus the prebuilt Halium GSI and UBports rootfs. We already have a boot-verified kernel, so this is the method that reuses the most existing work. |
| **Halium 11** | The vendor base is Android 11. The kernel tree's `build.sh` exports `ANDROID_MAJOR_VERSION="r"` and `PLATFORM_VERSION="11.0.0"`, and the Droidian port runs Android 11 blobs. UBports' table maps Android 11 → Halium 11 → LineageOS 18.1. Verified, not assumed. |
| **26.04-1.x** | A supported value of `deviceinfo_ubuntu_touch_release`. Its rootfs artifact URL resolves (checked 2026-09-01). It is an early series — 24.04-2.x is the tools' default and the fallback if 26.04 churn gets in the way. |

The three artifact URLs the tools will fetch were checked, not assumed — all
HTTP 200 on 2026-09-01:

* rootfs — `ci.ubports.com/job/ubuntu-touch-rootfs/job/main/…/ubuntu-touch-android9plus-rootfs-arm64.tar.gz`
* Halium 11 GSI — `…/generic_arm64/job/halium-11.0/…/halium_halium_arm64.tar.xz`
* halium-boot ramdisk — `github.com/halium/initramfs-tools-halium/releases/download/dynparts/initrd.img-touch-arm64`

### Where each kind of device fix goes

This is the part worth having written down, because this device needs fixes in
three different layers and the ecosystem has a designated home for each.

| Fix belongs to | Upstream mechanism | Here |
|---|---|---|
| The initramfs (before the real root is mounted) | a cpio appended to the halium-boot ramdisk | `ramdisk-overlay/` |
| The running rootfs (udev rules, units, config) | overlaystore — `/system/opt/halium-overlay` | `overlay/` |
| Something that must run *after* the Android container is up | `/usr/libexec/lxc-android-config/device-hacks`, run by `/bin/sh` on every boot | `overlay/usr/libexec/lxc-android-config/device-hacks` |
| The kernel | patches on the port's kernel branch | a50-halium's `kernel/patches/`, carried onto the branch |

That third row matters more than it looks. a50-halium's warning list says
`runonce` targets on this device fire *before* the Android container exists, so
every one of them silently no-opped and was then marked permanently done — that
is how the device ran for days with no display cutout. `device-hacks` is the
upstream answer to exactly that ordering problem, and it runs every boot rather
than once.

### AppArmor is not optional

Without it "most apps will crash when launched". For a 4.14 kernel the guide
points at the backported series on `kdrag0n/proton_zf6`, branch `halium`,
`security/apparmor`, plus `CONFIG_DEFAULT_SECURITY="apparmor"`. This is new
work: Droidian never needed it, so nothing about it is inherited and all of it
has to be boot-tested here.

### What we do NOT adopt

* `deviceinfo_bootimg_tailtype="SEAndroid"` — the standard Samsung advice, and
  wrong for this device: no known-good A50 boot image carries the footer.
* `deviceinfo_bootimg_partition_size` — setting it triggers `avbtool
  add_hash_footer`, and no image that has booted this device has an AVB footer.
  The 57,671,680-byte limit is real and is enforced separately.
* `deviceinfo_kernel_cmdline` as a way to set anything — S-Boot ignores the
  header command line entirely. See [`kernel.md`](kernel.md).
