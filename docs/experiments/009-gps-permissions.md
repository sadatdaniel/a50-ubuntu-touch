# Experiment 009 — GPS: why no app could ever get a location

**Date:** 2026-09-05 · **Status:** ✅ answered — GPS works · **Device needed:** yes

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

## Result 4 — the real blocker: `gpsd` waits for a boot animation

With permissions solved, GPS still produced nothing. The Samsung GNSS HAL
logged, three times a second, for as long as any app held a session:

```
E vendor.samsung.hardware.gnss@2.0-service:
  Critical Error: lal_state_handle_transition: curST:1 pendingST:2
```

That string is undocumented anywhere online. `strace` answered it in one pass —
the HAL is retrying a connection:

```
connect(7, {sa_family=AF_UNIX, sun_path=@"GNSSND"...}, 110) = -1 ECONNREFUSED
```

`@GNSSND` is an **abstract** unix socket. `gpsd` is supposed to bind it — the
name and its `spot_host/lal/lal_router.c` paths are both in the `gpsd` binary —
and it never did, because `gpsd` never initialised at all.

Tracing `gpsd` from startup showed its entire `main()`:

```
openat("/data/vendor/gps/gnssd.pid", O_RDWR|O_CREAT) = 3
flock(3, LOCK_EX|LOCK_NB)                            = 0
openat("/dev/__properties__/u:object_r:exported_system_prop:s0") = 4
mmap(...); close(4)
nanosleep({0, 250000000})     <- forever
```

It takes its lock, reads **one property**, and drops into a 250 ms poll loop:
one thread, never reads the `gps.cfg` given on its own command line, never
opens `/dev/gnss_ipc`, never binds a socket, logs nothing anywhere.

The property context pins it down. `exported_system_prop` contains only five
properties on this build:

```
persist.sys.locale  persist.sys.timezone  service.bootanim.exit
sys.boot_from_charger_mode  sys.shutdown.requested
```

**`service.bootanim.exit`** is the only one a GPS daemon would gate on. On
stock Android the boot animation sets it to `1` when it finishes. A Halium
container runs no boot animation, so nothing ever sets it, and `gpsd` waits
forever. All five were empty.

Setting it changes everything:

```sh
lxc-attach -n android -- /system/bin/setprop service.bootanim.exit 1
lxc-attach -n android -- /system/bin/setprop ctl.restart gpsd
```

| | before | after |
|---|---|---|
| `gpsd` threads | 1 | **12** |
| `@GNSSND` in `/proc/net/unix` | absent | **bound, with a connection** |
| `/dev/gnss_ipc` open by `gpsd` | never | **yes** |
| `lal_state_handle_transition` | 3/second | **gone** |

And real satellites arrive, through Ubuntu Touch's own hybris bridge:

```
gnssSvStatusCb: num_svs: 5
  prn: 7,  snr: 36.9, elevation: 66.4, azimuth: 88.3
  prn: 79, snr: 40.6, elevation: 48.0, azimuth: 64.8
  ephemeris_mask: 15, almanac_mask: 0, used_in_fix_mask: 15
gnssLocationCb: called
```

`used_in_fix_mask: 15` is four satellites used in the fix, and `gnssLocationCb`
is a real position delivered to the platform — repeating once a second.

### Made permanent

`a50-gnss-unblock.service` (in `overlay/`, and installed on an existing device
by `scripts/apply-device-workarounds.sh`) sets the property, restarts `gpsd`,
**waits for `@GNSSND` to actually appear** rather than assuming, then restarts
the HAL and `lomiri-location-service` — both cache their connection, so both
must come up after `gpsd` is ready.

Verified from a cold boot with no manual step:

```
a50-gnss-unblock.sh[3746]: gnss: gpsd bound @GNSSND
gpsd pid=3808 threads=12, /dev/gnss_ipc open, @GNSSND bound
```

with audio, Bluetooth (`hci0` up with its BD address), the container
(`sys.boot_completed=1`) and lightdm all unaffected.

### Left over

* `Critical Error: handle_sgee_aiding_request: sgeeReqType=6` — SGEE is
  Samsung's extended-ephemeris A-GPS download. Non-fatal; it only slows the
  first fix. Not investigated.
* `Unable to Initialize AGnss interface` / `Unable to initialize GNSS NI
  interface` from the hybris bridge — assisted-GNSS and network-initiated
  positioning are absent. Plain GNSS works without them.
* `visible_space_vehicles` over the CLI still reads empty even while the HAL
  is reporting five satellites. The data reaches the platform, so this looks
  like a separate reporting path; not chased.

## What not to redo

* Do **not** rebuild the kernel for AppArmor in order to fix GPS. It is not
  required, and the one attempt did not boot.
* Do not look for `lal_state_handle_transition` online — it is undocumented.
* The `/efs` data the Samsung GNSS stack wants **is** present:
  `/mnt/vendor/efs` is mounted from `sda3`, and `/data/vendor/gps` exists with
  its `sgee` subdirectory. Neither is the problem.
