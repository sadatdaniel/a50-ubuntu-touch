# 041 â€” Authentication CPU loop and Terminal reopening

3 October 2026. These are development-image release blockers. The failed-authentication CPU loop remains unresolved. Terminal reopening now
has a verified stale-state cause and a narrowly scoped package candidate.

The user's newer installer output was real: sudo and dpkg logs show an
authenticated installation at 17:45 phone local time. It replayed the original
dependency-incomplete installer and left the three QtMir packages unpacked.
The corrected repair was completed offline in TWRP; experiment 040 records the
verified package operation and read-only normal boot.

## Runaway authentication process

An older sudo-rs process from a failed authentication at 17:02 remained alive
without a command child and used roughly one CPU core. It was distinct from
the newer installer, whose authentication session closed normally. SIGTERM did
not stop it. After confirming the PID, executable and absence of an installer
child, terminating that single process removed the CPU consumer. The immediate
aggregate idle observation changed from approximately 75% to 88%; this is not
a performance benchmark or proof that all perceived sluggishness was caused
by that process.

Installed packages are sudo-rs 0.2.13-0ubuntu1.2 and conventional sudo
1.9.17p2-1ubuntu3.1. Both are already in this 26.04 rootfs. The registered
alternative `/usr/bin/sudo.ws` can authenticate the repair using the existing
policy; no package downgrade, new sudoers rule, passwordless access or global
alternative switch was made.

The upstream [high-CPU report 841](https://github.com/trifectatechfoundation/sudo-rs/issues/841)
is an older closed terminal/PTY report. It is a related symptom, not evidence
that its patch fixes this phone's current authentication loop. The installed
tag's password/TTY code and current upstream reports were inspected.

`check-sudo-terminal-close.py` creates isolated synthetic terminals, reaches a
password prompt, closes it without sending any credential, and measures exit
and CPU time with a bounded cleanup. Both installed implementations exited
normally in this test (about 0.03 seconds of CPU each). Noninteractive sudo
without authentication also rejects promptly with exit 1. The observed loop
has therefore not yet been reproduced. Do not claim a kernel waitid, YESCRYPT,
or terminal fix is proven; do not change password hashing based only on the
PAM warning. Required validation includes failed authentication, cancellation,
timeout, swipe-only onboarding, changing credentials, and terminal closure.

## Terminal close/reopen failure

The user closed the buggy Terminal from Recents and could not reopen it. The
journal records Terminal exiting with SIGSEGV at 18:05. A subsequent process
was paused by application lifecycle management while the shell reported an
application requesting focus without an associated window. The user confirmed
that tapping the icon returned to the drawer.

There were no active sudo, apt or dpkg jobs when the stopped Terminal launch
service was cleared. The first retry coincided with a display-session restart
and failed to connect to the Mir socket. After the display recovered, a new
Terminal process connected and loaded its normal QML, but focus still lacked a
window. Resuming it once changed its process state from stopped to sleeping
without establishing a functional visible window.

The temporary wizard wrapper was removed and normal package installation was
completed offline. A fresh boot uses the package-owned QtMir library and normal
full-greeter command, with root mounted read-only. Terminal still returned to
the drawer. The shell also restarted with SIGSEGV during an app close/relaunch;
that crash is not represented as fixed by the database repair.

## Verified saved-hidden-state cause

Narrow QtMir logging showed Terminal create a normal 1080×2257 surface, then
receive `requestState(hidden)`, lose its window and be suspended. Its row in
Lomiri's window-state SQLite database contained state 13 (HiddenState), rather
than 1 (RestoredState). `Stage.qml` loads this state when the window becomes
ready. `WindowStateSaver.qml` saves the state when a delegate is destroyed and
only normalizes MinimizedState; the shared storage accepted HiddenState.

`scripts/experiments/repair-terminal-hidden-state.py` made a private SQLite
backup, stopped only Terminal's launch unit and changed only that app's verified
hidden row to RestoredState. The next normal launch produced the authentication
window, and the user confirmed Terminal opens. No credential was collected,
authentication disabled, application data erased or entire database reset.
Settings was reported to return to the drawer too, but its saved state was 1;
its failure is not attributed to the same stale hidden row.

## Shared correction candidate

Official upstream source and recent commits were checked first; no matching
fix was found in the inspected revision. The candidate patches exact installed
[Lomiri fcac00b](https://gitlab.com/ubports/development/core/lomiri/-/tree/fcac00b977a96f050ebcde4fdbd78e77c2e9b26a):
`AsyncQuery::saveState` ignores transient HiddenState, preserving the previous
usable state; `WindowStateStorage::getState` falls back for legacy hidden rows.
It applies to all callers and requires no recurring database-reset service.

`lomiri-hidden-window-state.patch` includes a real SQLite regression in the
existing storage tests. `build-lomiri-window-state-package.sh` builds current
26.04 ARM64 packages through the existing workflow's `lomiri` choice. Native
compilation and tests are pending at this checkpoint. Full shell integration,
repeated close/reopen, Settings, Recents and shell crash checks remain required
before calling this a permanent validated fix. The exact trigger that first
saved the hidden state is not yet established.

The diagnostic unit also survived in userdata-backed `/etc/systemd/system`,
despite removing the image copy offline. `cleanup-persisted-diagnostics.sh`
uses normal administrator authentication, validates its known ExecStart,
backs up only that unit and removes it. Authenticated execution is pending.
The recovery wrapper now handles both locations. No privilege workaround is
used to exploit the temporary unit's overly permissive development mode.

Keep raw runtime logs and database backups private. The failed-auth CPU loop,
shell SIGSEGV and first-boot/OTA regressions remain release blockers.
