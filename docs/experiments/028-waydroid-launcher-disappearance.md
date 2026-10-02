# Waydroid launcher disappearance: October 2 investigation

The user clarified that Waydroid usually disappears from the application menu,
returns after reboot, and otherwise works normally. Do not treat this report as
proof of an Android application or container crash.

Installed package: 1.6.3-0ubports1~20260902074048.12~72f4eca+ubports26.04.1.
`dpkg -V waydroid` returned no discrepancies. The installed UBports
`tools/services/user_manager.py` regenerates `Waydroid.desktop` on userUnlocked.
It sets NoDisplay from persist.waydroid.multi_windows; that property currently
reads false. The installed system entry is hidden, while the generated user
entry overrides it. The user entry currently exists, is NoDisplay=false and
uses the A50 launch wrapper. Gio.AppInfo discovery reports it visible. It has
not changed since 07:26:13 CEST this boot. Per-app Android entries are hidden,
as intended for the single-window launcher configuration.

The current 150-second reconciliation script is installed. It cannot repair
rewrites occurring after its startup window, but such a rewrite has not been
observed during this investigation. Do not replace it with another speculative
polling workaround or claim the missing icon fixed. A drawer refresh check is
pending from the user. Capture desktop-file state and Gio discovery while the
icon is actually missing before selecting a correction.

Upstream references checked before changing code:

- https://docs.ubports.com/en/latest/userguide/dailyuse/waydroid.html documents
  pulling down to refresh the app drawer when Android entries do not appear.
- https://gitlab.com/ubports/development/core/lomiri/-/issues/39 describes stale
  drawer entries after desktop-file changes, especially Waydroid. Its duplicate
  entry symptom is related evidence, not proof of this missing-entry cause.
- https://github.com/waydroid/waydroid/issues/1407 reports a main launcher hidden
  by regeneration in 1.4.2. This phone currently has NoDisplay=false, so that
  report alone does not explain its present state.

No installed Waydroid code or configuration was changed in this audit. The
container's FROZEN state while idle is intentional and is not a crash diagnosis.
