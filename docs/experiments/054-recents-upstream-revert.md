# 054 — Recents fixed by upstream rendering revert

2026-10-10. Native runtime test passes; conventional package validation pending.

The installed Lomiri fcac00 source included MR 330, which changed
SurfaceContainer.qml from MirSurfaceItem.PadOrCrop to Stretch. With the
installed Mir1 stack, Recents squashes whole application buffers into its
preview geometry. The user reported this after the clean installation and
reconfirmed it today; private full-display screenshots show the distortion.

Upstream [5fc43d75272c62d1317a4225e9e77087691a97e1](https://gitlab.com/ubports/development/core/lomiri/-/commit/5fc43d75272c62d1317a4225e9e77087691a97e1), merged by
[fe38aa78f3b1c69319ba914c3d48f78543b8e186](https://gitlab.com/ubports/development/core/lomiri/-/commit/fe38aa78f3b1c69319ba914c3d48f78543b8e186) on 9 October, reverts that exact one-line change. No density,
layout, GPU driver or app modification is needed.

After checking the original file hash, the exact upstream setting was loaded
through a temporary QML bind and normal full-greeter restart. Root remained
read-only and USB-only maintenance remained accessible. The user confirms
Recents is fixed. A private after screenshot of Terminal/Settings shows normal
content proportions. This is runtime evidence, not permanent package/OTA proof.
The public test-recents-upstream.sh records the original hash, applies only
this change and supports --rollback. A reboot also removes its bind.

## Conventional packaging

The existing pinned builder now supports --upstream-recents. Its original
fcac00/a50state.2 build remains the default for reproducing experiment 041.
The new profile uses current official Lomiri fe38aa78, including the Recents
revert and panel singleton correction, while retaining the exact previously
validated MR 331 window-state backport. The current official source still lacks
that backport, so replacing it with unmodified upstream would risk losing the
Terminal/Settings reopening correction.

Candidate version:
`0.6.2+0~20261009095335.519+ubports26.04.1~1.gbpfe38aa+a50state.3`.
Build-only source preferences retain the phone's matching LightDM, indicator
network and UI toolkit versions; the new profile also selects official QtMir
ac3ee9 packages validated in experiment 053. No phone-wide freeze is added.
The actual WindowStateSaver regression must fail on the unpatched upstream
source and pass after the existing backport. Native ARM64 CI uses ordinary
Debian packaging and records dependencies/checksums.

Required before completion: successful build, a reviewed exact matching package
transaction, bind removal, full reboot, Recents and repeated app reopening
checks. A clean image and an OTA carrying the required packages remain release
requirements. This correction is already upstream; future compatible upstream
images contain it. Device and unmerged shared fixes still require maintained
image integration. OTA is not enabled on this development phone.

Raw screenshots/session logs remain private. Vendor, recovery, authentication
and user data were not modified by this rendering test.
