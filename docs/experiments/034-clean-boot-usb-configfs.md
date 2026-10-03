# 034 — Clean first boot: USB configfs ownership

Status: aa13 built and flashed with verified readback; clean setup reached after experiment 036. Ubuntu Touch
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

## aa13 build and installation, 2026-10-03

Kernel port source: c74b0ff. The corrected incremental build exited zero at
10:30:17 UTC; the existing .config hash stayed unchanged. PLATFORM_VERSION must
be 12.0.0, as set by Documentation/device-db/a50.sh, giving ANDROID_VERSION=120000
and ANDROID_MAJOR_VERSION=s. The first probe omitted that environment variable;
its output was discarded without flashing. The corrected compiler macros match
the retained aa11/aa12 builds. This vendor build setting does not change the
Android 11 vendor base or Halium version.

Image: 45,053,968 bytes; SHA256
9ecb60339027e0024cfcded50eddd351c90a0d5fe17b4d06eb6fe70f93dd2840.
boot-aa13.img: 55,851,008 bytes; SHA256
8ae7ab85c08c13b0a7f454882dda3c52162a004a718de2be657d3cd75218fca6.
The existing pack-boot-image.py retained the aa12 header and ramdisk, verified
the unpacked kernel/ramdisk and command line, and checked the partition limit.
No recovery image or system partition migration was performed.

The guarded scripts/experiments/flash-aa13-twrp.sh requires the exact aa12
preimage, exact new image, boot partition mapping/size and ubuntu.img layout.
It writes only boot and checks its readback plus the preserved vendor and
recovery hashes. The first invocation stopped before writing because TWRP's
shell aliases the name hash; renaming the helper file_sha256 resolved that
shell collision. The corrected invocation passed all checks. The read-only
root image inspection mount was removed, and the phone rebooted for clean
onboarding. User-visible setup and runtime results are still pending.

Rollback: from TWRP flash the retained aa12 boot donor using the same partition
and size checks. Its USB configfs defect remains, so it is a diagnostic fallback,
not a working clean-install release. Vendor and recovery were not modified.
The earlier userdata was intentionally erased; no old-userdata rollback exists.

## Hardware result after the first aa13 boots

Fresh persistent logs no longer show the earlier configfs NULL dereference.
Android starts and the compositor renders. Onboarding was then blocked by
host ION permissions; experiment 036 fixes that and the user confirms the
setup wizard and touch. Runtime USB mode/reconnect testing remains pending.

The isolated regression did not run: creating its second unbound gadget fails
with ENOMEM before any link test. Samsung's android_device_create() always
creates the singleton android0 device; gadgets_make() converts its creation
error to ENOMEM. This is a test-environment restriction, not a passing result.
Do not remove the active gadget just to run this check. Exercise the normal
USB mode path and verify repeated actual reconnects instead.
