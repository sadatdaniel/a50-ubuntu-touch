# Resume prompt

Paste this into a fresh session to bring it fully up to date.

---

Continue the Samsung A50 Ubuntu Touch port. Read these first, in order:

```
C:\Users\sadat\Development\a50-ubuntu-touch\docs\SESSION-HANDOFF-03.md
C:\Users\sadat\Development\a50-ubuntu-touch\docs\status.md
C:\Users\sadat\Development\a50-ubuntu-touch\REPRODUCE.md
```

Handoff 03 supersedes 02 and 01 (both kept for history). Read the experiment
doc for whatever you touch: 009 GPS, 010 Morph, 011 settings, 012 fingerprint,
013 Waydroid, 014 camera.

**State:** audio, Bluetooth (incl. A2DP), calls, mobile data, Wi-Fi, GPS and
Waydroid (Android 13, F-Droid installed) all work and survive reboots.
Everything is committed and pushed to `github.com/sadatdaniel/a50-halium` and
`github.com/sadatdaniel/a50-ubuntu-touch`.

**The running kernel is NOT the published release.** It is `90c281f8…`
(`/userdata/boot-known-good-waydroid.img`), carrying two boot-tested patches:
`decon-force-mask-layer` (fingerprint HBM, defaults off) and the `anbox-*`
binder devices (Waydroid). The older `53fe13b5…` is staged at
`/userdata/boot-known-good.img`. **The built kernel exists only on the device
and this machine — there is no release for it yet.**

**Open, with root causes already established — do not re-derive:**
* **Camera** — hardware, kernel driver, Samsung HAL and libhybris all work (16
  preview sizes readable from UT). The fault is upstream: `qtubuntu-camera`
  0.5.1 implements only the legacy `QCameraViewfinderSettingsControl`, while Qt
  5.15 needs `ViewfinderSettingsControl2`, so Qt returns an empty resolution
  list → `QSize(-1,-1)` → SIGSEGV. Waydroid's camera works because it uses
  Android's Camera2 and never touches Qt. The old "camera panics the kernel"
  hazard **does not reproduce**.
* **Fingerprint** — HBM is solved by the kernel patch. **Illumination is
  settled, do not re-test.** No DRDY interrupt is ever registered because the
  HAL never issues `INT_TRIGGER_INIT`; the blocker is sensor bring-up in
  Samsung's trustlet. Lead: no calibration data under `/mnt/vendor/efs`.
* **AppArmor** — unbuilt; the one attempt did not boot. Not blocking anything.

**Waydroid policy (deliberate, user's decision):** only the `Waydroid` launcher
icon is shown; all per-app entries are hidden, because Waydroid exposes one
Android surface and a second app steals it from the first. Launch apps from
inside Android.

**Suggested next:** cut a release (highest value — the kernel is unpublished),
then report the qtubuntu-camera gap upstream, then the fingerprint EFS lead.
Untested: Bluetooth HFP, headphone/earpiece audio.

**Working agreements:** search for the known fix before improvising; read the
source that is actually installed, not upstream master; verify, never assume
("returned 0" ≠ "worked"); an absent log line is not evidence; one variable at
a time; stage a known-good boot image before flashing; never poll hardware
mixers; keep chat replies short and do the work in the tools.

**Traps that have already cost hours (handoff 03 §4):** `pkill -f` kills your
own ssh session — use `pkill -x`; logcat is UTC while the device is CEST;
`strings` cannot see kernel module params, verify with `System.map` plus a
known-good control symbol; the kernel tree cannot be checked out on Windows
(`aux.c`) — build with the source on a Docker volume, pre-cloned; apt needs
`-o APT::Sandbox::User=root`; decon only evaluates the HBM mask layer on a new
frame.

**Device:** SSH `plink -ssh -batch -pw 1234 root@10.15.19.82`, hostkey
`SHA256:BPpKdQdHCDAeDLdNFhWAXWN5Pfqxr9zNUb2gAiLk++4`, prefix
`MSYS_NO_PATHCONV=1` from Git Bash. Flash from running Linux to `/dev/sda14` —
no TWRP needed. Windows loses the static IP when the phone re-enumerates; re-add
from an elevated shell if ping fails.
