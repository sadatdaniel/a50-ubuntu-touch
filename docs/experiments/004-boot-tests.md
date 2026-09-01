# Experiment 004 — the first boot tests

**Date:** 2026-09-01 · **Status:** 🔄 in progress · **Device needed:** yes

## Setup

Every flash: from TWRP via a50-droidian's `scripts/flash/03-flash.sh`
(push → size verify → `dd` to `bootdevice/by-name/boot`, `DD_EXIT:0` +
byte-count confirmed each time; first 1 MB read back and md5-compared once).
The pre-test boot partition is backed up byte-for-byte:
`boot-backup-preUT.img`, 57,671,680 B, sha256 `bdde0284…`.

## Test 1 — the tools-built boot image (`beb55619…`/`81b6ff7f…`)

Kernel: Google clang-r383902 ThinLTO build. Result: **stuck at Samsung
logo, static — no bootloop, no panic, no USB gadget** (no RNDIS adapter
appeared on the host at all).

Reading:

* S-Boot accepted the image — **the `id`-digest question from experiment 001
  is answered: S-Boot does not check it** (strong evidence: handoff happened,
  no rejection/restart).
* No panic means no kernel crash; a panic would reboot (bootloop). Static
  logo + nothing = kernel hangs before the initramfs reaches USB networking.
* Conclusion: the **tools-built kernel itself hangs early**. Open thread —
  candidates: clang-11/LTO codegen, or something in the config deltas.
  Not yet bisected.

## Test 2 — control image (`55afc75d…`): verified kernel + UT ramdisk

Kernel: `074aad86…` (the boot-verified Proton build, hash-checked against
the pin before packing). Ramdisk: the tools' merged upstream halium-boot
ramdisk (no overlay yet). Same flat header.

