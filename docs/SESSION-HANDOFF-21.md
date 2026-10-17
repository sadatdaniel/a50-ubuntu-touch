# Current session handoff 21 — 11 October 2026

Start new work here. `SESSION-HANDOFF-20.md` and earlier handoffs preserve
chronology, but contain old device states and pending instructions. Treat them
as history only; use this page, `docs/status.md`, and
`docs/release-validation-backlog.md` for current work. Verify live state before
phone or Docker actions.

## Goal and user preferences

Develop a reproducible, shareable stable Ubuntu Touch 26.04 port for the Samsung
Galaxy A50 SM-A505F (`a50`, Exynos 9610, Halium 11). This remains a development
port: no stable image and no OTA channel. Search official UBports/upstream and
existing device implementations first; prefer conventional supported fixes.
Keep Samsung vendor intact. Every validated fix needs a reproducible script,
meaningful checks, evidence/rollback notes, and a GitHub commit/push. User asked
to defer `agent.md` and `first_contact.md` until the checklist is resolved.
Fingerprint is last. Do not provision paid compute without explicit approval.

## Workspace and repositories

- Port repo `C:/Users/sadat/Development/a50-ubuntu-touch`, branch `main`, HEAD
  `ab9b30c896fb8299245d132ce92bdb549343f279` at handoff time; clean, pushed.
- Halium repo `C:/Users/sadat/Development/a50-halium`, branch `main`, HEAD
  `8fda1eacabc05ab21cd6425ba7e9a4e60b15ee80`. Numerous untracked `out-aa*`
  directories contain old builds and candidates. Preserve them. Do not use
  `git clean`, `git reset --hard`, broad deletion or `git add .`.
- Private task evidence/scripts: current Codex workspace `work/session02` and
  `work/private`. Phone evidence is under `/userdata/`, as referenced by the
  experiments. Keep credentials, private logs and calibration data private.
- No `AGENTS.md`, `agent.md` or `first_contact.md` was found in either repo.

## Latest verified state

**Phone:** last confirmed on aa17. aa18 is built but unflashed; it fixes a
reproduced pidfd-wait issue, whose effect on Waydroid is not established. Verify
live kernel, boot ID, root read-only, AppArmor, failed units and access before
any device operation. Do not flash aa18 unless the owner is present for health
and fallback checks. Boot candidates (both 55,984,128 bytes):

- aa17 fallback `out-aa17-pullup-state/boot-aa17.img`, SHA256
  `a413d2bc4a605489225a0b5d8e512965af83eea39b7abb6097dbc2f7420775c8`.
- aa18 candidate `out-aa18-pidfd-wait/boot-aa18.img`, SHA256
  `81f172febf16ebc8d132565f5bda3de8c6200df177647d8034d8a34971ec9776`.

The vendor/recovery partitions were not changed.

**Sleep and health:** installed aa17 passed nine unplugged deep cycles (76.719s,
zero resume failures), then an overnight run added 180 successful cycles,
7h47m16s asleep, with 18 explained Wi-Fi/cable/modem/alarm wake aborts and zero
resume failures. Owner confirmed the existing Waydroid window responded after
wake. This is substantial aa17 soak evidence, not clean-image/OTA validation.
The overnight observer was collected, archived privately and removed. AppArmor
is enabled and actual allow/deny tests passed. One isolated 64 MiB memory-cgroup
OOM test killed only its disposable worker and allowed a later allocation; it
does not prove whole-phone or Android LMK behavior. The user's post-OOM phone
responsiveness confirmation was pending.

**Lomiri/Waydroid/audio/authentication:** the four-app graphical Restart passed
twice with real Samsung logos/changed boot IDs after the shared snapshot fix.
Recents proportions and Terminal/Settings reopen repetitions passed after
reboot. Waydroid's native single-instance launcher fix survived reboot and three
user drawer close/reopens; the existing background window also survived the
overnight sleep test. Fresh-image Android initialization and broader lifecycle,
network and stability checks remain. Authentication PIN/swipe behavior and
YouTube audio were user-confirmed working; validate again on the clean image.

**Camera:** the PR 84 temporary library test passed three Stop/playback cycles
with picture and sound, but those mounts disappeared on reboot. Video is not
proven fixed in a distributable image. Build and test the complete corrected
Android GSI before claiming release readiness. Fingerprint remains deferred.

