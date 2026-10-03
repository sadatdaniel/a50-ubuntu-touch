# Direct maintenance access and Restart investigation

3 October 2026. The user requested direct OS access to reduce manual commands
and provided their existing administrator credential privately. Normal sudo.ws
authentication successfully started a temporary standard OpenSSH instance.
No credential is written to a script, log or repository.

## Reproducible temporary USB-only SSH

`scripts/experiments/start-maintenance-ssh.sh PUBLIC_KEY_FILE` runs as root
through normal authentication. Supply a freshly generated computer ed25519
public key over trusted, authorized ADB first. Keep the computer private key
outside the repository. The script prints the public key fingerprint for review.

The runtime instance listens only on phone 127.0.0.1:2222. Forward it using
`adb forward tcp:0 tcp:2222` and connect to the allocated computer localhost
port. Retrieve only the phone's public host key via the trusted USB path and
pin that key in a private known_hosts file before connecting with strict host
verification. Do not fetch private host keys or disable host verification.

Its root public-key login uses from=127.0.0.1 and restrict. Password login,
keyboard-interactive authentication, PTY, X11, agent and TCP forwarding are
disabled. Configuration/authorization stay under root-owned /run. The ordinary
ssh.service and global configuration remain unchanged. This provides temporary
administrator capability to the selected computer while the service runs; keep
Developer Mode/ADB authorized only for trusted computers.

Stop with `systemctl stop a50-maintenance-ssh.service` and remove its ADB forward
with `adb forward --remove tcp:HOST_PORT`. Reboot removes the runtime instance.
This is an opt-in development tool, not a service enabled in release images.
The active private session successfully collected the frozen recorder's native
stack and inspected system service health without asking the user to type again.

## Restart report

The user reports that the graphical Restart action only reloads Lomiri.
Ordinary authenticated sudo.ws reboot previously changed the kernel boot ID
and uptime, confirming a full system reboot. These are separate observations.
The current graphical dialog calls lomiriSessionService.reboot(). logind is
running with zero service restarts; its inspected journal contains no reboot
request in the current boot. Trace the session-service dispatcher and capture
a controlled menu request before assigning a cause or claiming this fixed.

The explicit PID/start-time/UID subject for the actual Lomiri process passes
both normal and multiple-session reboot policy checks. Its own session-service
CanReboot returns true. The graphical power dialog closes all windows before
calling the backend. A controlled capture of that path remains necessary;
no reboot-policy relaxation was applied. The unsuccessful camera test was
removed through the normal launcher and helper stop/start, and both original
library hashes were restored without a system reboot.
