# Experiment 001 — can UBports' `mkbootimg` reproduce this device's boot image?

**Date:** 2026-09-01 · **Status:** ✅ answered · **Device needed:** no

## Question

`halium-generic-adaptation-build-tools` packs boot images with
`LineageOS/android_system_tools_mkbootimg` (branch `lineage-20.0`), driven by
`deviceinfo_flash_offset_*`. Two inherited facts say that will not work here:

* `device-facts.md`: *"Use the kernel tree's own `mkbootimg`, not a
  system-installed one. The system tool computes `header_version 1` addressing
  differently and rejects this device's official-style overflow address
  values."*
* `a50-droidian/scripts/build/05-build-boot-image-reproducible.sh` packs the
  known-good image with `--base 0x10000000 --ramdisk_offset 0xf0000000`, i.e.
  a deliberate 32-bit overflow to land `ramdisk_addr` at `0x00000000`.

If both hold, this port cannot use the upstream build tools unmodified — which
would be a serious problem, because using them unmodified is the whole point.

## Method

No device. Everything below is against `halium-boot-canonical.img`
(sha256 `d69a30a6…`), an image that has booted this device.

1. Unpack it by its own header (page 2048, kernel 41,633,808 B, ramdisk
   6,533,840 B).
2. Clone `LineageOS/android_system_tools_mkbootimg` at `lineage-20.0` — the
   exact tool and branch `setup_repositories.sh` fetches.
3. **A:** repack with a50-droidian's overflowing offsets.
4. **B:** repack with the same addresses expressed flat — base `0`, every
   offset absolute.
5. Byte-compare both against the original.

Script: [`scripts/experiments/001-bootimg-header.sh`](../../scripts/experiments/001-bootimg-header.sh).

## Results

**Free confirmation of two pins.** The parts extracted from the image are
exactly the published artifacts — kernel `074aad86…` (a50-halium's pinned
`Image`) and ramdisk `0af4d23f…` (the canonical ramdisk). The boot image is
what it is documented to be.

**A — overflowing offsets: rejected, as documented.**

```
struct.error: 'I' format requires 0 <= number <= 4294967295
  mkbootimg.py line 212, in write_header:
      args.output.write(pack('I', ramdisk_load_address))
```

`0x10000000 + 0xf0000000 = 0x100000000`. The vendor's own `mkbootimg` truncates
to 32 bits; this one raises. The inherited fact is **confirmed**, now against
the specific tool UBports uses rather than "a system-installed one".

**B — flat offsets: reproduce the image.**

| Region | Bytes | Result |
|---|---|---|
| Header, magic → cmdline | 0–575 | **identical** |
| `id` (SHA-1 digest) | 576–607 | **differs** |
| extra_cmdline + kernel + ramdisk | 608 → EOF | **identical** |

```
deviceinfo_flash_offset_base="0x00000000"
deviceinfo_flash_offset_kernel="0x10008000"
deviceinfo_flash_offset_ramdisk="0x00000000"
deviceinfo_flash_offset_second="0x00000000"
deviceinfo_flash_offset_tags="0x10000100"
deviceinfo_flash_pagesize="2048"
```

Every address field, both sizes, the page size, the header version, the board
name `SRPRL05B007KU` and the OS version/patch strings come out equal to the
image that boots.

## Conclusion

The upstream build tools **can** produce this device's boot image, unmodified.
The overflow form is a property of how a50-droidian invokes the vendor tool,
not a property of the device, and the same addresses expressed flat are
accepted by the stricter tool.

`device-facts.md` should not be read as "this device needs the vendor
mkbootimg". What it needs is those addresses; either tool can supply them if
asked in the form it accepts.

## What is still open

The 20-byte `id` field is a SHA-1 over the image parts and the two tools
compute it differently. **Nothing yet shows whether S-Boot reads it.** Android
bootloaders generally do not, and the field is not a signature, but "generally"
is not this device. This is the single remaining unknown between here and a
flashable boot image, and it takes one boot test to close:

* pack B's image, flash it, and see whether the device boots.
* If it does not, the difference is one field and the fallback is known —
  a50-halium can keep producing the `Image` and a50-droidian's script can keep
  packing it.

## Note on the method itself

The first version of the comparison ran `cmp -s <(dd …) <(dd …)` inside a
container that did not have the files. Both `dd`s failed, both substitutions
produced nothing, `cmp` compared two empty streams and the script printed
`IDENTICAL`. Same shape as the `awk '{64}'` guard in a50-droidian that passed
everything while printing success. The rewritten script checks the inputs are
non-empty before it is allowed to conclude anything.