Result: **kernel boots** — uptime climbing, full dmesg, and the initramfs
came up: RNDIS gadget on the host (DHCP'd 192.168.2.55), debug telnet
reachable at `192.168.2.15` (ping <1ms). The initramfs did real work:

* mounted `/dev/sda32` (userdata) and the Droidian `rootfs.img` on it as
  `/root` via loop0, plus the Android system image mounts —
  "Android system image API level is 30", "boot mode: halium", "Normal boot".
* then **aborted the handoff** and dropped to the telnet shell.

This splits the failure cleanly: **ramdisk fine, tools kernel is the
hang** — and gave us a live initramfs shell to diagnose the handoff with.

## The handoff diagnosis (from the live debug shell)

```
run-init: opening console: No such device        (×6)
Target filesystem doesn't have requested /init.
No init found. Try passing init= bootarg.  → panic() → telnet
```

Two independent device facts, both verified live:

1. **S-Boot always passes `init=/init`** (visible in `/proc/cmdline`, an
   Android-ism from the device tree bootargs). Upstream's `/init` honors
   cmdline `init=` over its `/sbin/init` default — and a Debian-style
   rootfs has no `/init`.
2. **`/dev/console` cannot be opened O_RDWR on this kernel** — verified in
   the live shell: `exec 3<>/dev/console` → `No such device` (ENXIO). The
   node exists (5,1); there is simply no readable console driver, because
   the only registered console is Samsung's write-only `console=ram`.
   Upstream's final line is
   `exec run-init … <${rootmnt}/dev/console >${rootmnt}/dev/console 2>&1`
   — the shell cannot even set up the redirection, so the exec never runs,
   every init-probe "fails", and `panic()` fires.

Droidian's ramdisk never hit either: its init hardcodes the right target
and redirects the handoff fds away from the console.

## The fix: `ramdisk-overlay/init` (commit `9cb08bf`)

Upstream `/init` byte-identical except the handoff block: force
`init=/sbin/init` and `exec run-init … </dev/null >/dev/kmsg 2>&1`
(output to kmsg survives into the booted system's dmesg). Packed via the
tools' own overlay mechanism (second cpio appended by
`make-bootimage.sh`; note for verification: a single `cpio -i` stops at
the first archive's trailer — read the overlay with two sequential cpio
invocations off one `gzip -dc`).

## Test 3 — control2 (`boot-control2.img`, 47,048,704 B): init forced, run-init still dies

Same as test 2 plus overlay v1 (force `init=/sbin/init`, handoff fds
redirected off the console). Result: the *"requested /init"* error is
**gone** — but still panic → telnet. The `run-init: opening console`
errors are the binary's **own internal console open**; shell-side
redirections cannot bypass them.

## Test 4 — control3 (`2901b252…`): switch_root handoff — still panics

Overlay v2: handoff via `busybox switch_root` (never opens the console;
present in the initramfs, v1.22.1). Result: **still panic → telnet** —
and the dmesg trail showed why: the repeated `run-init: opening console`
lines belong to **`validate_init()`, which is `run-init -n`** — klibc's
dry-run probe opens the console even in dry-run mode. Every probe fails
ENXIO, `init=` is emptied, and `/init` panics at the *top* of the handoff
sequence — before any bottom-of-file patch is ever reached.

## Test 5 — control4 (`3b710bb1…`): the real fix — ✅ **BOOTS**

Overlay v3 (commit `749b59f`) fixes the actual blocker:

* `validate_init()` replaced with a plain shell check
  (`[ -x "$rootmnt$1" ]`) — no klibc, no console;
* `init=/sbin/init` forced **before** the validation (S-Boot's
  `init=/init` from the device tree never survives to the check);
* handoff via `busybox switch_root`, output to `/dev/kmsg`.

Result: **the device boots to the Droidian userspace — screen, UI, all of
it.** The complete chain is now device-proven:

S-Boot → UBports-tools-packed boot image → UT halium-boot initramfs →
`switch_root` → systemd.

The rootfs it booted is Droidian's (that is what lives on userdata); the
Ubuntu Touch rootfs is the next stage (rootfs install), not a boot-image
matter.

## Test 6 — no-LTO tools build (`boot-nolto.img`, `3a0120d2…`): HANGS

Identical to test 1 except `CONFIG_LTO_CLANG` dropped (single variable:
ThinLTO). Result: stuck at Samsung logo, no gadget, no panic — same
signature as test 1 (owner-confirmed screen state). **ThinLTO
exonerated.**

## Test 7 — Proton + tools-style build (`boot-proton.img`, Image `3b74364a…`): ✅ BOOTS to Droidian

Identical to test 1 except the compiler: the pinned Proton Clang 13
(a50-halium's toolchain) building the *same branch* with the same
bare `make O= … LLVM=1` style the tools use (minus `LLVM_IAS=1` —
Proton's integrated assembler rejects this tree's `memcpy` binding, so
the GNU cross assembler handles the `.S` files, exactly like mint's own
build). Same defconfig (`console=tty0` in, Polly out), same v3 ramdisk.
Result: **boots to the Droidian userspace.** The Image is 41,633,808
bytes — the identical byte count of the boot-verified `074aad86…`.

## Verdict

**Google clang-r383902 (`android11-gsi`) produces kernels that hang
this device early** — pre-initramfs, no panic. ThinLTO, the bare-make
delivery, `console=tty0` and the Polly removal are all exonerated: each
was varied independently and only swapping the compiler changed the
outcome.

Consequences:

* Near term the kernel comes from **Proton** — either a50-halium's
  pinned build or the equivalent tools-style Proton build just proven —
  fed into the tools' boot-image step. This is the fallback kernel.md
  always documented; everything else (ramdisk, packing, rootfs) is the
  tools' own.
* Convention-compliance option for later: try newer Google clang
  branches (`android12-gsi`, `android13-gsi`, …) — one build + one
  flash each, exactly like this series.

## Ledger of variables (one per test, as earned)

* Test 1: tools clang kernel + tools ramdisk — hangs.
* Test 2: kernel → boot-verified Proton — boots; ramdisk handoff bugs
  exposed (kernel-independent).
* Tests 3-5: ramdisk overlay v1→v3 — each fixed one diagnosed bug;
  v3 boots the full chain.
* Test 6: test 1 minus ThinLTO — still hangs ⇒ not ThinLTO.
* Test 7: test 1 with Proton — boots ⇒ **the compiler**.
