# 041 — Authentication CPU loop and Terminal reopening

3 October 2026. These are development-image release blockers. No permanent
authentication or app-lifecycle correction has been established by these checks.

The user's newer installer output was real: sudo and dpkg logs show an
authenticated installation at 17:45 phone local time. It replayed the original
dependency-incomplete installer and left the three QtMir packages unpacked.
The corrected repair has since replaced both `/tmp/a50-fix.sh` and
`/tmp/a50-repair.sh`; its authenticated execution remains pending.

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

The temporary `90-a50-layout-probe.conf` wizard wrapper was then removed. The
full greeter was restarted with the standard `lomiri-systemd-wrapper
--mode=full-greeter` command; the tested QtMir library override remains until
normal package installation is complete. Terminal was requested through its
ordinary launcher again. The user confirmed that tapping Terminal still returns to the drawer. Recovery repair is therefore staged and recovery access has been requested; no offline package operation has yet been performed.

No authentication dialog was bypassed, credential captured, or Terminal data
erased. Preserve private runtime logs locally. Required next: finish package
repair, recover normal Terminal UI, verify repeated close/reopen and other
apps, remove the remaining temporary overrides, then validate a clean boot.
