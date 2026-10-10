# 055 — Restart crash in synchronous window closure

10 October 2026. Reproduced on the installed a50state.3 / official QtMir ac3ee9
packages. Shared regression, native package build, installation and full
reboot persistence pass. Two original four-app power-menu tests now complete
real kernel reboots, including a repeat without the debugger.

## Evidence

Recents rendering and repeated Terminal/Settings reopening pass after a full
reboot (054). A power-menu Restart with those two apps also completed a real
kernel reboot. Repeating with Gallery, OpenStore, Morph and YouTube instead
crashes Lomiri and reloads the interface; the kernel boot ID does not change.
The journal records SIGSEGV and automatic shell restart. Thus the successful
two-app test does not close this defect.

The first four-minute debugger expired before the later user test. The next
trace stopped on normal XWayland SIGUSR1 while opening a browser; this was not
the crash. A corrected, bounded trace passes SIGUSR1/SIGUSR2/SIGPIPE and captures
SIGBUS on the main Lomiri thread during the same power-menu reproduction:

1. QObjectPrivate::maybeSignalConnected
2. Qt signal dispatch
3. TopLevelWindowModel::closeAllWindows
4. TopLevelWindowModel::qt_metacall, QML invocation and mouse release

The debugger detached and the shell recovered normally. Extracted signed native
GDB tools were used from userdata; no installed debugging packages, persistent
core-dump policy or authentication changes. Raw stacks and logs remain private.

## Upstream review and candidate

The exact installed source is fe38aa78f3b1c69319ba914c3d48f78543b8e186. Its
closeAllWindows loops directly over m_windowModel and calls Window::close.
The closeRequested path can synchronously remove model entries and delete
windows, invalidating that iteration. The function also enables completion
signals during the loop; synchronous last-window removal can emit completion
before the loop returns and then again in the final empty-model check.

Current upstream main was inspected and still has that same function. Searches
found similar historical closure/Restart symptoms in [postmarketOS's own
tracker](https://gitlab.com/postmarketOS/pmaports/-/issues/2393), but no matching
upstream correction was identified. Do not present this candidate as an existing
upstream backport or the historical issue as proof of the same cause.

The candidate snapshots the model's existing stable window IDs and uses its
existing indexForId lookup immediately before each close. Removed windows are
skipped without retaining raw object references. Completion is enabled after
the synchronous loop, preserving ordinary asynchronous last-window completion.
This changes the shared close-all path used by Restart, power-off and logout;
it is not an A50 reboot shortcut or a bypass of normal shutdown/authentication.

check-close-all-windows.py compiles the actual function body from the selected
source with Qt Core and AddressSanitizer. Fixtures exercise an empty model,
normal asynchronous closure, synchronous self/sibling deletion, and a window
created during closure. The upstream source must fail with heap-use-after-free;
the corrected source must pass before package compilation. This targeted harness
does not run the full upstream shell suite or replace device testing.

The existing native ARM64 workflow now accepts lomiri-restart. It uses the
same fe38aa source, official QtMir compatibility inputs, Recents correction and
window-state backport as the tested a50state.3 build, plus this narrow shared
patch. Candidate version ends in +a50state.4. Native build/install/reboot now pass as recorded below; repeated four-app
menu Restart tests remain pending.
Recovery, OTA, clean image and wider lifecycle checks remain release gates.

## Native build and normal package installation

Native ARM64 [run 38061616400](https://github.com/sadatdaniel/a50-ubuntu-touch/actions/runs/38061616400)
passes. The actual upstream closeAllWindows body reproduces an AddressSanitizer
heap-use-after-free during synchronous window removal. The patched function
passes all five cases. The existing WindowStateSaver regression also passes.
Full upstream tests remain disabled (nocheck). Earlier runs 38061291059 and
38061467557 stopped in regression setup before producing a package; exposed
diagnostics identified a missing QObject header for Q_EMIT in the extracted
fixture. The fixture now includes the normal Qt header.

All five build archives match SHA256SUMS. The guarded public
install-lomiri-restart.sh retains the exact a50state.3 rollback archives and
supports --rollback. Both the preliminary review and installer enforce an APT
plan of exactly lomiri, lomiri-common, lomiri-private and lomiri-greeter, with
zero additions/removals and zero installed-size growth. indicators-client is
not installed. Audit passes after installation.

A true system reboot retains all four a50state.4 versions. The installed
libwindowmanager-qml.so exactly matches the library inside the verified
lomiri-private archive, SHA256
2cb38ff5da0476fcee8331860d810eaffa54966f9eaf0eab43fc8fa864077944.
Root is read-only, AppArmor Y, no failed system units, Lomiri active with zero
automatic restarts, and the existing autosuspend startup unit is active with
Result=success. These are build/install/startup passes, not yet a successful
power-menu Restart reproduction. The corrected bounded trace is armed on the
candidate for the user hardware test.

Archive checksums:

| Package | SHA256 |
| --- | --- |
| lomiri | caf61879e94e8e423f280f21d74db7ffbf771218bb3917721e9ae5d538db3ed8 |
| lomiri-private | 364881f90b863a986a843fe61ab0b63d4b437936ee41f10b5036f9f2164dce67 |
| lomiri-common | af6f93c5bd856f6ee1e1cba6b59b56ea45bd3559aafc1cb1b2ea37503c0a5987 |
| lomiri-greeter | 23e47025554878f65cf83030818e443c00ba6919008b704e3b32400989fd7e3b |
| indicators-client (not installed) | 86ac43c1f145c428a560ece0361769e08ca8747e5ac7f120d6d12589994c7056 |

## Repeated four-app hardware validation

The user opened Gallery, OpenStore, Morph and YouTube and selected Restart
from the normal power menu twice. Both show the Samsung logo and change the
kernel boot ID: ff216042-8c36-4f78-8a03-a5b8e894af54 to
2ecc4dd3-1c39-418d-be77-e791478633f8, then to
ffb91172-1f4e-4bba-9135-e374b0a8f959. The second test has no debugger attached.
The first candidate trace ends with normal shutdown SIGTERM, without the
previous SIGBUS. The second prior-boot journal records systemd-logind's normal
reboot request, with no shell crash/automatic-restart entry. Shutdown-time
USB/polkit start jobs conflict with the queued shutdown transaction; these
messages do not prevent either reboot and are not concealed as a clean journal.

After each reboot the installed window-manager hash still matches the verified
archive, root is read-only, AppArmor is Y, audit is clean, no system units fail,
Lomiri has zero automatic restarts and automatic suspend startup succeeds.
This closes the reproduced four-app menu failure for this tested package.
Broader shutdown/logout coverage, clean-image incorporation, signed OTA and
soak checks remain; these two passes do not establish a stable ROM.
