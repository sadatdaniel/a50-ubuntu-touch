# The kernel: one hard conflict, and how to settle it

The A50 already has a kernel that is bit-for-bit reproducible, CI-gated and
boot-verified — [a50-halium](https://github.com/sadatdaniel/a50-halium) builds
it, and `sha256:074aad86…` is the `Image` that boots this device.

Ubuntu Touch's build tools cannot currently produce that kernel, and pretending
otherwise would waste a session. This file says exactly why, and what the
experiment is.

## Risk 1 — a bare `make` does not boot this device

`halium-generic-adaptation-build-tools/build-kernel.sh` builds a kernel the
ordinary way:

```sh
make O="$OUT" $MAKEOPTS $deviceinfo_kernel_defconfig
make O="$OUT" $MAKEOPTS -j$(nproc --all)
```

a50-halium's `device-facts.md` calls this the single most expensive lesson in
the port's history:

> Early attempts invoked `make` directly with a defconfig. Those kernels
> **compiled cleanly and never booted** — verified against the known-good
> ramdisk as a positive control, so the ramdisk was not the variable.

The mechanism, read out of the kernel tree's own `build.sh`:

| What `build.sh` sets | Value | Why it matters |
|---|---|---|
| `KCONFIG_BUILTINCONFIG` | `arch/arm64/configs/exynos9610-a50_default_defconfig` | A **second** defconfig, merged by Kconfig through the environment. Miss it and `.config` is quietly incomplete rather than obviously wrong. |
| `ANDROID_MAJOR_VERSION` | `r` | |
| `PLATFORM_VERSION` | `11.0.0` | Also written into the generated defconfig as `CONFIG_MINT_PLATFORM_VERSION`. |
| `LD_LIBRARY_PATH` | the bundled Proton Clang's own libs | |

and the defconfig it actually builds is generated, not checked in:
`build.sh` writes `tmp_exynos9610-a50_${VARIANT}_defconfig` from
`exynos9610-a50_core_defconfig` plus variant options. The variant matters:
`-v recovery` is what produces the kernel this port boots.

`build-kernel.sh` sets none of that.

### The experiment that settles it

One variable, no device needed for the first half:

1. Build with a50-halium (`build.sh -v recovery`) and keep the resulting
   `.config` — this is the configuration of a kernel known to boot.
2. `make savedefconfig` that `.config` into
   `arch/arm64/configs/halium_a50_defconfig`, committed on the port's kernel
   branch. A resolved defconfig has the `KCONFIG_BUILTINCONFIG` merge already
   baked into it, so it should not need the environment variable.
3. Build that defconfig with a bare `make`, the way `build-kernel.sh` does.
4. **Diff the two `.config` files.** If they are equal, the config half of the
   problem is solved on paper.
5. Only then flash and boot-test. If it boots, the tools can build this kernel
   and the port is conventional. If it does not, the remaining difference is
   `ANDROID_MAJOR_VERSION` / `PLATFORM_VERSION` reaching the source itself
   (they are used outside Kconfig), and that is the next single variable.

**Do not skip step 4 to get to step 5 faster.** One boot test per variable is
this project's own rule, broken once already at a cost of an hour.

### If it cannot be made to work

The fallback is to keep a50-halium as the kernel producer and feed its `Image`
into the tools' `KERNEL_OBJ` directory before `make-bootimage.sh` runs. That
works — `make-bootimage.sh` only reads
`$KERNEL_OBJ/arch/$ARCH/boot/$deviceinfo_kernel_image_name` — but it is a
deviation from the convention and would not survive upstream CI, so it is the
answer only if the experiment above fails.

## Risk 2 — `console=tty0` cannot be delivered the documented way

The UBports guide is unambiguous:

> `console=tty0` is a must for cmdline and should not be removed no matter what.

and it is set through `deviceinfo_kernel_cmdline`, which lands in the boot
image header.

**This device's bootloader ignores the boot image header command line.** S-Boot
merges its own from the device tree's `bootargs`. That is a verified A50 fact,
found the expensive way — an entire session's change was a silent no-op — and
the only way to check is a live `cat /proc/cmdline`.

So on this device `console=tty0` has to be compiled into `CONFIG_CMDLINE`, as a
kernel patch, and confirmed on the running device rather than assumed from the
deviceinfo.

Open sub-question, cheap to answer and worth answering early: does the UT rootfs
actually need `console=tty0`, or does it need `/dev/tty0` to exist? This kernel
already sets `CONFIG_VT=y` for exactly that reason — Phosh would not start
without `/dev/tty0` — and `CONFIG_FRAMEBUFFER_CONSOLE` must stay off, because
fbcon crashes against the Samsung decon driver while bare VT does not.

## Risk 3 — a different compiler from every kernel that has booted

Every booting A50 kernel was built with Proton Clang 210521, pinned by commit
in a50-halium. The adaptation tools fetch Google's prebuilt Clang by
branch/revision instead, and offer no way to point at an arbitrary Clang.

This is not obviously fatal — but it is a second changed variable sitting
underneath risk 1, and if the bare-`make` kernel fails to boot it will be
tempting to blame the config when the compiler changed too. Build with
a50-halium's Proton Clang first, so that the config is the only difference;
change the compiler afterwards, on its own.

## Kernel options Ubuntu Touch wants that Droidian did not

* The guide's minimal `halium.config` — `CONFIG_DEVTMPFS`, `CONFIG_FHANDLE`,
  `CONFIG_SYSVIPC`, `CONFIG_IPC_NS`, `CONFIG_NET_NS`, `CONFIG_PID_NS`,
  `CONFIG_USER_NS`, `CONFIG_UTS_NS`, `CONFIG_VT`. Every one of these is already
  satisfied by a50-halium's `kernel/patches/0002`. Worth a line-by-line check,
  not a re-derivation.
  * `CONFIG_SYSVIPC=y` is confirmed fine on this device (it ships enabled and
    `/proc/sysvipc` exists). `CONFIG_POSIX_MQUEUE` — the other way to satisfy
    `CONFIG_IPC_NS` — is reported to bootloop it. Leave it off.
* **AppArmor** is new work: the backported 4.14 series plus
  `CONFIG_DEFAULT_SECURITY="apparmor"`. Add it as its own patch, boot-test it
  on its own.
* `CONFIG_BT` + `CONFIG_BT_HCIVHCI` are still the known open bug — needed for
  Bluetooth, and they bootloop this device. Parked in a50-halium's
  `kernel/patches-experimental/`. Do not pick this up before the port boots.

## And the thing that must not be re-litigated

Whatever happens above, `/proc/config.gz` and `lxc-checkconfig` **lie on this
device** — they read a stale frozen IKCONFIG blob. Check kernel features by
using them, or through `/proc`. The UBports guide's suggestion to recover a
defconfig from `/proc/config.gz` does not apply here.
