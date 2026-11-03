# HOTICE repository instructions

Read [HOTICE_HANDOFF.md](HOTICE_HANDOFF.md) before planning or changing this repository. It is the canonical UX-first product blueprint, branch inventory, release contract and continuation ledger.

- Follow the latest human request. A documentation-only request permits documentation only; the blueprint does not independently authorize deployment, paid calls or merging.
- Inspect current branch/head, git status, remote PR bases and actual CI. Preserve dirty files, divergent commits and existing feature stacks.
- Distinguish planned, implemented, verified-in-branch and integrated-verified work. Historical README and handoff statements may be stale.
- Reuse existing code and contracts. Do not replace working subsystems or combine competing vaults without an evidence-backed migration decision.
- Keep provider keys and billing authority on the server. Preserve local-first projects and explicit consent-based paid cloud sync.
- Validate the complete affected user journey and meaningful failure cases; record exact source revisions and evidence. Mock success is not live-provider, billing, physical-device or production proof.
- After every meaningful work unit, update section Z's ledger and the current-state/remaining-work entries in HOTICE_HANDOFF.md. Keep release issue #33 and relevant PR descriptions consistent with verified evidence.
- Never claim READY TO PUBLISH while a required release gate is open or unverified.
