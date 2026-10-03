# 039 — Lock-security page cannot load on current Qt 5

3 October 2026. Status: diagnosed and reproduced; minimal correction tested in
isolation and through a temporary standard Settings panel. Conventional package build is pending.

The user completed clean onboarding with swipe-only unlocking, then reported
that selecting a different unlock method did nothing. The user-session journal
records repeated failures in LockSecurity.qml at line 72:

```
RegularExpressionValidator is not a type
```

Installed lomiri-system-settings is
1.4.0+0~20261001195229.487+ubports26.04.1~1.gbpd10c47. Its page imports
QtQuick 2.4 but instantiates RegularExpressionValidator. The installed Qt
5.15.18 type registration exports that validator starting at QtQuick 2.14.
Consequently the page fails before a change-password dialog can open. This
failure is distinct from the earlier polkit SO_PEERPIDFD helper problem.

## Upstream comparison

The official [Qt 6 preparation commit 73e06e78](https://gitlab.com/ubports/development/core/lomiri-system-settings/-/commit/73e06e789b3171d605fa5e6712174722ac5e6f3f)
renames RegExpValidator/regExp to RegularExpressionValidator/regularExpression
without increasing the QtQuick import. It was committed to the branch on
24 September. Main d10c4792 still has the same import and validator on
3 October; no matching open fix was found in the inspected issue/MR search.
Do not represent that limited search as proof that no upstream fix exists.

The candidate lock-security-qtquick-import.patch changes only the page import
from QtQuick 2.4 to 2.14, retaining the new validator, its digit/length rule,
password handling and authentication checks. It does not revert the package,
add a default password or bypass authorization.

## Reproduction

Run scripts/experiments/check-lock-validator.qml using the installed Qt 5
qmlscene in an offscreen software-rendering process:

```
. /etc/profile.d/hybris-static-tls.sh
XDG_RUNTIME_DIR=/run/user/32011 QT_QPA_PLATFORM=offscreen \
QT_QUICK_BACKEND=software timeout 10 /usr/lib/qt5/bin/qmlscene \
scripts/experiments/check-lock-validator.qml
```

The real phone reproducer exits 0: import 2.4 raises the exact reported type
error, import 2.14 creates the validator, and its synthetic short/non-digit
inputs are rejected while valid four/five-digit inputs are accepted. No real
credentials are read or changed. The full page was then tested using the standard user-local Settings panel discovery mechanism, with a private copy of the existing security/privacy QML and only the import corrected. The user successfully chose a private credential; `passwd -S` changed from NP to P. No credentials were collected. The temporary panel must be removed after validating the conventional package.

Read-only account queries show no password, password mode 2 and Locked=false,
consistent with the user's swipe-only setup. The supported legacy polkit helper
is already setuid-root and its socket is masked; both accounts-daemon and the
polkit agent are active with no counted restarts. The absence of an old shared
development password is intentional, not this page-loading error.

Required next: build and install the import fix conventionally using `build-lock-settings-package.sh`, verify the normal page opens, test PIN/password/swipe changes
and administrator authentication, then reboot/OTA persistence. Preserve the
current credentials until the user chooses to change them. The user resumed repairs and ran the prepared package installation after setting a credential. Do not publish temporary panels or diagnostic access in a final image.

## Other fresh-install observations

Camera currently fails to load its QML plugin because libexiv2.so.27 is missing.
The current signed 26.04 UBports index offers libexiv2-27-compat, version
0.27.6-1ubports1+0~20260529190549.1+ubports26.04.1~1.gbp94be66. A verified
844082-byte package is staged; all dependencies are installed. It is now installed and configured; the camera QML plugin resolves all of its shared libraries. Camera preview and video still need functional validation. The later aa6 records confirm working camera preview after AppArmor
socket fixes; do not repeat the superseded experiment 014 conclusion as the
current baseline. Video recording remains unvalidated.

A private native Recents screenshot confirms distorted application previews.
Official [Lomiri commit ac0b5dca](https://gitlab.com/ubports/development/core/lomiri/-/commit/ac0b5dcad3bffc8c7bc9a80e2ded03048a2c5149),
merged in [MR 330](https://gitlab.com/ubports/development/core/lomiri/-/merge_requests/330),
changed PadOrCrop to Stretch to support Wayland fractional scaling. This is a
focused lead, not a demonstrated correction on this Mir1 installation.

Waydroid 1.6.3 is installed, its default system launcher has NoDisplay=true,
and no initialized Android images or user launcher are present after the wipe.
The [official setup flow](https://docs.ubports.com/en/latest/userguide/dailyuse/waydroid.html)
requires waydroid init. No Android image download was started in this audit.

System and user failed-unit lists are empty. AppArmor is enabled. LightDM,
Android LXC, repowerd, USB, modem and Bluetooth services are active with no
counted restarts; user audio, media-hub and push services are also active. The
A50 Wi-Fi hooks are present in DeviceInfo. Fresh suspend counters are zero,
so earlier development-image sleep results do not validate this installation.
Root has 1.3 GB free and userdata 102 GB free. Temporary wizard/library overrides
and the root diagnostic unit still require removal before final-image checks.
These observations are not a stability or release-readiness claim.