## Image and OTA readiness

Port commit `4d57b1f` integrated a verified, hash-locked cohort of 18 native
packages in the image assembler. The installed phone cohort matches; APT dry run
reports no changes. The assembler uses native APT in the offline Ubuntu 26.04
ARM64 root, applies device overlays afterward, records source/package provenance,
and refuses incomplete or changed inputs. Real Debian archive and tiny ZIP
gate regressions pass. **A fresh rootfs install and full candidate image have
not been built.** Read `docs/experiments/059-image-package-integration.md` before
changing this pipeline. Legacy OpenStore XML/ICU extraction remains separate
release debt.

The complete PR 84 GSI build previously failed for lack of space; its documented
builder requirement is about 250 GiB free on conventional Linux. Windows C: now
has about 44.3 GiB free, after obsolete A50 caches were removed and Docker's
VHD was compacted. Docker is running; the one unrelated `oci-a1-retry` job
resumed under its own policy. Retained `a50-ksrc-aa12-wifi-early` kernel source
cache passed a fresh read check. Do not repeat cleanup/compaction or touch
unrelated Docker resources. No DigitalOcean/Vultr resource has been provisioned.

Unified recovery exists only as an offline candidate. OTA is disabled. Release
still needs conventional recovery/device integration, safe on-device recovery
test, two signed local updates retaining userdata, maintained channel/signing,
installer configuration, clean install and post-update regression. Never use
the private signature bypass.

## Afternoon update, 11 October

Read [060](experiments/060-upstream-input-retention.md) before continuing:

- Phone verified on aa17 (`#6`) over USB ADB; Wi-Fi SSH was unreachable.
- Pinned GSI 1542 is no longer downloadable from Jenkins, which keeps about 30
  builds. `dl/halium_halium_arm64-1542.tar.xz` is the only copy. Any
  corrected GSI should re-pin to a current build (1578 has six frameworks/av
  security fixes) with the PR 84 guard. Archive release inputs durably.
- All 18 cohort archives are preserved in gitignored
  `dl/cohort-20261011/` (flat bundle in `bundle/`). On 16 October the gated
  fresh-rootfs test **passed**, after fixing a real blocker: `--no-download`
  made the image installer's real APT install fail for every local archive.
  The installer now disables sources instead.
- 16 October log check, same aa17 boot for 6 days: no Linux or Android
  service restarts, core dumps or OOM kills. **Regression:** Waydroid's
  `android.hardware.camera.provider@2.4-service` restarts every 5 s. The 013
  stop helper runs only once per container-service start, so each new
  Waydroid session brings the loop back. Fixed by a system-overlay `.rc` via
  tmpfiles ([061](experiments/061-waydroid-camera-overlay.md)); zero starts verified.
  Waydroid container daemon fd leak (1021/1024) is open.
- The fresh rootfs is newer than the cohort for QtMir and Settings
  (intentional downgrades), and 184 other packages differ from the phone.

## Next actions

1. Check both repos' current revisions and preserve untracked `out-aa*` files.
   Verify phone/Docker state before relying on this snapshot; do not repeat the
   completed Docker cleanup or disk compaction.
2. Continue work not requiring the owner beside the phone. First review official
   UBports build/recovery/OTA conventions and upstream status of camera PR 84.
   Make the corrected GSI path and the 18-package fresh-rootfs integration
   reproducible; do not launch a large build on C:.
3. A 250 GiB builder requires explicit owner approval and a reviewed cost plan.
   Do not create a paid cloud machine. The owner has DigitalOcean/Vultr accounts
   and credits but chose to defer this decision until the port is closer to
   release-ready.
4. Keep `docs/release-validation-backlog.md` and this handoff aligned with new
   evidence. Remaining checks include clean install/onboarding, first-boot
   package integration, camera GSI, signed OTA/recovery, Waydroid soak, Bluetooth
   idle/reconnect/suspend, VPN, Libertine, reset, telephony/GNSS/hotspot,
   notifications, charge estimate and final soak. Ask for physical steps only
   when a concrete test is armed and cannot be done remotely.
5. Finish `agent.md` and `first_contact.md` only after the release checklist is
   complete, as the owner requested.

## Resume prompt

See the copyable fresh-agent prompt supplied with this handoff. Never claim
stable/release-ready until the clean-image and signed-update gates pass.
