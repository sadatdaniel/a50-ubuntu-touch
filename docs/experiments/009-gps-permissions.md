# Experiment 009 — GPS: why no app could ever get a location

**Date:** 2026-09-05 · **Status:** partly answered · **Device needed:** yes

## Question

GPS produced nothing for any app. The inherited diagnosis was that
`lomiri-location-service` refused every session with *"Client lacks
permissions"* because this kernel has no AppArmor, and that the fix was
therefore a kernel with AppArmor built in.

That kernel had already been built and **did not boot at all** (see
[008 appendix](008-bluetooth-hci-sock.md#appendix--apparmor-as-default-lsm-does-not-boot-2026-09-05)),
so the question was reopened from the start: *is a kernel change actually
required?*

## Method

One variable at a time, against the running device, reading the source and
config that is actually installed rather than upstream master.

## Result 1 — the inherited error message was wrong, the diagnosis was right

`journalctl` has **no** occurrence of "lacks permission" in any boot. The
string exists in `liblomiri-location-service.so.3`, but the service does not
log it — it is returned to the *caller* as a DBus error, which is why the
journal is silent and why this was never visible server-side.

Reproduced properly by calling the API directly. `Criteria` encodes **flat**
(no enclosing struct) as four bools, a double, then three `Optional`s that are
a bool each when empty — signature `bbbbdbbb`:

```sh
gdbus call --system --dest com.lomiri.location.Service \
  --object-path /com/lomiri/location/Service \
  --method com.lomiri.location.Service.CreateSessionForCriteria \
  true false false false 100.0 false false false
```

The real error is **not** the permission one:

```
Error: GDBus.Error:com.lomiri.location.Service.Error.CreatingSession:
Error creating session
```

`Error.CreatingSession` is the *generic catch* in the service skeleton.
`Skeleton::DBusDaemonCredentialsResolver` resolves each caller's AppArmor
profile through `libapparmor` before the permission manager is ever consulted;
with no AppArmor in the kernel that throws, and the catch turns it into this
message. So the conclusion "AppArmor is why location fails" was correct even
though the quoted message was not.

## Result 2 — no kernel change is required

`TrustStorePermissionManager::check_permission_for_credentials` tests
`TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING` **first** and returns
`granted` before it looks at the profile at all. This is not a hack invented
here: `lxc-android-config`'s own
`/usr/libexec/lxc-android-config/lomiri-location-serviced-wrapper` — the
`ExecStart` this device already uses — sets that variable when the Android
property `custom.location.testing` is `true`.

Setting it via a systemd drop-in instead (no dependency on an Android property
surviving in the container):

```ini
[Service]
Environment=TRUST_STORE_PERMISSION_MANAGER_IS_RUNNING_UNDER_TESTING=1
```

**Verified**, as `phablet`, on a clean boot:

```
(objectpath '/sessions/0',)
```

Sessions are created, `client_applications` lists a client, and
`StartPositionUpdates` is accepted.

**The trade-off is real and deliberate.** This grants location to any client
without the trust-store prompt. On this port nothing is confined anyway — there
is no AppArmor, so no app is isolated by it — and the alternative is that
location works for nobody. Delete the drop-in to restore the prompt the moment
a kernel with AppArmor boots.

**This retires the AppArmor kernel as a GPS blocker.** AppArmor is still wanted
for app confinement, but it is no longer on the critical path for GPS, and it
should not be rushed after the failed boot.

## Result 3 — `/dev/gnss_ipc` is root-only and the GPS daemon is not root

With sessions working, the Samsung GNSS HAL began logging three errors a
second, for as long as a session was open:

```
E vendor.samsung.hardware.gnss@2.0-service:
  Critical Error: lal_state_handle_transition: curST:1 pendingST:2
```

The string is undocumented anywhere online. Read the device instead:

| Evidence | Value |
|---|---|
| `/dev/gnss_ipc` as shipped | `crw------- root root` (0600) |
| `/vendor/etc/init/init.gps.rc` | `chmod 0660` + `chown system system` |
| same file, service block | `service gpsd` → `user gps`, `group system` |
| `gpsd` running as | uid **1021** (`gps`) |

So the vendor's own init says the node must be `0660 system system`, and its
daemon reaches it through the **system group**, never as root. That
`on post-fs-data` block does not run in the Halium container, so the node keeps
root-only permissions and `gpsd` cannot open it. Exactly the class of bug as
`/dev/hwbinder` in [006](006-what-we-missed.md) and `/dev/ion`.

The rootfs has a real `system` user at uid/gid 1000, so the vendor's intent can
be expressed directly as a udev rule:

```
KERNEL=="gnss_ipc", SUBSYSTEM=="misc", OWNER="system", GROUP="system", MODE="0660"
```

**Verified across a reboot:** `crw-rw---- 1 system system 10, 77 /dev/gnss_ipc`.

## Still open — GPS does not yet produce a fix

Both fixes above are necessary and both are confirmed; real apps (Pure Maps)
now register as location clients. They are **not sufficient**: no satellites,
no position. The fault is inside the vendor stack, and it is `gpsd`.

**What is healthy:**

* The kernel. `/userdata/dmesg-boot-first.txt` shows the Exynos GNSS interface
  driver (`gif`, KEPLER) probing cleanly — reserved memory at `0xFB000000`,
  shared-memory/fault/IPC regions created, `gnss_ipc created`. No kernel GNSS
  error in any test.
* The HAL. It registers `android.hardware.gnss@2.1::IGnss/default` and
  `vendor.samsung.hardware.gnss@2.0::ISehGnss/default` cleanly, then spins
  `lal_state_handle_transition: curST:1 pendingST:2` three times a second for
  as long as a session is open — it is asking `gpsd` for something and getting
  nothing.

**`gpsd` is inert.** One thread, sleeping in `hrtimer_nanosleep`. Its entire fd
table is `/dev/null` ×3 plus a zero-byte `/data/vendor/gps/gnssd.pid` — no
socket, no device. It has loaded **no vendor library at all**, notably not
`/vendor/lib64/libwrappergps.so`, which its own strings reference. It never
opens `/dev/gnss_ipc`, and it writes nothing to any logcat buffer, even after
`setprop dev.gnss.silentlogging ON` swaps in `gps.debug.cfg` (which also
produced no files in `silentGnssLogging`). Run by hand it prints nothing
either.

`/data/vendor/gps/chip.info` read `S.LSI,UNKOWN` (sic), dated weeks earlier.
Deleting it did not make `gpsd` re-probe — it is simply never rewritten.

### Ruled out — do not re-test these without new evidence

| Suspect | Finding |
|---|---|
| `/dev/gnss_ipc` permissions | was the bug, now fixed and verified across a reboot |
| `/dev/umts_boot0` permissions | `0660 system radio` is exactly what `/vendor/ueventd.rc` specifies; `cbd` holds it open. Stock-correct. |
| `/sys/devices/soc0/machine`, `revision` | both present and readable ("… Exynos9610", "2") |
| `/sys/power/wake_lock` | `radio:3010`, and `gpsd` carries gid 3010 — reachable |
| `/mnt/vendor/efs`, `/data/vendor/gps/sgee` | both mounted/present; the usual "missing EFS" answer does not apply |
| stale `chip.info` | deleted, no change |
| `vendor.gsm.sim.state` | empty on this port (ofono drives the modem from the host, so Android's framework never sets it). Setting it to `LOADED` changed nothing. |
| GNSS firmware in `/vendor/firmware` | none there; whether KEPLER needs a file at all is still unknown |

### Next single variable

**Install `strace`.** Every remaining question is a syscall question: what
`gpsd` polls in that nanosleep loop, and what it fails before giving up.
`strace`, `curl`, `gdb` and `ltrace` are all absent from the device.

Two traps that cost time here:

* `pgrep -f 'bin/hw/gpsd'` **matches your own ssh command line** and returns
  your shell's pid. Use `pgrep -x gpsd`. The same trap makes
  `pkill -f <pattern>` kill the session — already in the handoff's §3, and it
  still bit twice.
* Device time is CEST; `logcat` timestamps are UTC. A log that looks two hours
  stale is live.

## What not to redo

* Do **not** rebuild the kernel for AppArmor in order to fix GPS. It is not
  required, and the one attempt did not boot.
* Do not look for `lal_state_handle_transition` online — it is undocumented.
* The `/efs` data the Samsung GNSS stack wants **is** present:
  `/mnt/vendor/efs` is mounted from `sda3`, and `/data/vendor/gps` exists with
  its `sgee` subdirectory. Neither is the problem.
