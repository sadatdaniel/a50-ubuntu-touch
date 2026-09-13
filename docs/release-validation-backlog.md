# Release validation backlog

User reports recorded 2026-09-13. Suspend/resume remains the active priority.

| Area | Current status | Required evidence before a stable release |
| --- | --- | --- |
| Suspend/resume | Watchdog failure corrected in aa8 testing; USB resume candidate aa9 under test | Repeated staged and full sleep/wake, USB/Wi-Fi, display/touch, delayed stability, automatic sleep and battery measurements |
| Lock/password changes | User reports current passphrase unlocks and works with sudo but Settings rejects it when changing lock method | Reproduce with private logs; inspect Settings, AccountsService/PAM/polkit and writable credential paths without exposing password hashes; test PIN/passphrase/swipe choices and reboot persistence |
| First-run setup | Development installation is not representative of a clean user install | Fresh official rootfs plus committed port adaptations; no development-access build option; verify setup wizard, user-selected credentials, security defaults and second boot |
| Bluetooth keyboard | User reports unsolicited connect/disconnect; not independently reproduced | Capture connection/controller logs and test idle, typing, reconnect and sleep/wake; establish cause rather than assume it |
| VPN | Untested | Validate supported VPN connection, routing/DNS, reconnect and sleep/wake |
| Libertine | Untested | Container creation, package installation, application launch/input and reboot persistence |
| Factory reset | Untested | Test only with disposable data or verified complete backup; confirm recovery behavior and return to first-run setup |
| System updates | Not operational/validated; updater packages installed but configuration empty | Unified recovery, correct image layout, local OTA plus second update/data preservation, signed channel integration and installer validation |
| Waydroid | Unreliable; deferred by user | Repeated launches/stops, compositor restart, network/sound, sleep/wake and extended use; no absolute stability claim from a single launch |
| Camera video | Broken and deferred | Separate investigation later |

The release scripts include an explicit development-access option that sets up
debug credentials. Do not publish a copy of the current development filesystem
as a user-ready image. Build cleanly and validate onboarding. A fresh image is
not proof that the reported password-change bug is gone; it must be tested.

No passwords, authentication configuration, Bluetooth configuration or user data
were changed as part of recording this backlog.
