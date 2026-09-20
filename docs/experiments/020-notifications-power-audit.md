# A50 upstream, notifications and power audit — 2026-09-20

## Direct answers

Reliable deep suspend/resume does not work yet. aa9 passed nine PM diagnostic
cycles, but its real sleep attempt lasted11ms and USB endpoint restoration
failed with -110. Cable reconnect recovered USB; a software reconnect did not.
Current aa1 boot cb53ecb1-a42d-48fd-8bb4-95810ca82c39 has zero suspend attempts
as of07:35CEST. Screen-off and deep suspend must not be conflated.

Ubuntu26.04.1 stays installed. Authentication remains unchanged after the user's
explicit decision to leave it alone. The polkit127 socket helper requires
SO_PEERPIDFD, absent from kernel4.14. Its own supported legacy helper proposal
needs a setuid-root permission change, not older or additional packages. User
later expressed openness to suggested packages; that is not an explicit
approval of the previously declined authentication-mode change. Password
changes remain a release blocker. Do not bypass authentication or downgrade.

## Upstream comparison

Queried official GitLab API and refreshed signed UBports26.04-1.x metadata in
/userdata/a50-session20-release/apt-audit, leaving normal package lists intact.
Normal package lists were last refreshed September3, so their claim of no new
candidate was stale.

- lomiri-push-service: installed Aug28 ef1c304a (0.100.2), upstream/current
  candidate Sep7 201da1f1 (0.100.3). September5 commits64cd216a and9aa53b53 fix
  general D-Bus signal watching and NetworkManager PropertiesChanged watching.
  Official project: https://gitlab.com/ubports/development/core/lomiri-push-service
- Lomiri: installed0.6.1 e12b69; current candidate0.6.2 081274, Sep18. Recent
  main changes include greeter QML touch-compression change05c1934d onSep17.
  This is not evidence that a screen-wake or charge-estimate fix is included.
- Repowerd installed f3bf63 matches main f3bf6322, Aug19. Its tree already
  includes729c08a7, fixing screen-on requests from system services.
- Ayatana power indicator installed4aed57e July29; candidate506c541 Sep5 adds
  camera-HAL flashlight backend. No charge-estimate correction established.

Push0.100.3 ALONE was installed from signed-repository-verified packages. Exact
old0.100.2 and new0.100.3 debs plus SHA256SUMS retained in apt-audit/packages.
Simulation required only that one package, no dependency installs/removals.
User notification service restarted, user daemon metadata reloaded, service
active/running PID551004; root filesystem returned read-only. No polkit or
other UI package was changed. Full Lomiri simulation pulls many dependencies;
that update is not yet applied. Broad upgrade is not a validated release.

The device runs lomiri-push-service, lomiri-account-polld and Lomiri notification
QML. There is no verified separate replacement notification system to switch
on. The 'new notification system' the user heard about was not specifically
identified. Current upstream improvements are now in the installed push daemon.
End-to-end delivery remains untested. Before update, repeated 'unable to get
helper output; putting payload into message' errors appeared. exec-tool exists
at its new libexec path and logs show it is executed, so a missing executable
was not established. Monitor/reproduce after update without exposing payloads.

## Random screen wakes and charging

User thinks random screen wake happened with charger connected. Historical
repowerd logging was too sparse to attribute cause. Power-key events appear,
but without an exact incident timestamp those cannot explain random wakes.
Current boot has no deep-suspend entries. Investigate charger transitions,
notification-driven screen requests and input events rather than assuming
suspend spontaneously resumes. Do not disable notifications or wake sources
without evidence.

User clarified the comparison was approximately50% in the top indicator versus
15minutes until full on the lock screen. These are different measurements and
not intrinsically contradictory. Charging-time accuracy still needs a timed
charging-session comparison. At inspection both UPower battery and DisplayDevice
report100%/fully charged; kernel time_to_full_now still reports110 despite zero
current. That stale raw value is not proof either UI displayed it.

Installed and latest upstream BatteryMonitor.cpp both use UPower DisplayDevice.
Potential stale-refresh defect: timeToFullChanged emits only when an event has
BOTH TimeToFull and Percentage and state is charging. Need event-level validation;
do not claim this caused the user's percentage-versus-time observation.
https://gitlab.com/ubports/development/core/lomiri/-/blob/main/plugins/BatteryMonitor/BatteryMonitor.cpp

## Fingerprint test continuity

Test boot remains running with sec_efs /dev/sda7 at /efs ro,noload. Automatic
rollback completed Sep19 at22:02:59; original Android image and hooks restored
on disk. Test image remains mounted until reboot. User has not yet provided
an enrollment outcome. File-only trace captured an attempted /efs/biometrics/
meta/cell_id access returningENOENT; this alone does not diagnose capture.
Calibration file presence and read-only mount are confirmed, capture is not.

Next: user-visible fingerprint test with private vendor logs; USB balanced
hardware-restoration candidate (not generated/built yet after earlier tool
usage-limit interruption); security-enabled candidate boot and bounded sleep
ladder. Preserve rollback/TWRP/userdata and resolve authentication before any
stable-release claim.