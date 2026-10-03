# 037 — Clean wizard Mir1 scaling regression

Status: the current-source native package build passed. Its privately loaded
library restores the measured wizard geometry and scrollable content. The user
now confirms that the installation wizard displays correctly. They also report
distorted app content in Recents, Camera not starting, and no Waydroid launcher.
These fresh-installation reports require screenshot/log collection before
declaring the display or onboarding path fully validated. No permanent package
installation or second-boot claim yet.

## Why the earlier image worked

Port commit [79f7c378](https://github.com/sadatdaniel/a50-ubuntu-touch/commit/79f7c378fcae7ff1ba13064bf6c1f7ad8eaa6c6d)
on 3 September 2026 records working setup after binder permissions and
`GRID_UNIT_PX=21`. It explains the density calculation: 8 × 420 / 160 = 21.
That value and `QTWEBKIT_DPR=2.625` remain unchanged in the current overlay.
Later relocation into `overlay/system/` did not remove them. The exact QtMir
package installed on the erased old system has not been recovered.

The clean rootfs 376 instead contains QtMir
`0.7.2+0~20261001152353.82+ubports26.04.1~1.gbp38268e`, including
[fbc50e5](https://gitlab.com/ubports/development/core/qtmir/-/commit/fbc50e5104a9efc4f115aad0601d650b1b8b6d65),
merged on 24 September in [MR 162](https://gitlab.com/ubports/development/core/qtmir/-/merge_requests/162).
That change exposes Mir's scale as native Qt DPR and uses output extents for
screen geometry. It postdates the working September checkpoint.

The paired Mir1 package is
`1.8.3-0ubports1+0~20260922141456.15+ubports26.04.1~1.gbpebc14f`.
The correct upstream repository is
[packaging/mir1](https://gitlab.com/ubports/development/core/packaging/mir1),
not the archived `core/mir` tree. At its installed ebc14fb revision,
`debian/patches/series` still applies
`ubports/0007-DO-NOT-MERGE-Temp-fix-for-wrongly-scaled-buffers.patch`.
That patch deliberately removes division by scale from display extents.
Thus QtMir receives physical dimensions and also scales the scene by 2.625.
This is an upstream userspace compatibility mismatch, independent of the
boot-image packaging.

## Live evidence

Authenticated USB diagnostics and an upstream-supported `--qmlfile` wrapper
around the installed shell record the actual language page. Every ancestor
has 1080 × 2340 geometry, zero translation and scale 1. The language list has
height 2172, 35 rows at height 56, and content height 1960. Its current index
is English; contentY and originY are zero. It correctly concludes there is
nothing to scroll, but native DPR 2.625 renders that logical scene outside
the physical 1080 × 2340 framebuffer. Native screenshots show the final
languages, with the header and Next text clipped away.

An isolated offscreen run of the installed wizard at DPR 1 instead produces
21-pixel grid units, 147-pixel rows and scrollable content height 5145.
The installed language QML therefore does not need a device-specific layout
or scrolling modification.

`QT_ENABLE_HIGHDPI_SCALING=1` was tested in a temporary user-unit override.
It changed logical geometry without correcting the native mismatch; the
same clipping remained. The override was removed and the shell restarted.
Do not ship this flag or reduce the device's grid unit to hide the issue.

## Candidate and required checks

The [native Ubuntu 26.04 ARM64 build](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37122912585)
passed on 3 October. The three runtime .debs total about 625 KB, with dependency
manifest and verified checksums. Source 38268ef and the one-line compatibility
patch are published with scripts/experiments/build-qtmir-mir1-package.sh. This
uses ordinary dpkg-buildpackage; hardware-dependent tests are deferred to the
phone, not reported as passing in CI. The source revision is fetched explicitly
so later movement of upstream main does not prevent reproducing this experiment.

The temporary wizard process maps the candidate library from a private user
directory. Installed packages remain intact. The header is now 336 pixels,
the list viewport 1899, rows 147 and content height 5145; the footer sits at
2235 with height 105. The list now correctly has content to scroll. The service
has zero automatic restarts. The user subsequently confirmed correct wizard
display and completed onboarding with swipe-only unlocking. The same full-greeter
process continues to host the session with its temporary library override.
Recents distortion and a separate lock-settings page-loading regression remain
open; see experiment 039. The QML probe changes no behavior.

Build current QtMir 38268ef against signed Ubuntu Touch 26.04 dependencies,
restoring native DPR 1 for its existing Mir1-only build. Its CMake explicitly
rejects WITH_MIR2; Mir1's application scale remains 2.625. First load the
candidate through a temporary library path and rerun the actual layout and
screenshot checks. This preserves current packages until behavior is proven.

Required: header and Next visible, English reachable, correct row size,
normal touch/scroll, complete setup with user-chosen credentials, normal
application scaling, screen rotation and second boot. Only then package a
reproducible compatibility fix. Prefer a coordinated upstream fix when it
becomes available; do not silently carry a permanent device workaround for
this generic regression.

All temporary QML/library/unit overrides, the diagnostic root unit and
force-ADB marker must be removed before final fresh-image validation.
Host authorization stays enabled throughout. Raw screenshots and logs remain
private. Vendor, recovery, calibration and account credentials are untouched
by the scaling investigation.

## Normal package installation checkpoint

Experiment 040 records completed normal QtMir installation with its matching
content-hub dependency set. After recovery repair, the normal boot maps the
package-owned library with SHA256
`825ef29b11cbc5a543bd53a18040a7d6309be89e5489dd3d507d8f22b25bc183`,
uses the standard full-greeter command and no private library override. Root is
read-only. Earlier temporary staging statements above describe the experiment,
not the current package state. Recents and app lifecycle remain open.
