# Experiment 011 — two System Settings quirks: updates spin, PIN "wrong"

**Date:** 2026-09-05 · **Status:** ✅ both diagnosed · **Device needed:** yes

Two user-reported Settings problems, investigated together because both turned
out to be Ubuntu Touch behaviour on this port rather than device faults.

## A. "Checking for updates" spins forever

### Cause — Wi-Fi is misdetected as mobile data

`system-image-cli --dry-run` hangs in the download of the GPG keyring, in
`lomiri-download-manager`. Its log is explicit:

```
network_session.cpp:79] Connection type gsm
manager.cpp:240] Create group download == {... allowMobile0 ...
    User-Agent: ... device=halium_arm64;channel=daily;build=0}
```

The download manager believes the active connection is **gsm** and the request
carries **`allowMobile 0`** (updates are set to "download on Wi-Fi only"), so it
queues the download and never runs it — the spin the user sees.

The phone is actually on Wi-Fi: `swlan0` is `connected` and the default route
(`metric 600`, below `rmnet0`'s `700`), and the keyring URL fetches with HTTP
200 directly. But **both** connections are active at once —

```
Tintin5G          802-11-wireless  swlan0
Congstar Internet gsm              ril_0
```

— and the Lomiri connectivity API reports the pair as `gsm`. That is the bug:
the connection-type reporting in `lomiri-indicator-network` / the connectivity
API, which the download manager trusts, does not prefer the active Wi-Fi route.

An earlier one-off in the same log — `HostNotFoundError` for
`image-master.tar.xz` on 09-03 — was the separate IPv6-only-DNS issue and is
resolved; the server resolves and responds now.

### Confirmation and the fix

`system-image-cli` has `--override-gsm` precisely for "set to Wi-Fi only but
currently on GSM". With it, the check completes instantly:

```sh
system-image-cli --override-gsm --dry-run
# -> Already up-to-date
```

That both proves the diagnosis and is the CLI workaround. Running it also caches
the result, after which the Settings page stops spinning and shows
"up to date".

### The other half: there is no update to get anyway

`system-image-cli -i` reports `current build number: 0`, `channel: daily`,
`device name: halium_arm64`, `last update: Unknown`, and `/etc/system-image/`
has an **empty** `config.d/` and no `channel.ini`. This is a self-built GSI
image with no OTA lineage, so there is no system-image update to receive
regardless — updates to this port come from rebuilding and re-flashing, not
OTA. The "unknown series / daily" the Settings channel page shows is the same
fact. So the spin is worth fixing for UX, but nothing is actually withheld by
it.

### Not done here

The real fix is in the connectivity-type reporting (`lomiri-indicator-network`
/ the connectivity API) so that an active Wi-Fi default route is not reported
as `gsm`. Setting update auto-download to "always" would also make the GUI
check complete, but on this port that is only safe because the connection is
misdetected — it is a workaround, not a fix, and is not applied automatically.

## B. Removing the PIN says the passphrase is wrong

Switching Lock security from PIN to swipe asks for the existing passcode;
entering the correct `1234` is rejected as not matching.

`1234` is genuinely correct. It matches the stored hash in **both** password
stores this system uses:

* `/etc/shadow` — `phablet` `$6$SZeU4v1nZ…`, verified: `1234` matches.
* `/var/lib/extrausers/shadow` — `phablet` `$6$CANnlFXr…`, verified: `1234`
  matches. (Ubuntu Touch keeps `phablet` in `extrausers`; `common-auth` checks
  `pam_extrausers.so` first.)

So authentication is not the problem — both PAM stores accept the password.
This is a **known UBports regression** in the lock-security change flow in
recent 26.04 (`lomiri-system-settings 1.4.0`), reported upstream: the
change-security dialog rejects a correct current credential. `pam_fscrypt` is
only `optional` in the stack and cannot cause it, and `/home/phablet` is not
fscrypt-encrypted here, so that is not involved either.

**Recommendation:** leave the PIN in place. It is not broken, and a PIN or
passphrase is wanted anyway as the fallback for fingerprint unlock
(experiment 012). Changing the lock method from the CLI is possible but touches
the greeter's own state and is not worth the risk to remove a working PIN.
