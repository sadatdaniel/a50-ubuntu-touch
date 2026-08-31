# Plan

Ordered so that each step either produces evidence or is cheap to undo, and so
that **no step changes more than one variable that a boot test has to
attribute**.

Steps 1–3 need no device at all.

## 1. Settle the kernel question — no device

The blocking risk. [`kernel.md`](kernel.md) has the full statement; the work is:

1. Build with a50-halium and keep the `.config` of the boot-verified kernel.
2. `make savedefconfig` → `halium_a50_defconfig`, committed on the kernel
   branch.
3. Build that defconfig with a bare `make`, as `build-kernel.sh` does.
4. **Diff the two `.config`s.** Equal, or the difference is the answer.

Deliverable: `docs/experiments/002-bare-make-config.md`, and either a defconfig
that stands on its own or a precise statement of what `build.sh` adds that
Kconfig cannot carry.

## 2. Create the kernel branch — no device

`ubuntu-touch-26.04` on `sadatdaniel/android_kernel_samsung_exynos9610_mint`,
off the commit pinned in a50-halium's `kernel/source.lock`
(`bec0c2aff1ee8a02ac9f582d60fe611f1d2bc939`), with:

* a50-halium's four patches, as commits
* `arch/arm64/configs/halium_a50_defconfig` from step 1
* `arch/arm64/configs/halium.config` — the guide's minimal fragment, after
  checking line by line which options patch 0002 already sets
* `CONFIG_CMDLINE` carrying `console=tty0`, as its own commit, because it is a
  separate boot test

This clears the last `[?]` in `deviceinfo`'s kernel block.

## 3. First build — no device

```bash
./build.sh -b workdir
```

Success here is only that the tooling runs end to end and emits a `boot.img`.
Before flashing anything, check the output against what is known:

* its header against `halium-boot-canonical.img`, the way experiment 001 does
* its size against the 57,671,680-byte boot partition — `dd` truncates past it
  silently and the device simply will not boot

## 4. First boot attempt — device, and a way back

Flash from TWRP with a known-good image already downloaded. Expect no display.
Success is a shell, not a UI: `telnet 192.168.2.15` if the initramfs falls
over, `ssh phablet@10.15.19.82` if it does not.

Whatever happens, this answers the `id`-digest question from experiment 001 as
a side effect.

If it hangs before either: the four initramfs fixes in
`ramdisk-overlay/README.md`, one at a time, `/dev/kmsg` first — that one has
already cost this project a session on a different distro and its cause is a
property of the device.

## 5. Bring up Lomiri

Only after a shell. The guide's order is Lomiri, display, then AppArmor. Expect
`/dev/ion` permissions to bite immediately — that is what stopped the
compositor under Droidian, and the fix is a udev rule.

When something in the Android layer misbehaves, before anything else:

```sh
lxc-attach -n android -- /system/bin/logcat -d -b all
```

## 6. AppArmor

New work, its own boot test. Backported 4.14 series plus
`CONFIG_DEFAULT_SECURITY="apparmor"`. Keyboard vibration working is the
guide's own smoke test.

## 7. The rest of the hardware

In whatever order it breaks. Wi-Fi (`wlan0`, not `p2p0`), audio (the 32-bit HAL
bridge), the display cutout, the CPU governor. Each has a written diagnosis in
a50-droidian; none has a written Ubuntu Touch fix yet.

## Not on this list yet

Bluetooth, UBports recovery, and the UBports installer. See
[`status.md`](status.md).
