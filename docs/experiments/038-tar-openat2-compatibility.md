# 038 — Ubuntu 26.04 tar and old-kernel compatibility

Status: fresh-phone failure reproduced; existing Ubuntu report identified;
the current-source rebuild passed 222 upstream tests, the CI ENOSYS reproducer,
and a nested archive round trip on the real 4.14 kernel. The candidate is staged
privately; installed system packages remain intact.
No older package, global sandbox change or kernel change has been installed.

The clean image has tar 1.35+dfsg-4ubuntu0.4 and glibc 2.43-2ubuntu2.4.
Extracting a verified experimental .deb with dpkg-deb fails at nested
directories with ENOSYS. Direct mkdir succeeds on the same writable
filesystem; the shell reports Seccomp 0. This is distinct from the QtMir
display regression in experiment 037 and from a full filesystem.

The original [Ubuntu bug 2166326](https://bugs.launchpad.net/bugs/2166326)
is confirmed and describes exactly this regression. glibc 2.43 provides
openat2, so configure detects it and omits gnulib's replacement. The libc
wrapper cannot fall back when kernel 4.14 lacks the syscall. An
[upstream bug discussion](https://www.mail-archive.com/ubuntu-bugs%40lists.ubuntu.com/msg6313453.html)
identifies the existing runtime fallback in gnu/openat2.c and the configure
check in m4/openat2.m4 that disables it. Flat paths may succeed while nested
archive paths fail. Package operations must be validated before release.

Candidate: rebuild the current signed Ubuntu 26.04 source, with
ac_cv_func_openat2=no so the existing gnulib implementation is compiled.
The first build exposed an incomplete backport: openat2's declaration passes
four arguments to tar 1.35's three-argument gnulib macro. Joining its parameter
list and nonnull attributes restores that existing macro convention; all
upstream security patches remain applied. The candidate also carries this
one-line declaration correction.
Use the normal Debian package build and its upstream tests. Also run one
archive create/extract test with openat2 forced to ENOSYS in that test process
only; the original tar must fail and the candidate must preserve the nested
file. The test uses libseccomp on the isolated GitHub runner and does not
alter phone confinement or disable syscall protection globally.

Reproduction is in scripts/experiments/build-tar-openat2-package.sh and
test-tar-openat2-fallback.c. The manually triggered native Ubuntu 26.04 ARM64
workflow accepts component=tar; no emulation or large local build download is
needed. Source, configuration, dependency manifest and package checksums are
recorded with the experimental artifact. The [corrected remote build](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/37124633502)
passed. On the phone, the installed tar exits 2 on nested archive creation;
the candidate exits 0, extracts the nested path and preserves the fixture.
Run scripts/experiments/check-tar-archive.sh with the installed or candidate
executable to reproduce this comparison without touching existing data.
Command-local PATH pointing to the private candidate also lets normal
dpkg-deb extraction of the verified QtMir package succeed; the resulting
library matches its verified runtime copy. This provides a bootstrap for normal
package installation without a global PATH change. A normal package installation
and repeat-boot check remain required.
Prefer an official fixed build once
the archive provides it.

For the initial QtMir library experiment only, the verified .deb was extracted
on the computer with its native archive tool, and the library was copied into
a private user directory. Installed packages remain intact. This diagnostic
staging is not a substitute for resolving tar before normal installation,
Libertine, updates or a public ROM.

## Installed package checkpoint

The current security source rebuild is now installed as
`1.35+dfsg-4ubuntu0.4+a50openat2.1`. The offline dependency repair completed
using normal package extraction, and the next boot has a read-only root and
clean dpkg audit. Earlier candidate-only statements above are historical.
Libertine and OTA still require their own functional tests.
