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

> **Updated 2026-09-08** from a live session on the device. Items marked
> *(measured)* were proven in that session; the evidence is in the
> [session log](#what-was-measured-on-2026-09-08) at the end of this file.

### Working

* Cellular: Carrier info, signal strength *(measured: fraenk, MCC 262 MNC 01, strength 40)*
* Cellular: Data connection *(measured: rmnet4 10.154.122.208, APN internet.telekom; TLS to 1.1.1.1 in 0.14 s and DNS resolving with Wi-Fi switched off)*
* Cellular: Enable/disable mobile data and flightmode works *(measured: Modem.Online false deregisters, true re-registers)*
* Cellular: Switch connection speed between 2G/3G/4G *(measured: gsm/umts/lte/nr all settable and the registered technology follows - gsm gives edge, lte gives lte)*
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
* Misc: Online charging *(measured: charging, 60%)*
* Misc: Battery percentage *(measured)*
* Misc: Shutdown / Reboot *(measured: clean reboot, back in 70 s)*
* Misc: Date and time are correct after reboot *(measured: RTC correct)*
* Sound: Microphone, recording works *(measured: 90,880 samples, peak 8587, 98.8%% non-zero)*
* WiFi: Persistent MAC address between reboots *(measured)*
* Bluetooth: Persistent MAC address between reboots *(measured: DC:F7:56:3E:DA:8D)*
* Bluetooth: Enable/disable and flightmode works *(measured: rfkill block/unblock, hci0 DOWN then UP RUNNING)*

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
* Sound: System sounds and effects - untested
* Cellular: the remaining items need a person on the other end of a call or
  message. The SIM lives in **slot 2** (`/ril_1`); slot 1 is empty, so
  "switch preferred SIM" cannot be tested with one card
* Cellular: MMS in, out - untested
* Cellular: Change audio routings (speakerphone, earphone) - untested
* Cellular: Switch preferred SIM for calling and SMS - needs a second SIM
* Cellular: Voice in calls over Bluetooth (HFP) - untested
* Actors: Notification LED - **not present**: /sys/class/leds is empty *(measured)*
* Actors: Torchlight - no flash LED in sysfs; camera-HAL only, and the camera does not work in Lomiri *(measured)*
* Actors: Vibration - /sys/class/timed_output/vibrator exists *(measured)*; nobody has felt it buzz
* Sensors: Automatic brightness - an `auto_brightness` iio device exists *(measured)*; not confirmed in the UI
* Sensors: Proximity works during a phone call - a `proximity_sensor` iio device exists *(measured)*; needs a call
* GPU: Hardware video decoding - /dev/video10-12 present *(measured)*; no playback tested
* WiFi: Hotspot - the driver advertises AP mode *(measured)*, but no hotspot has been brought up and joined
* Endurance: battery > 24 h, no reboot needed for 1 week - untested
* Misc: SD card detection and access *(measured: /dev/mmcblk0p1, exFAT, 15 G, mounts, reads and writes)*
* Misc: logcat, dmesg and syslog do not spam errors - **fails**: 413 journal
  errors this boot and a SIGSEGV from
  android.hardware.graphics.composer.1-service at startup *(measured)*
* Misc: Offline charging, Factory reset - untested
* Network: NFC - **not present**: no nfc device nodes *(measured)*
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

---

## What was measured on 2026-09-08

A live session over SSH, after fixing USB (see the commit
"usb: fix USB being dead from boot"). Commands and results, so the claims above
can be re-checked rather than believed.

**Microphone.** Recorded 3 s from `source.primary-in` with `parec` and measured
the samples: 90,880 samples, peak amplitude 8587, 98.8% non-zero. Silence would
be all zeros. Works.

**MAC persistence.** Recorded both addresses, rebooted, compared:

| | before | after | |
|---|---|---|---|
| `wlan0` | `00:00:0f:01:d5:76` | same | persistent |
| `hci0` | `DC:F7:56:3E:DA:8D` | same | persistent |

The Wi-Fi MAC passes the checklist item but is worth a second look: `00:00:0f`
is not a Samsung OUI, so the driver is inventing an address rather than reading
one from EFS. Stable, but not the device's own.

**Bluetooth enable/disable.** `rfkill block bluetooth` → `Soft blocked: yes`;
`rfkill unblock` + `hciconfig hci0 up` → `UP RUNNING PSCAN`. Both directions.

**Clock after reboot.** RTC and system time both correct immediately after
boot, no network sync needed (`System clock synchronized: no`, NTP active).

**Sensors.** iio exposes `accelerometer_sensor`, `gyro_sensor`,
`geomagnetic_sensor`, `light_sensor`, `auto_brightness`, `proximity_sensor`,
plus Samsung's gesture devices. Present at driver level; not confirmed through
Lomiri.

**Wi-Fi AP mode.** `iw list` reports `AP` among supported interface modes, so a
hotspot is possible on this chipset.

**Not present at all.** `/sys/class/leds` is empty - no notification LED and no
flash LED - and there are no NFC device nodes.

**Cellular is blocked, not broken.** `org.ofono.SimManager` reports
`Present = false`; there is no SIM in the device. Both modems `/ril_0` and
`/ril_1` exist and are powered. Put a SIM in and the whole Cellular block
becomes testable in one pass.

### A false alarm worth writing down

The device shows a **load average around 16 while completely idle**, which
looks alarming and is not. 28 kernel threads sit permanently in `D`
(uninterruptible) state:

```
tz_worker_thread  x8      scsi_srpmb_work
tz_iwsock                 ree_time
simpleinteracti   x4      ...
```

These are Samsung's TrustZone workers waiting on the secure world. Linux counts
`D`-state tasks toward load average, so they inflate it permanently. `top`
shows 0.0% CPU across every process. Do not chase this.

### Still genuinely wrong

`android.hardware.graphics.composer@2.1-service` takes a **SIGSEGV at every
boot** and is restarted. The display works afterwards, so it has never been
urgent, but it is real and it is most of what makes the "no error spam"
checklist item fail.

## Cellular and storage, measured 2026-09-08

With a SIM and an SD card inserted.

**The SIM is in slot 2.** `/ril_1` has it (`Present = true`, IMSI `262012041705080`,
ICCID `894902…`); `/ril_0` is empty. Both modems exist and are powered, so the
port's dual-SIM configuration is right - there is simply one card. "Switch
preferred SIM" cannot be tested until there are two.

**Data carries real traffic.** The context is active on `rmnet4`
(`10.154.122.208/24`, APN `internet.telekom`). Proving that took two attempts
and the first one was wrong in an instructive way:

* Binding a socket to the cellular source address and connecting **timed out**,
  which looked like broken data. It was a broken test. The routing table has
  `default via … dev swlan0 metric 600` and `default via … dev rmnet4 metric
  700`, so Wi-Fi wins; the packets left over Wi-Fi carrying a cellular source
  address and were dropped. Binding a source address does not choose a route.
* With `nmcli radio wifi off`, `ip route get 1.1.1.1` goes via `rmnet4`, and
  TLS to 1.1.1.1 completes in 0.14 s, 8.8.8.8:53 in 0.02 s, and DNS resolves.

**Technology switching works, and the radio follows.** Setting
`RadioSettings.TechnologyPreference` and reading back both the preference and
the registered technology:

| set | preference | registered on |
|---|---|---|
| `gsm` | gsm | `edge` |
| `umts` | umts | `edge` |
| `lte` | lte | `lte` |
| `nr` | nr | `lte` |

`umts` landing on EDGE is the network, not the port - Telekom Germany
switched 3G off in 2021. `nr` landing on LTE is coverage.

**Flight mode works.** `Modem.SetProperty Online false` deregisters
(`Status` empties), `true` re-registers.

**SD card works.** `/dev/mmcblk0p1`, exFAT, label `16GB`, 15 G with 3.2 G free.
Mounts, lists content, and a write-then-read-back test succeeds.

### Two testing traps this session

Both produced a confident wrong answer, so they are worth writing down.

* **`dbus-send` without `--print-reply` swallows errors.** Every ofono
  `SetProperty` looked like a no-op until the flag was added, at which point
  they all returned `method return` - they had been working the whole time.
* **A readback is part of the test.** The first switching run reported the
  preference never changing; the parser was mangled by shell quoting, not the
  setter. When a set appears to do nothing, verify the reader before blaming
  the writer.
