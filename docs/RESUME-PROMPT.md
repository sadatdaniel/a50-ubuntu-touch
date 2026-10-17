# Resume prompt

Paste this into a fresh session:

---

Continue the Samsung Galaxy A50 (SM-A505F) Ubuntu Touch 26.04 port toward a
conventional, stable release with OTA, following official UBports
documentation. Read `docs/SESSION-HANDOFF-22.md` first, then `docs/status.md`
(top entries), `docs/release-validation-backlog.md` and the experiment for
whatever you touch. Older handoffs are history only.

Verify both repos' revisions and live phone health (USB ADB) before acting.
On a fresh checkout restore inputs with `scripts/release/fetch-release-inputs.sh`.
Preserve Samsung vendor and `a50-halium/out-aa*`. Do not flash a kernel
unless the owner is present. Do not provision paid compute or touch other
projects' Docker data without approval. Ask the owner for physical or sudo
steps only when a concrete test is armed. Fingerprint last.
