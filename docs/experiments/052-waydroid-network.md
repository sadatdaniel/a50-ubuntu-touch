# Waydroid network comparison

4 October 2026, aa17, fresh official Android 13 VANILLA/HALIUM_11 images.
The user reports slow general browsing, F-Droid downloads near 100 KB/s, and
slow catalogue refresh/search. No DNS, MTU, firewall, proxy or mirror setting
was changed during diagnosis.

## Evidence

- Android Ethernet is validated, with an IPv4 address and default route through
  the normal Waydroid bridge. Bridge/interface counters show no errors/drops.
- Two capped 1,000,000-byte Cloudflare downloads inside Android took 0.515 and
  0.381 seconds, approximately 1.94 and 2.62 MB/s. This excludes a constant
  100 KB/s limit for every destination, not all networking problems.
- Three Android downloads from the F-Droid primary hostname reached
  `65.21.79.229` and averaged approximately 147–182 KB/s. The initial Ubuntu
  comparison reached an IPv6 server and was about 1.6–2.0 MB/s. Those different
  peers made the first host/container comparison inconclusive.
- Fixed-peer IPv4 comparisons, preserving normal TLS hostname validation:

| F-Droid IPv4 peer | Android bytes/s | Ubuntu bytes/s |
| --- | ---: | ---: |
| 65.21.79.229 | 139715 | 186633 |
| 37.218.243.72 | 1169132 | 1640117 |
| 37.218.247.73 | 965991 | 1671076 |

Each request fetched at most 1,000,000 bytes from `/F-Droid.apk`, with a
15-second timeout and HTTP 206 response. Tests were sequential and used
different native clients, so the rates are diagnostic samples, not a precise
performance ranking. Both systems reproduce the slow peer. Endpoint selection
explains the measured F-Droid download symptom; it does not establish the cause
of every reported browser or search delay.

F-Droid 2.0.1 logs show the initial catalogue worker beginning at 09:00:18 and
finishing successfully at 09:03:41 UTC, including database processing. Small
later workers also returned SUCCESS. No sampled UnknownHost, SocketTimeout or
TLS handshake error was found. A successful refresh does not prove UI search
responsiveness. User confirmation after refresh and a specific slow browsing
destination remain pending.

## Conventional response and reproduction

[F-Droid's official mirror documentation](https://f-droid.org/docs/Running_a_Mirror/)
describes signed mirror metadata and compatible official servers. If needed,
use the client's supported mirror selection, retain the official repository's
signing identity, and compare an actual application download. Do not ship a
hardcoded DNS address, disable signature validation or make a phone-wide
network workaround based on these results. Addresses above are observations,
not permanent configuration.

To reproduce a bounded Android download as an authenticated administrator:

```sh
waydroid shell -- curl --resolve "f-droid.org:443:OBSERVED_IPV4" \
  --fail --range 0-999999 --max-filesize 1100000 --max-time 15 \
  -o /dev/null -w 'peer=%{remote_ip} total=%{time_total} bytes=%{size_download} speed=%{speed_download}\n' \
  https://f-droid.org/F-Droid.apk
```

Resolve current addresses rather than assuming the recorded ones persist.
For the host comparison, Python's standard-library HTTPS client connected to
the same IPv4 address, verified TLS against `f-droid.org`, used the same Range
and User-Agent headers, and read at most 1,000,000 bytes. Ubuntu's installed
environment has no host curl; no extra package was installed for these tests.
Raw application/network logs remain private. No persistent configuration needs
rollback because none was changed.
