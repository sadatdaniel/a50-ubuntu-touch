# 053 — Official QtMir replacement and graphical Restart diagnosis

2026-10-10. Ubuntu Touch 26.04 only. Development port; not a stable release.

## Upstream replacement

Official QtMir commit [23c1ede83dcc40d42a02dd31cad5ffed5b00f6f6](https://gitlab.com/ubports/development/core/qtmir/-/commit/23c1ede83dcc40d42a02dd31cad5ffed5b00f6f6), merged in [ac3ee9fbb90e0ef635229cbf66992626100c1a7d](https://gitlab.com/ubports/development/core/qtmir/-/commit/ac3ee9fbb90e0ef635229cbf66992626100c1a7d) on 8 October, guards geometry and DPR changes by Mir version. Its commit message identifies double scaling on Mir1. It restores DPR 1 and mode dimensions for Mir1 while preserving Mir2 behavior. This replaces the port's narrower one-line DPR patch.

Signed UBports metadata now offers official package version
`0.7.2+0~20261008000645.83+ubports26.04.1~1.gbpac3ee9`.
An APT simulation and completed ordinary installation changed exactly
libqt5mir1server1, qml-module-qtmir0.1 and qtmir-qt5-mir1, with no additions or
removals. Installed dependencies satisfy the official packages. Archive hashes
and exact preceding custom packages are guarded by the published
install-qtmir-upstream.sh. Packages occupy approximately 631 kB and grow the
installation by only 6,144 bytes.

This deliberately isolates the reviewed scaling change. A newer official
6a015ef package includes the broader miroil migration merged on 10 October;
that migration has not been validated on this phone. No persistent package
freeze or global APT preference was added by this experiment.

Installed server library SHA256:
`a12573d5ec57ba70d4ef9899a96aae2b365e982e776b36ed05bb603fda4f96ce`.
The normal shell reloaded with physical geometry 1080x2340 and application
scale 2.625. Package audit passed. No library bind or environment override is
used. Full kernel reboot changed boot ID; the official library survived with root
read-only, AppArmor Y, no failed system units and a clean package audit. The
user reconfirmed working touch/apps; Recents was still distorted.

## Recents

The user reconfirms distorted previews. A private full-display screenshot
shows stretched preview content in Gallery, OpenStore and Morph. No rendering
correction is yet demonstrated. Do not claim the scaling replacement fixes
Recents. The upstream texture placement path and native QML transform are
under investigation; avoid altering density or hiding the issue with layout
changes. Raw screenshots remain private.

## Graphical Restart

The user tapped Restart in the normal power menu with applications open.
Kernel boot ID remained unchanged. A bounded system D-Bus trace observed no
org.freedesktop.login1.Manager.Reboot call. The user service journal records
lomiri-full-greeter exiting with SIGSEGV at 13:03:24 CEST and automatic restart
count increasing to one. Client apps lost their compositor connection.

This establishes a shell crash before a reboot request, rather than a proven
login1/polkit reboot denial. It reproduces on the already running preceding
custom QtMir process; the automatic replacement process subsequently loaded
the new official libraries. Reproduction with the new process is outstanding.
Native crash collection is disabled (core limit zero); a targeted backtrace is
needed before changing the close-all-windows/dialog path. A normal authenticated
systemctl reboot was initiated to restore read-only root and check the package
replacement from startup.

## Reproduction and rollback

On this exact development installation, the private bundle is
/userdata/a50-qtmir-upstream-test. Official archives were fetched by APT through
signed metadata into cache/archives; the exact previous custom archives are
kept in rollback. The installer checks all package versions, architecture,
archive SHA256 values, an exact three-package APT plan and package audit, then
attempts read-only restoration in its exit trap. A full reboot is required if
the remount is busy. --rollback restores the three prior custom packages and
also requires restart/reboot validation. No vendor/recovery or account changes.

This is a development transaction script. The final image needs package
integration and first-boot/OTA checks; installing this on one phone does not
complete that work.

## Follow-up on the same day

Experiment 054 resolves Recents through the exact already merged upstream
Lomiri revert, packaged with the existing reopening backport. Native ARM64
build/install/full reboot pass. The user confirms correct previews and three
Terminal/Settings close/reopens each; a private screenshot agrees, with zero
shell restarts. A later power-menu Restart with those apps completes a real
kernel reboot, unlike the earlier SIGSEGV. The original four-app combination
still needs repetition; this does not attribute the successful reboot to a
specific change or establish that all Restart paths are fixed.
