# 038 — Ubuntu 26.04 tar and old-kernel compatibility

Status: fresh-phone extraction failure reproduced; existing Ubuntu report
identified; a rebuild retaining GNU tar's existing fallback is being tested.
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
Use the normal Debian package build and its upstream tests. Also run one
archive create/extract test with openat2 forced to ENOSYS in that test process
only; the original tar must fail and the candidate must preserve the nested
file. The test uses libseccomp on the isolated GitHub runner and does not
alter phone confinement or disable syscall protection globally.

Reproduction is in scripts/experiments/build-tar-openat2-package.sh and
test-tar-openat2-fallback.c. The manually triggered native Ubuntu 26.04 ARM64
workflow accepts component=tar; no emulation or large local build download is
needed. Source, configuration, dependency manifest and package checksums are
recorded with the experimental artifact. Hardware validation and a normal
package installation remain required. Prefer an official fixed build once
the archive provides it.

For the initial QtMir library experiment only, the verified .deb was extracted
on the computer with its native archive tool, and the library was copied into
a private user directory. Installed packages remain intact. This diagnostic
staging is not a substitute for resolving tar before normal installation,
Libertine, updates or a public ROM.
