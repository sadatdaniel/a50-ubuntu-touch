# 037 — Clean wizard Mir1 scaling regression

Status: root cause traced; a temporary rebuild of current QtMir is being
prepared. No permanent display change or completed-onboarding claim yet.

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
