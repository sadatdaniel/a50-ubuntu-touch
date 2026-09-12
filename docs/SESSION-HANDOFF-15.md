# Session handoff 15 - Waydroid stale display socket fixed

2026-09-12 08:00 CEST. Preserve prior handoffs. AppArmor aa6 build continues;
no kernel flashed since aa4. User reported a Waydroid launch failure during build.

## Evidence and recovery

At 07:45 Waydroid unfroze but its composer repeatedly reported `Couldn't open
Wayland display`; SurfaceFlinger was restarting. Host Wayland socket inode
274438 differed from the container bind-mounted inode 107848 (same device 53).
The old socket came from before the 02:32 Lomiri refresh for the notch. Session
notification code also referenced a vanished D-Bus name. No reinstall needed.

Stopped the user waydroid-session service and container through their supported
commands, then started the session and opened its UI. Host/container inodes both
274438; SurfaceFlinger running; IP 192.168.240.112. User confirmed Android opened.

## Prevent recurrence

Existing port unit only belonged to graphical-session.target, which stays active
across a Lomiri restart. Added lomiri-full-greeter.service to its PartOf and After
dependencies. Standard systemd PartOf propagates stop/restart; After also ensures
Waydroid stops before the compositor and starts after it. Existing Waydroid
SIGTERM handler already stops its container, so no extra stop script was added.
Read installed session_manager.py and official systemd/Waydroid documentation.

Installed unit backup: /userdata/a50-session13/waydroid-session.service.before.
Root returned RO. User-unit verification completed without reported errors.
Controlled test at 07:57:

- Waydroid stopped at 07:57:17-21, before Lomiri stopped.
- Lomiri restarted and was ready at 07:57:46; Waydroid then restarted automatically.
- Both socket inodes became 582068, graphics service running, IP restored.

This fixes the demonstrated compositor-restart failure, not all Waydroid bugs.
Images/config were not replaced. Installed package 1.6.3 (UBports 26.04 build),
VANILLA system/HALIUM_11 vendor from official Waydroid OTA URLs; binder devices
anbox-binder/anbox-vndbinder/anbox-hwbinder. Idle suspend_action=freeze is expected.

## AppArmor work still active

aa6 container a50-kbuild-aa6, source a50-ksrc-aa6, full/ubports at ac4c288.
AppArmor lsm.o and af_unix.o now compile, as does SELinux hooks.o. Resolved config
AppArmor default and HARDENED_USERCOPY=y. Full build and actual boot still pending.
Do not claim suspend/resume or camera fixed. aa4 SO_PEERSEC baseline is errno 92.
Next guard must support Kconfig AppArmor selection and unequal boot-image sizes;
templates prepared locally in a50-ut-out/session-14, not armed on the phone.
