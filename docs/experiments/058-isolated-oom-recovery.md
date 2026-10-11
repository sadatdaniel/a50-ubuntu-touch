# Isolated real OOM recovery

11 October 2026, 08:09 CEST. Requested by the owner after the overnight sleep
test. Kernel aa17 / Ubuntu Touch 26.04. No global RAM exhaustion, production
memory limits, OOM daemon/policy changes, kernel flash or security changes.

The native cgroup-v1 memory controller is present and enabled; panic_on_oom=0,
oom_kill_allocating_task=0. Available memory is about 1.3 GiB, with existing
zram swap. systemd-oomd is inactive. This test therefore exercises the real
kernel memory-cgroup OOM killer, not systemd-oomd or Android app reclamation.

## Conventional bounded test

[Kernel memory-controller documentation](https://docs.kernel.org/admin-guide/cgroup-v1/memory.html)
describes isolated resource limits and selection of an OOM victim inside the
limited group. The documentation warns that older details need comparison
with the running kernel; actual cgroup files and outcomes are checked here.

Run scripts/experiments/check-isolated-oom.sh as root through normal authorized
maintenance, with capture-kmsg.py beside it. The script requires root RO,
AppArmor Y, panic_on_oom=0 and over 512 MiB available memory. It launches a
temporary native service as phablet, with MemoryMax=64M, OOMScoreAdjust=500,
OOMPolicy=continue, no restart, a 45-second maximum runtime and five-second
stop timeout. It verifies the actual cgroup RAM limit and sets/verifies its
memory-plus-swap limit to the same 64 MiB before releasing the allocation gate.
There is no write to the root/global cgroup or production service limits.

A disposable Python worker touches memory in 8 MiB blocks, with an additional
hard workload ceiling of 128 MiB. Its small shell supervisor remains briefly
after the worker dies so the memory-cgroup OOM counter can be captured. Native
kernel evidence must name that exact worker PID, exit must be 137 (SIGKILL),
and the counter must show one OOM kill. Mere allocation failure or a runtime
timeout is not a pass. A subsequent small allocation must succeed, and the
kernel boot ID and original shell/Waydroid identities must be unchanged.

Cleanup stops/resets only the temporary unit, terminates only the diagnostic
kernel reader and removes only its own /run files. Evidence remains private
under /userdata/a50-oom-test. Root never needs remounting. No persistent test
service, new package or permanent memory limit is installed.

## Hardware result

Private cohort /userdata/a50-oom-test/20261011T060934Z, host private archive in
this task's work/private/oom-20261011. Verified archive SHA256:
1a55850eb310857f90574c375e6577e1609032115a7f2c49f79a49b0bc99d7ce.

- Memory-cgroup oom_kill changes from 0 to 1, with under_oom back to 0.
- Kernel explicitly reports a memory-cgroup OOM and kills worker PID 35383.
  Its supervisor records WORKER_EXIT=137; the expected temporary unit failure
  is retained privately before resetting its diagnostic state.
- POST_OOM_ALLOCATION=PASS; original boot unchanged, Lomiri PID 5596 and
  Waydroid launcher/init PIDs 16925/17064 unchanged, both user services active
  with NRestarts=0. Android remains RUNNING.
- Temporary runtime directory removed; test unit inactive, final failed-unit
  count zero, root RO and AppArmor Y.

The bounded kernel OOM isolation/recovery check passes. Phone/Waydroid visual
responsiveness is being checked separately with the owner. This does not prove
global low-memory victim selection, Android low-memory killing/relaunch,
whole-container restart, swap-thrashing response or sustained-pressure UX.
Those are distinct release validations; do not force global RAM exhaustion
or change production memory policy based only on this result.
