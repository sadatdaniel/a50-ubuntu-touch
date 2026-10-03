# 034 — Clean first boot: USB configfs ownership

Status: candidate kernel building; hardware validation pending. Ubuntu Touch
26.04 rootfs 376 remains installed. Vendor and TWRP were preserved.

## Recorded failure

The clean installation rebooted before onboarding. Persistent ramoops records
an unbind warning in config_usb_cfg_unlink, followed by a NULL dereference in
strcmp called by config_usb_cfg_link+0x308, at approximately 7.2 seconds.
Disassembly of the exact aa12 vmlinux maps that comparison to
cn->configuration in Samsung's is_symboliclink_change_mode(). Configfs creates
the label object before any string is written, so the pointer may be NULL.

The installed UBports configurator probes RNDIS before creating the language
directory. Samsung's other path queues that function on gi->linked_func,
whereas config_usb_cfg_unlink searches cfg->func_list. The vendor GSI path also
moves functions to the former list and then searches for ADB specifically.
A NULL guard alone would leave this incompatible ownership/mode logic intact.

## Conventional fix

Restore Linux's normal configfs function linking: validate the instance,
reject duplicate links, get the function, and put it on cfg->func_list. The
existing unlink routine then removes and releases that same function. Remove
the unused Samsung label/GSI helpers and their calls from the link routine.
Keep Samsung's USB uevents, setup callbacks, RNDIS MAC helper and controller
adaptations. No forced developer mode or credential changes are used.

Reference implementation:
https://android.googlesource.com/kernel/common/+/23818c192b1564bae833256324cbc7c451dc7087/drivers/usb/gadget/configfs.c
Lifecycle documentation: https://docs.kernel.org/usb/gadget_configfs.html
UBports configuration: https://docs.ubports.com/en/latest/porting/configure_test_fix/USBModed.html

An existing Eureka Exynos7885 implementation was inspected too. Its current
file retains label-based Samsung GSI assumptions, so it was not copied.
https://github.com/eurekadevelopment/Eureka-Kernel-Exynos7885-Q-R-S/blob/Eureka-Clang-HMP/drivers/usb/gadget/configfs.c

## Reproduction

Kernel repository: a50-halium. Patch:
kernel/patches-experimental/usb-configfs-standard-linking.patch.
Build option: --usb-configfs-fix. Start with a fresh source volume and use:

```sh
./build/build-kernel.sh --profile full --firmware /fw --apparmor ubports \
  --watchdog-freezer-fix --usb-otg-sleep-fix --usb-otg-core-reinit \
  --wifi-sleep-fix --usb-configfs-fix --out /src/out-aa13-usb-configfs
```

For the initial hardware probe the retained aa12 source/build volume is reused
incrementally to avoid another full source/toolchain copy on the low-space
Windows host. Its source commit, pre-patch configfs file and profile are checked;
the existing .config must retain its hash. This incremental output has not yet
been compared with an independent clean build.

The root-only check-usb-configfs-links.sh creates a separate, unbound gadget.
It checks repeated link/unlink and duplicate rejection with absent, unset,
empty, generic and Samsung configuration labels. It never binds a controller
or changes the active gadget. Run only on the patched Ubuntu Touch kernel;
running it on aa12 can reproduce the panic. Full USB mode/reconnect testing
and a clean second boot remain required beyond that isolated check.

Raw pstore and journal logs remain private in the development workspace.
