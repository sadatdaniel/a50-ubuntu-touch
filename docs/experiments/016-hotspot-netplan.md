# Experiment 016 — Wi-Fi hotspot: a missing netplan helper, not a device bug

**Date:** 2026-09-08 · **Status:** ✅ fixed and verified on the device
· **Device needed:** yes

## Symptom

The hotspot toggle in the UI does nothing. The indicator says:

```
lomiri-indicator-network-service: Could not find a hotspot setup to enable
```

and doing it by hand fails too:

```
$ nmcli device wifi hotspot ifname wlan0 ...
Error: Failed to setup a Wi-Fi hotspot: failure adding connection:
       settings plugin does not support adding connections
```

## The first message is a decoy

That error names the `ifupdown` settings plugin, which genuinely cannot write
connections. It is the obvious thing to blame, and blaming it is wrong.

`/etc/NetworkManager/NetworkManager.conf` ships stock Ubuntu's
`plugins=ifupdown,keyfile`. Setting it to `plugins=keyfile` alone and restarting
NetworkManager changes the error to a **different** one:

```
Error: Failed to add 'x' connection: failure adding connection: netplan generate failed
```

So NM asks the netplan-backed keyfile plugin first, that one fails, NM falls
through to `ifupdown`, and it is *ifupdown's* refusal that reaches the user.
The first message was masking the real failure, not describing it.

**This matters for what gets shipped.** Editing `NetworkManager.conf` looks like
a fix — the error changes, and if you stop there you ship it. It is not a fix.
Once the real cause below is fixed, the **stock** `plugins=ifupdown,keyfile`
works unchanged; that was re-tested by restoring the stock file and adding a
connection successfully. Nothing in this port touches `NetworkManager.conf`.

## Not specific to the hotspot either

```
$ nmcli connection add type ethernet ifname a50eth con-name t   -> netplan generate failed
$ nmcli connection add type wifi     ifname wlan0  con-name t   -> netplan generate failed
$ nmcli connection add type wifi ... 802-11-wireless.mode ap    -> netplan generate failed
```

Every connection add failed, for every type. (An early test used `type dummy`,
which netplan has no device type for — a confound. The three above are all types
netplan does support, so the conclusion rests on them, not on `dummy`.)

## The real cause

`netplan generate` run by hand exits 0. So the failure is in *how* NM invokes
it. NM spawns it with stderr discarded, so nothing reaches the journal. `strace`
on the NM process during an add:

```
[pid 20655] execve("/usr/libexec/netplan/configure",
                   ["/usr/libexec/netplan/configure", "--networkmanager-only"],
                   0x558887bbb0 /* 7 vars */) = -1 ENOENT (No such file or directory)
```

The file does not exist, and no installed package ships it:

```
$ dpkg -S /usr/libexec/netplan/configure
dpkg-query: no path found matching pattern /usr/libexec/netplan/configure
$ ls /usr/libexec/netplan/
generate  netplan-dbus
```

This is a **version skew in the UBports 26.04 archive**, not anything to do with
this device:

| package | version |
|---|---|
| `network-manager` | 1.54.3-2ubuntu3ubports1 |
| `netplan.io`, `netplan-generator` | **1.1.2**-8ubuntu1 |

netplan **1.2** split the single `generate` stage into
`/usr/libexec/netplan/generate` + `netplan-configure.service`, for
systemd-generator compatibility. NM 1.54.3 is built against that split and calls
the `configure` helper on every write. netplan 1.1.2 still does all of that work
inside `generate`, so the helper is simply absent — and NM reports the resulting
`ENOENT` as the misleading string `netplan generate failed`.

`apt policy` offers nothing newer than 1.1.2, so there is no package to upgrade
to. Any device on this rootfs has this bug.

## The fix

`overlay/system/usr/libexec/netplan/configure` — a shim that forwards to
`generate`. `generate` rejects flags it does not know (`--networkmanager-only`
gives `failed to parse options`), so the shim drops unknown flags and passes
through only `--root-dir`.

netplan 1.1.2's `generate` already writes
`/run/NetworkManager/system-connections/*.nmconnection`, which is exactly what
`configure --networkmanager-only` exists to produce in 1.2 — the work only moved
between stages. That is why forwarding is sufficient rather than a guess.

The shim is self-deleting in intent, not in code: it should be removed when
netplan ≥ 1.2 reaches the archive, and its header says so.

## Verified

With the shim installed and `NetworkManager.conf` **stock**:

```
$ nmcli device wifi hotspot ifname wlan0 con-name a50-hotspot ssid A50Hotspot password ...
Device 'wlan0' successfully activated

$ iw dev wlan0 info      -> type AP, ssid A50Hotspot
$ ip -4 addr show wlan0  -> 10.42.0.1/24
   dnsmasq --listen-address=10.42.0.1 --dhcp-range=10.42.0.10,10.42.0.254,3600
   iptables -t nat: -A POSTROUTING -s 10.42.0.0/24 ! -d 10.42.0.0/24 -j MASQUERADE
```

and a second phone associated and got an address. Upstream routing was checked
too, because there are two default routes and the lower-metric one is dead:

```
default via 192.168.179.1 dev swlan0 metric 600 linkdown
default via 10.156.195.1  dev rmnet4 metric 700

$ ip route get 1.1.1.1 from 10.42.0.10 iif wlan0
1.1.1.1 from 10.42.0.10 via 10.156.195.1 dev rmnet4
```

Forwarded client traffic correctly takes cellular and steps over the dead route.

## Side effect worth knowing

A failed add still leaves its YAML behind: NM writes
`/etc/netplan/90-NM-<uuid>.yaml` *before* calling netplan and does not roll it
back. Nine orphans had accumulated. They are harmless but confusing — clean them
by comparing against `nmcli -g UUID connection show` and deleting only files
whose UUID NM does not know.

## What this does not prove

The UI toggle path was verified only as far as `nmcli`; the indicator's own
hotspot setup was not exercised end to end. Hotspot behaviour with cellular data
*off*, and client throughput, were not measured.

## Upstream

Worth reporting to UBports: `network-manager` 1.54.3 in the 26.04 archive needs
`netplan.io` ≥ 1.2, and the archive has 1.1.2. It breaks every connection add on
every device, not just the hotspot.
