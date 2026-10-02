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

User follow-up: Waydroid also becomes unavailable from Recents during the event.
The event is not occurring now. The user will record it when it recurs and
requested deferring further Waydroid diagnosis. A crash remains possible; the
currently healthy launcher does not exclude an earlier crash.

At 18:47 CEST the user reported the icon currently absent. Before any refresh or
restart, the same Waydroid.desktop still had its 07:26 modification time,
NoDisplay=false and the wrapper Exec. Both fresh Gio discovery and
lomiri-app-launch-appids included Waydroid. The session and container services
had been running since 07:25 with NRestarts=0; the container was FROZEN and the
session RUNNING. There were no matching recent retained journal entries.
This narrows the current symptom toward the shell's displayed model; it does
not rule out an earlier application failure or establish the exact race.

Inspected installed Lomiri e12b69c and current upstream 9ee950b. AppDrawerModel
and XdgWatcher are unchanged between these revisions. The model drops events
while refreshing; changed-file events only update popularity, and file-removal
signals remove rows. These are investigation leads, not a verified fix.
No Waydroid, shell or phone restart was performed while capturing this state.

## Live follow-up at 23:26–23:31 CEST

The user confirmed pull-down refresh did not restore the icon. A fresh process
using the running shell's XDG paths still listed Waydroid, and lomiri-app-info
parsed its name/icon/orientation successfully. The existing desktop file was
unchanged since 07:26 before the next test.

Starting Waydroid via lomiri-app-launch succeeded; the user confirmed Android
opened while the drawer icon remained absent. The same container/session
services retained NRestarts=0, and the container changed from FROZEN to RUNNING.
This event does not establish a container crash.

At 23:29:53 the user desktop file was regenerated with Exec=waydroid show-full-ui
instead of the adaptation wrapper, still NoDisplay=false. This demonstrates a
late rewrite beyond the 150-second repair window. It does not explain the
original disappearance, which was captured with the wrapper still intact.

An isolated Qt5 harness reproduced four AppDrawerModel defects against upstream
9ee950b: duplicate add events, missing visibility reconciliation on change,
and an event lost while a refresh snapshot is in flight. No model patch was
deployed: the user's unsuccessful manual refresh means those test failures alone
are insufficient evidence for the current phone symptom.

Capture the next event before restarting with
`sudo sh scripts/experiments/check-waydroid-launcher.sh` on the phone. It only
reads metadata, discovery, parsing, service status and relevant journal entries.
Keep raw diagnostic output private; no repair or launch is performed by it.
The script passed against this live event. Investigation remains open.

The user subsequently confirmed the normal launch opened Android with its
icon still absent, and authorized a clean-install test with no need to retain
personal data. Helper 3.4.0 was not running. Its installed Appdrawer code only
selects lowercase waydroid.*.desktop entries for hide/show, not Waydroid.desktop;
there is no evidence it hid the main entry. No Helper uninstall was performed.
The next clean-image test is distinct from a working OTA migration.
