# Experiment 008 — Bluetooth, and why "CONFIG_BT bootloops this device" was wrong

**Date:** 2026-09-05 · **Status:** ✅ resolved — `hci0` is up and
`bluetoothctl` discovers real nearby devices · **Device needed:** yes

## TL;DR

Bluetooth was parked since 2026-08-31 as "enabling `CONFIG_BT` bootloops the
device", with an Android-init fatal error named as the leading hypothesis.
**That diagnosis was wrong.** The kernel boots fine with `CONFIG_BT`. What
happens is that `bluebinder` starts, opens an `AF_BLUETOOTH` socket, and
**panics the kernel** — every boot, which looks identical to a bootloop.

The panic is a `BUG_ON` reached because this vendor tree has commented out the
entire Linux HCI socket layer:

```
kernel BUG at net/bluetooth/af_bluetooth.c:71!
pc : bt_sock_create+0x190/0x1a0
Kernel panic - not syncing: Fatal exception
```

Three changes were needed, all in the kernel:

1. `CONFIG_BT` + `CONFIG_BT_HCIVHCI` (the parked patch) — gives `/dev/vhci`.
2. Restore the commented-out HCI socket layer in `net/bluetooth/hci_sock.c`.
3. `CONFIG_RFKILL` — `bluebinder` needs `/dev/rfkill`.

## 1. It was never a bootloop in the kernel sense

Booting the `CONFIG_BT` kernel with `bluebinder` masked gives a completely
stable system: `/dev/vhci` present, lightdm `NRestarts=0`, audio still working,
uptime climbing. The kernel is fine.

Unmask `bluebinder` and every boot panics. So the 2026-08-31 result was real,
but the cause was one userspace process touching a broken kernel path — not
Android init, and not the kernel failing to come up.

Capturing the panic needed the same trick as the audio work: mask the offender
so the device stays up, then trigger it deliberately and read `/proc/last_kmsg`
after the reboot.

## 2. The vendor tree has gutted the HCI socket layer

`net/bluetooth/hci_sock.c` has roughly a third of its 2077 lines wrapped in
`/* ... */`, with each gutted function left returning 0:

| commented block | what it removes |
|---|---|
| 86–113 | `hci_sock_gen_cookie`, `hci_sock_free_cookie` |
| 477–573 | `create_monitor_ctrl_open` / `_close` |
| 600–694 | `hci_send_monitor_ctrl_event`, `send_monitor_replay`, `send_monitor_control_replay` |
| 820–881 | `hci_sock_release` body |
| 884–962 | `hci_sock_blacklist_add` / `_del`, `hci_sock_bound_ioctl` |
| 966–1056 | `hci_sock_ioctl` body |
| 1063–1343 | `hci_sock_bind` body |
| 1350–1377 | `hci_sock_getname` body |
| 2006–2030 | `hci_sock_create` body |

plus `// static DEFINE_IDA(sock_cookie_ida);`.

`hci_sock_create()` is the fatal one:

```c
static int hci_sock_create(struct net *net, struct socket *sock, int protocol,
			   int kern)
{
    /*
	struct sock *sk;
	...
	sk = sk_alloc(net, PF_BLUETOOTH, GFP_ATOMIC, &hci_sk_proto, kern);
	...
	sock_init_data(sock, sk);
	...
    */
	return 0;
}
```

It returns success without ever allocating a sock, so `sock->sk` stays NULL.
`bt_sock_create()` then does

```c
	if (!err)
		bt_sock_reclassify_lock(sock->sk, proto);
```

and `bt_sock_reclassify_lock()` opens with `BUG_ON(!sk)` — af_bluetooth.c line
71, exactly what the panic names.

Android never notices: it drives Bluetooth entirely through the HAL and never
opens an `AF_BLUETOOTH` socket. A GNU/Linux userspace does — BlueZ opens HCI
sockets, and `bluebinder` proxies HCI from the Android HAL into the Linux stack
through `/dev/vhci`.

Restoring is mechanical: delete only the comment delimiters. The stub
`return 0;` after each is left alone — for `create` and `release` it is the
correct ending, and for `ioctl`/`bind`/`getname` it becomes unreachable after
the restored `return err;`. Patch:
a50-halium `kernel/patches-experimental/bluetooth-hci-sock-restore.patch`.

Only one symbol was missing afterwards, `sock_cookie_ida`, commented with `//`
rather than `/* */`.

## 3. `CONFIG_RFKILL` — needed, but not for the documented reason

With the socket layer restored, `bluebinder` got further and then failed:

```
bluebinder: Connected to HIDL bluetooth service
bluebinder: Failed to open /dev/rfkill 2: No such file or directory
bluebinder: g_io_channel_shutdown: assertion 'channel != NULL' failed
systemd: bluebinder.service: Failed with result 'protocol'.
```

Experiment 006 wanted `CONFIG_RFKILL` for the **Wi-Fi indicator**. That claim
is false and was falsified directly: Wi-Fi connects and lists networks with no
`/dev/rfkill` at all and `urfkilld` inactive. `bluebinder` is what actually
needs it.

## 4. Result

```
hci0:	Type: Primary  Bus: Virtual
	BD Address: DC:F7:56:3E:DA:8D  ACL MTU: 1021:20  SCO MTU: 0:0
	UP RUNNING
```

Earbuds pair and play audio over A2DP, confirmed on the device. A scan finds
real devices with live RSSI:

```
[NEW] Device 60:98:66:FF:B6:D1 AM405X
[CHG] Device 1C:17:91:BD:26:C1 RSSI: -66
[CHG] Controller DC:F7:56:3E:DA:8D Discoverable: yes
```

No bootloop. Audio and telephony still work on the same kernel — verified
after the flash: `calliope_version = rSK1`, `/dev/hwbinder` open in
PulseAudio, ofono `Status = registered`, lightdm `NRestarts=0`.

## 5. Still open

* **Pairing and A2DP work** — real earbuds paired and played audio, confirmed
  by the user. HFP (calls over Bluetooth) is still untested.
* `/dev/vhci` is `0600 root:root`. `bluebinder` runs as root so it works, but
  that is worth checking against the same class of bug as the `/dev/hwbinder`
  `0600` greeter blocker in experiment 006.
