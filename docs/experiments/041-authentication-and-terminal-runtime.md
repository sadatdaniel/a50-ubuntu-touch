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
compilation succeeded in native ARM run
[37140084464](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37140084464).
The added SQLite regression fails on the original source and passes with the
shared correction; the storage tests pass. Runtime packages are downloaded to
the host but are not installed on the phone. The dependency preflight below
rejected this first candidate; do not install it. The full upstream suite was not
run. Full shell integration,
repeated close/reopen, Settings, Recents and shell crash checks remain required
before calling this a permanent validated fix. The exact trigger that first
saved the hidden state is not yet established.

The diagnostic unit also survived in userdata-backed `/etc/systemd/system`,
despite removing the image copy offline. `cleanup-persisted-diagnostics.sh`
uses normal administrator authentication, validates its known ExecStart,
backs up only that unit and removes it. Authenticated execution completed.
The unit and enablement symlink are absent, systemd reports not-found/inactive,
and the saved unit backup is root-owned mode 0600. Authorized USB remains
available.
The recovery wrapper now handles both locations. No privilege workaround is
used to exploit the temporary unit's overly permissive development mode.

Keep raw runtime logs and database backups private. The failed-auth CPU loop,
shell SIGSEGV and first-boot/OTA regressions remain release blockers.

## Upstream replacement and dependency preflight

The 3 October follow-up found official [Lomiri MR 331](https://gitlab.com/ubports/development/core/lomiri/-/merge_requests/331),
which describes the same persistent hidden-window failure. It remains open.
Its original commit [598d550](https://gitlab.com/ubports/development/core/lomiri/-/commit/598d550be9d8175e645ee5f0585421b7c9c412ca)
sanitizes transient states on save and load in WindowStateSaver.qml. Prefer
this existing correction over the earlier local C++ candidate. The later MR
revision b28ae27 uses `state` in load() without declaring it and does not
retain the save guard; it is not suitable for direct backport as inspected.
This assessment concerns that exact unmerged revision, not a future fix.

`lomiri-window-state-upstream.patch` contains the original upstream diff.
`check-window-state-saver.js` executes the actual QML JavaScript load/save
functions in an isolated context: usable states survive, and Minimized,
Hidden and Unknown fall back to a usable previous state or Restored.
The regression fails against installed source fcac00b and passes with the
original upstream patch. This is a logic test; full QML/compositor and phone
lifecycle validation remain necessary. The old storage patch is historical
and is no longer applied by the build script.

The first package build used newer builder libraries. Normal APT simulation
refused installation because connectivity and gesture minimum versions had
advanced, and the builder used stock LightDM 1.32 while the phone uses the
UBports LightDM 1.30 fork. No package was installed and dependencies were not
bypassed. The four original Lomiri packages were downloaded from the signed
UBports repository to a private rollback directory on the phone.

The revised conventional native ARM build pins the relevant development and
runtime libraries to the installed 26.04 versions, preserving the current
phone base and LightDM fork. Package suffix is `+a50state.2`. Pins and resulting
runtime dependencies accompany the artifact. A complete APT dependency
simulation is still required before installation; compilation alone is
insufficient. No authentication, vendor or recovery change is part of this
correction.

The first matching-header run (37153801896) stopped during dependency
resolution because QML toolkit packages require their gesture library at an
exact matching version. Pin the complete source package families, rather
than a subset of their binary packages, using APT's documented `src:` syntax
([apt_preferences](https://manpages.debian.org/bookworm/apt/apt_preferences.5.en.html)).
This builder-only correction keeps the toolkit, its development packages and
runtime libraries coherent. The phone still has no new Lomiri packages.
