# 055 — Restart crash in synchronous window closure

10 October 2026. Reproduced on the installed a50state.3 / official QtMir ac3ee9
packages. Shared candidate prepared; regression, package build and hardware
validation remain pending.

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
patch. Candidate version ends in +a50state.4. Build/install/reboot and repeated
four-app menu Restart tests remain pending; no candidate has been installed yet.
Recovery, OTA, clean image and wider lifecycle checks remain release gates.
