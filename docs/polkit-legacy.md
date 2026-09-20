# polkit authentication on the A50

On September 20 the user explicitly approved the legacy helper configuration,
superseding the earlier request to leave authentication unchanged. The installed
polkit 127 package is retained. Its socket helper requires SO_PEERPIDFD, absent
from this 4.14 kernel; upstream explicitly directs unsupported platforms to use
the setuid helper. This is a compatibility fallback, not a password bypass.

The helper remains root:root with unchanged binary hash, now mode 4755 through
dpkg-statoverride. polkit-agent-helper.socket is masked and stopped. Masking
while active left a stale socket pathname; after confirming there was no
listener, that pathname was removed. Root was returned to read-only. PAM and
account passwords were not changed, and no packages were added or downgraded.

Validation on aa1: a phablet process requested the real
org.freedesktop.accounts.user-administration authorization through pkcheck and
its internal agent. An intentionally wrong password was rejected (exit 1);
the current password was accepted (exit 0). No account-setting action was
performed. Settings UI confirmation and repetition with AppArmor enforcing
remain required. Do not equate this check with a complete password/PIN change.

The offline image builder calls scripts/release/configure-polkit-legacy.sh.
It rejects the live host root, non-root-owned helpers and conflicting overrides;
it preserves the helper binary and configures the same permission override and
socket mask. Disposable fixture checks covered repeated application and
conflict/host-root rejection. A fresh real rootfs build remains to be tested.

OTA integration must preserve/reapply this configuration in every resulting
image and test authentication after an update. An initial rootfs build hook
alone does not establish that an upstream OTA tarball preserves it. Reassess
this fallback if a future kernel/package supports the socket protocol.

Live rollback state is private under
/userdata/a50-session20-release/polkit-legacy. Original mode was 0755 and the
socket was enabled/active. Rollback requires removing the statoverride,
restoring 0755, unmasking and enabling/starting the socket, then restoring the
root mount mode. That restores the original configuration and its known
unsupported-kernel failure; it is not a functional alternative on this kernel.

Upstream: https://github.com/polkit-org/polkit/blob/127/src/polkitagent/polkitagenthelper-pam.c