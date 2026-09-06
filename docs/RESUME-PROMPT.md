# Resume prompt

Paste this into a fresh session to bring it fully up to date.

---

Continue the Samsung A50 Ubuntu Touch port. Read these first, in order:

```
C:\Users\sadat\Development\a50-ubuntu-touch\docs\SESSION-HANDOFF-04.md
C:\Users\sadat\Development\a50-ubuntu-touch\docs\status.md
C:\Users\sadat\Development\a50-ubuntu-touch\docs\RELEASING.md
```

Handoff 04 supersedes 03, 02 and 01 (all kept for history). Read the experiment
doc for whatever you touch: 009 GPS, 010 Morph, 011 settings, 012 fingerprint,
013 Waydroid, 014 camera.

**State:** audio, Bluetooth (incl. A2DP), calls, mobile data, Wi-Fi, GPS and
Waydroid (Android 13, F-Droid installed) all work and survive reboots.
Everything is committed and pushed to `github.com/sadatdaniel/a50-halium` and
`github.com/sadatdaniel/a50-ubuntu-touch`.

**There is now an installer, and it is UNTESTED on hardware.** Release
`installer-2026-09-06` is a single recovery-flashable zip
(`ubuntu-touch-a50-26.04-1.x-2026-09-06.zip`, 1.32 GB, sha `35e835e0…`) that
writes the boot partition and a 6144M rootfs. The release also ships a
`-devel-` zip (sha `80ade5e9…`) - the same port with sshd on, root's password
`1234`, usb-tethering on and `ADBD_SECURE=0`, so a tester can attach a journal
to a bug report. Its boot image is `90c281f8…`,
byte-for-byte the kernel the device is running. Its rootfs has been mounted and
checked file by file, and the installer has been run against loop devices under
`busybox sh` — but **nobody has flashed the zip in TWRP on a phone and booted
it**. Do not claim otherwise anywhere.

**The next task is that test.** Handoff 04 §0 has the cheap reversible version:
copy the new `rootfs.img` to `/userdata`, swap it with the current one, reboot.
It needs no TWRP and no boot-partition change. Recovery if it fails is the
initramfs telnet shell on 192.168.2.15 over USB, then TWRP (Volume Up + Power
from powered off). **Use the `-devel-` rootfs for the test**: the normal one is
the published UBports image with SSH off, so a successful boot would still need
the wizard finished on the phone before you could log in. The debug one answers
on `ssh root@10.15.19.82`, password `1234`, as soon as it is up.

**The running kernel is the published one now.** `90c281f8…`
(`/userdata/boot-known-good-waydroid.img`) is what release
`gps-waydroid-2026-09-05` ships and what is inside the installer zip. The older
`53fe13b5…` is staged at `/userdata/boot-known-good.img`.

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
* **The tools-built kernel has never been boot-tested.** That is why releases
  come from a50-halium and the GitLab CI is a compile check. Largest open task
  after the install test.

**Waydroid policy (deliberate, user's decision):** only the `Waydroid` launcher
icon is shown; all per-app entries are hidden, because Waydroid exposes one
Android surface and a second app steals it from the first. Launch apps from
inside Android.

**Working agreements:** search for the known fix before improvising; read the
source that is actually installed, not upstream master; verify, never assume
("returned 0" ≠ "worked"); an absent log line is not evidence; one variable at
a time; stage a known-good boot image before flashing; never poll hardware
mixers; keep chat replies short and do the work in the tools.

**Traps that have already cost hours** — handoff 04 §4 and handoff 03 §4:
`pkill -f` kills your own ssh session, use `pkill -x`; logcat is UTC while the
device is CEST; `strings` cannot see kernel module params, verify with
`System.map` plus a known-good control symbol; the kernel tree cannot be
checked out on Windows (`aux.c`) — build with the source on a Docker volume;
apt needs `-o APT::Sandbox::User=root`; decon only evaluates the HBM mask layer
on a new frame; do not mount a build image under a container's `/tmp`;
`ldconfig -r` cannot work cross-architecture.

**Disk:** this machine has sat at 95% (17-18 GB free). Docker container
`ut-build-env` holds 19.8 GB, ~15 GB of it three superseded scratch trees.
Check `df -h /c` before committing to a build.

**Device:** SSH `plink -ssh -batch -pw 1234 root@10.15.19.82`, hostkey
`SHA256:BPpKdQdHCDAeDLdNFhWAXWN5Pfqxr9zNUb2gAiLk++4`, prefix
`MSYS_NO_PATHCONV=1` from Git Bash. Flash from running Linux to `/dev/sda14` —
no TWRP needed. Windows loses the static IP when the phone re-enumerates; re-add
from an elevated shell if ping fails.
