# Session handoff 10 - verify the AppArmor kernel fix

Started 2026-09-11 21:05 CEST. Prior handoffs are preserved.

Previous turn made progress: captured the host-only AppArmor panic, restored
the phone, reproduced Samsung's incorrect empty-hook return offline, committed
the minimal correction as a50-halium 2b1c523, and launched a separate build.

## Current verified state

- Port 92adcbd and kernel/build 2b1c523; no tracked uncommitted changes at start.
- Docker a50-kbuild-aa4 is RUNNING; source volume a50-ksrc-aa4, output out-aa4.
  At 21:05 it had applied security-hook-default.patch and step3 configuration.
  Reuse this live build; do not restart because fetch/link stages are quiet.
- Phone on recovered aa1; Wi-Fi 192.168.179.85 works. At 21:05 uptime 9m,
  available memory 1611 MiB, swap 278 MiB, no new coredumps since 21:03.
- All temporary test startup changes were removed in handoff 09. The vendor
  preload is in source but was removed from the live phone after the test.
- Next health sample due 21:28 CEST, then every 30 minutes during active work.

## Next steps

Check completed build configuration against the preserved aa3 source, verify
the one intended source difference, then pack with the existing known-good
UBports donor. Repeat the guarded host-only AppArmor test before enabling the
separate vendor preload. Do not conflate a regression test with a boot result.

UBports' AppArmor documentation also prescribes version-specific patches;
audit those against this kernel before claiming full app confinement support.
https://docs.ubports.com/en/latest/porting/configure_test_fix/Apparmor.html

## Verification while compilation runs

- Resolved .config compares byte-for-byte equal between a50-ksrc and
  a50-ksrc-aa4. HARDENED_USERCOPY remains enabled; AppArmor is selected via
  the same security=apparmor built-in cmdline as aa3.
- Tracked source diffs excluding security/security.c compare identical.
  That file differs by only RC=IRC after the successful integrity check.
- The regression passes against the actual new build source, not just a
  separately edited test fixture.
- Known UBports donor hash verified:
  90c281f8da080f7bc1a9ec9aa822e0ae10bd19a77804717e0c3f6ea83cffd03b.
- Saved failed-boot evidence really includes AppArmor initialized at
  0.004127 seconds and the null/106-byte usercopy panic at 8.700265 seconds.

## Required AppArmor patch audit

Fetched the two commits linked by the official 4.14 guide into
a50-ut-out/session-10 (unmodified upstream patches):

- 559e4f447556e1ea0b24b035965023b6fba8f2f8: socket mediation infrastructure.
- f076c3083d908253d32d26b49d64faaf4f80b442: Unix socket mediation.

The current tree lacks these changes. Tested on a disposable security/
copy: first patch initially rejects only its missing .gitignore file;
excluding that metadata hunk allows all code changes, and the second patch
then passes git apply --check. No build source or phone changed by this audit.
These are still required before claiming complete UBports AppArmor support.
Keep the current aa4 boot test focused on the captured panic first.
