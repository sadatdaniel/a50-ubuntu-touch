# Getting onto UBports' update channels

**Short answer: yes, you register — but registration is the last step, not the
first.** A device gets an entry on `system-image.ubports.com` when its port is
adopted as a UBports community port. Until then Settings → Updates has nothing
to ask for, which is why it finds nothing today.

Checked 2026-09-08: `a50` returns 404 in every channel on the server. The
26.04-1.x daily channel currently carries FP5, Q25, Spacewar, algiz, ansuz,
caiman, eqe, jingpad_a1, mimameid_h12, mimir, r1, salami, tegu, vidofnir_esim,
yggdrasil and yggdrasilx. Getting `a50` into that list is what this file is
about.

## The path, in order

1. **Score the port against UBports' own device checklist.** It is one file,
   [`DeviceChecklist.md`](https://gitlab.com/ubports/porting/community-ports/general/-/blob/master/DeviceChecklist.md),
   in `ubports/porting/community-ports/general`. It exists so porters can
   "inform users in detail about their progress, as well as track their
   readiness for being added as a community or core device", and it asks for
   the results under three headings — **Working**, **Working with additional
   steps**, **Not working**. Our current score is below.
2. **Finish the porting guide's finalization step.** Two hard pieces, both of
   which this port has deliberately skipped: a working **UBports recovery**,
   and moving the rootfs **off userdata onto the system partition**. See the
   blockers — the second does not currently fit.
3. **Move the port under `ubports/porting/community-ports/`.** Ports live in
   subgroups by Android base; ours would be
   `community-ports/android11/samsung-galaxy-a50`, beside the existing
   `samsung-galaxy-s7`, `samsung-galaxy-note-10-plus`, `samsung-galaxy-tab-a8`
   and `samsung-galaxy-z-fold3`. The layout this repository already uses -
   `deviceinfo`, `overlay/system/`, a four-line `build.sh`, the shared
   `gsi-port-ci.yml` - is what those repos look like, so this is a move, not a
   rewrite.
4. **Ask for device registration.** Open an issue on
   [`community-ports/general`](https://gitlab.com/ubports/porting/community-ports/general/-/issues)
   with the codename and the checklist results. That is the documented route:
   the guide's own installer page says that for Halium 9 and newer "exact steps
   are not available at this time" and to get in touch with the community, so
   the issue **is** the process.
5. **Then the plumbing follows** - a channel entry on the system-image server,
   CI publishing into it, and an entry in
   [`ubports/installer-configs`](https://github.com/ubports/installer-configs)
   so the UBports Installer can flash the device by name. Only after that does
   Settings → Updates do anything.

## Where this port stands against the checklist

Scored against `DeviceChecklist.md`, in its own three headings. Anything never
tested is listed as **Not working**, because the checklist is a claim about
what has been confirmed, not about what probably works.

### Working

* Cellular: Carrier info, signal strength
* Cellular: Data connection
* Cellular: Incoming, outgoing calls
* Cellular: SMS in, out
* GPU: Boot into Spinner animation and Lomiri UI
* Bluetooth: Driver loaded at startup
* Bluetooth: Pairing with headset works, volume control ok
* Sensors: GPS
* Sensors: Rotation works in Lomiri
* Sensors: Touchscreen registers input across whole surface
* Sound: Loudspeaker, volume control ok
* USB: ADB access
* USB: MTP access
* WiFi: Driver loaded at startup
* WiFi: Enable/disable and flightmode works
* Actors: Manual brightness
* Misc: Anbox patches applied to kernel
* Misc: Online charging

### Working with additional steps

* Cellular: PIN unlock - the removal dialog rejects a correct PIN. A known
  UBports 26.04 regression, not a device fault. [011](experiments/011-settings-quirks.md)
* Camera: Photo, Video - **only inside Waydroid**, which uses Android's
  Camera2 and never touches Qt. [014](experiments/014-camera.md)

### Not working

* **Misc: AppArmor patches applied to kernel** - see blockers
* **Misc: Recovery image builds and works** - never built
* Camera: Photo / Video / Switch cameras / Flashlight - an upstream
  `qtubuntu-camera` gap. [014](experiments/014-camera.md)
* Sensors: Fingerprint reader - Samsung's trustlet never brings the sensor out
  of reset. [012](experiments/012-fingerprint.md)
* Sound: Earphones detected - untested
* Sound: Microphone, recording works - untested on this port
* Sound: System sounds and effects - untested
* Bluetooth: Enable/disable and flightmode - untested
* Bluetooth: Persistent MAC address between reboots - untested
* Cellular: MMS in, out - untested
* Cellular: Change audio routings (speakerphone, earphone) - untested
* Cellular: Switch 2G/3G/4G, preferred SIM - untested
* Cellular: Voice in calls over Bluetooth (HFP) - untested
* Actors: Notification LED, Torchlight, Vibration - untested
* Sensors: Automatic brightness - untested
* Sensors: Proximity works during a phone call - untested
* GPU: Hardware video decoding - untested
* WiFi: Hotspot, Persistent MAC address - untested
* Endurance: battery > 24 h, no reboot needed for 1 week - untested
* Misc: Offline charging, Factory reset, Shutdown/Reboot, Date and time after
  reboot, SD card, logcat/dmesg not spamming errors - untested
* Network: NFC - untested
* USB: External monitor - untested

That third list is long, and **most of it is untested rather than broken**.
Working through it is cheap and is the highest-value thing to do next for
upstreaming - far cheaper than either blocker below.

## The two real blockers

### 1. AppArmor

The checklist names it explicitly, and Ubuntu Touch confines apps with it. This
port has none: the one kernel built with it as the default LSM **did not boot**,
failing before USB enumeration. Two services currently run with their AppArmor
caller checks bypassed to work around its absence
(`lomiri-location-service`, `biometryd`), and both drop-ins say to delete them
once a kernel with AppArmor boots.

There is an open issue titled "Missing AppArmor" on `community-ports/general`,
so this is a known class of problem; read it before the next attempt.

### 2. The rootfs has to move to the system partition, and does not fit

The finalization page is explicit:

> Previously, your port has had the rootfs and system image coexisting on the
> userdata partition. These need to be moved to the system partition in order
> to ensure a maximum of available space for user data.

This port keeps `rootfs.img` on userdata (`sda32`, 111 GB) and loop-mounts it.
Moving it means using `sda25` - and that is **5,557,452,800 bytes, 5.18 GiB**,
while the image this port ships is **6144 MiB**. It does not fit as built.

Measured earlier: the contents come to about 3.9 GB, so a system-partition
build would have roughly 1.2 GB of headroom instead of 2 GB. Workable, but a
real change that needs a boot test - `deviceinfo_system_partition_size` stops
being an arbitrary number and becomes a hard limit.

Building UBports recovery is the other half of the same step, and this port has
deliberately not done it: TWRP is well tested on this device and is currently
the only reliable way back.

## What to do first

By value per hour:

1. **Work through the untested checklist items.** Most need a phone and ten
   minutes each, and each one moves an entry from the third list to the first.
2. **Try AppArmor again**, informed by the upstream issue.
3. **Then** the system-partition and recovery work - the largest change, and
   the one that most wants the rest settled first.

Registration is step 4. Asking before the checklist is filled in mostly earns
the reply "fill in the checklist".
