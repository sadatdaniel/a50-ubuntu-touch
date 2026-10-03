# Fresh suspend activation and read-only image health

4 October 2026. Fresh aa13/26.04 had zero suspend attempts and only the Android
suspend service's main/binder threads. Earlier aa12's 35 successful cycles do
not establish automatic sleep on this new installation.

## Native activation and startup ordering

The exact GSI 1542 system/hardware/interfaces revision is
a2fe15bf96c8bb88c174ac61eab6c013a04332c4. Its [SystemSuspend source](https://android.googlesource.com/platform/system/hardware/interfaces/+/a2fe15bf96c8bb88c174ac61eab6c013a04332c4/suspend/1.0/default/SystemSuspend.cpp)
shows enableAutosuspend starts one detached worker and returns true; later
calls return false because the static initialized flag is already set.
This establishes the meaning of both replies for this exact shipped base.

Using its existing privileged Android service API with USB connected and a
timed native wake lock produced true on the first call, a new thread blocked
in pm_get_wakeup_count, then false on the repeated call. The three initial
main/binder threads became four. The fresh automatic worker is now present;
this is stronger evidence than interpreting a parcel reply alone.

The existing activation script still uses Android SDK 30's native transaction,
with no forced suspend write. validate-autosuspend-startup.sh requires the
observed boot ID, connected USB, AppArmor Y and an active repowerd. It stages
the existing one-shot unit only under /run, after repowerd's Type=dbus readiness,
then verifies its InvocationID changes across a normal repowerd restart.
The lifecycle check passed; its repeated calls correctly reported already
active. Android retains wake-lock and wakeup-count arbitration.

This is a runtime startup experiment, removed by reboot. The normal selected
a50.yaml already contains the packaged Wi-Fi hooks. No permanent activation
service is yet installed in the release overlay. USB kept the phone awake:
success/fail/resume counters remain zero, so this adds no sleep-cycle evidence.
Next: timed unplugged screen-off test, screen/touch and network recovery,
then permanent image integration and a fresh normal reboot check. Android
container/SystemSuspend restart recovery also remains to be tested.

## Midnight package-backup failure

The new dpkg-db-backup.timer fired at midnight. Its installed script backs up
the package database into /var/backups; that directory is on read-only loop0,
so copies/rotations failed with Read-only file system. Package database health
and free userdata space are separate from this timer's destination error.

The image overlay now adds a normal [systemd path condition](https://github.com/systemd/systemd/blob/main/man/systemd.unit.xml):

```
[Unit]
ConditionPathIsReadWrite=/var/backups
```

A runtime drop-in using that condition passed: starting the unit produced
ConditionResult=no, inactive state and success, with no backup execution.
System failed-unit count returned to zero, and root stayed read-only. This
skips a job whose destination is immutable; it leaves the original timer and
backup command available when that directory is writable. No recurring repair,
custom backup implementation, remount or writable-path change is introduced.
check-readonly-backup.sh reproduces the guarded runtime check; the image overlay
must be included in the next clean build. The running fix currently lives in
/run and disappears on reboot.

Native unit verification also exposed the already-known malformed GNSS startup
link on the installed image (the repository link mode was previously corrected),
and an upstream bluebinder StartLimitIntervalSec option in the Service section.
Neither warning proves a camera or suspend failure. GNSS first-boot enablement
and the BlueZ keyboard stability checks remain open.
