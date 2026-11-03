# HOTICE — Development Progress

> **Continuing HOTICE on another model?** First read [CONTINUE_HERE.md](CONTINUE_HERE.md) for the verified repo state, product decisions, blockers, and ordered next steps. Refresh the current branch and Actions status; this checklist may lag behind newer commits.

## Guided live face capture — 28 October 2026 (feature branch)

- [x] On-device Camera2/NV21 + ML Kit face detection and 5-step auto-capture implementation with explicit consent, front-view open-eye checks, framing/head-pose/lighting heuristics, still revalidation and retake controls.
- [x] Prominent Live face capture UI; capture photos are linked to the selected Actor as 2D reference assets in the encrypted device-local archive; app-owned temporary files are deleted through vault path validation on removal.
- [x] Native camera permission generation and iOS 15.5 deployment/privacy configuration; unit tests for pose and eye-quality logic.
- [ ] Physical Android/iOS scan accuracy, orientation calibration and camera-permission/lifecycle field QA. CI emulator smoke tests do not prove face scanning works.
- [x] AES-GCM encrypted device vault and archive persistence for avatar/scene reference metadata, ownership and selected IDs. Device key means no cross-device recovery; this is not cryptographic per-account isolation.
- [ ] User-controlled encrypted media recovery/export, actual multi-view 3D reconstruction and export, native model APIs and verified identity fidelity.

## AI Model compatibility foundation — 28 October 2026 (feature branch)

- [x] Source-backed provider-scoped catalog spanning video, image, script, speech and transcription candidate models; retired API endpoints fail closed.
- [x] Exact task/role/duration/ratio/resolution validation with unknown media limits rejected. Static research is not considered an authorized live quote.
- [x] Searchable Model Compatibility page linked from Settings and Normal Video.
- [x] Expiring versioned trusted-backend manifest parser with exact format tuples and duplicate/unsupported-role rejection.
- [x] Server-only PHP Google Omni/Runway text-video request envelope builders with secret isolation, fixed hosts and approval gates, plus CI policy tests.
- [ ] Actual authenticated cPanel server API, key setup and live provider connectivity; production verified catalog, paid model probes, uploads, job queue, billing and end-to-end tests.

See [API_MODEL_COMPATIBILITY.md](API_MODEL_COMPATIBILITY.md).

## Smart reference work-in-progress — 28 October 2026 (feature branch)

- [x] Typed smart reference selection engine in source with image/GLB capability gates, pose-aware scoring, manual locks, consent checks and account/project ownership validation.
- [x] Avatar Studio manual front/side face photo tagging/import, scene image picker, generation reference preview, immutable reference IDs on drafts, and encrypted archive round-trip.
- [x] Focused tests cover archive round-trip, invalid owner/path rejection, account isolation and avatar rename/delete reference lifecycle; current local Flutter suite passes.
- [ ] Actual guided live camera scanning, landmark/eye checks, quality gating, trusted 3D reconstruction/export and secure long-lived avatar storage.
- [ ] Verified vendor reference limits + server-side adapters, encrypted backend media, genuine AI rendering and likeness benchmarks.

See [SMART_REFERENCE_ENGINE.md](SMART_REFERENCE_ENGINE.md) for exact supported behavior and privacy limitations. **Current changes are on a feature branch and not a production release.**

## Current verified snapshot — 26 October 2026
- [x] **Flutter static analysis, unit/widget tests, static web validation, Android emulator smoke test, and Android debug APK build passed** on [Actions run 40246311392](https://github.com/parmtech/HOTICE/actions/runs/40246311392).
- [x] Android **debug** APK artifact `HOTICE-Android-v0.2.0-run85` was compiled and uploaded in that run. It is not a production-signed APK. Emulator smoke passed; manual device QA remains open.
- [x] Clear Normal Video / Music Video Studio mode switch with one freeform scene/story prompt in each mode.
- [x] Music Video Studio text-only local storyboard with selectable styles and edit/reorder/save controls. **No song upload, lyric timing, beats, live AI planning or rendering.**
- [x] One-tap demo entry without a fake password. All accounts/workspaces remain in-memory demos.
- [x] Avatar Studio editing/deleting, identity descriptions reused in demo model prompts, and guided 3D capture **preparation** UI. **No real scan or likeness lock.**
- [x] Additional font choices and corrected mobile More navigation.
- [x] Searchable Inspiration Library prototype in Flutter and static web; approved HOTICE-written prompts prefill a demo model and accept named Actor assignments.
- [x] Public prompt entries require provenance, prompt reuse scope, attribution, media-license/embed and last-verified metadata; no third-party videos are included without item-level rights checks.
- [x] Namecheap-compatible static website base plus documented PHP/MySQL admin, narrow API proxy and approved-feed/manual-review ingestion plan. These server components are not implemented.
- [x] Resolve the Android file picker build incompatibility and narrow-screen Studio header overflows; latest Android APK and emulator smoke checks passed on run 40246311392.
- [x] Latest Android APK artifact confirmed for this revision; check [Actions](https://github.com/parmtech/HOTICE/actions) for future edits.
- [ ] Manual Android portrait/landscape screen-reader and device UX QA.
- [ ] Real camera capture / depth scan with informed consent, secure biometric deletion and provider-specific identity-reference testing.
- [ ] Server-side auth, cloud persistence, secure uploads, real AI rendering and verified real provider costs.
- [ ] Accurate song transcription/timings, media timeline, lip-sync, output editor and export.
- [ ] Verified Stripe/PayPal/payment webhooks and credit ledger.

**Definition of complete:** Implemented UI means only that demo interactions exist. It does not mean a verified AI/media pipeline or perfectly consistent 3D avatars. [Avatar identity architecture](AVATAR_IDENTITY_AND_SCAN.md).

## GitHub task threads
- [M1 — Flutter CI and responsive QA](https://github.com/parmtech/HOTICE/issues/1)
- [M2 — Secure accounts and persistence](https://github.com/parmtech/HOTICE/issues/2)
- [M3 — AI video generation and avatars](https://github.com/parmtech/HOTICE/issues/3)
- [M4 — Stripe/PayPal/cards and credit ledger](https://github.com/parmtech/HOTICE/issues/4)
- [M5 — Professional QA and release](https://github.com/parmtech/HOTICE/issues/5)

**Verification note:** Run 40246311392 passed Flutter analysis/tests, static web validation, the Android emulator smoke journey, and debug APK compilation/upload on 26 October 2026. The APK is a preview build; manual device QA remains outstanding.

This checklist tracks source-level implementation separately from integration and release verification. A checked box means the specified source/UI task was written, **not** that it is production-ready.

## M1 — UI foundation
- [x] Flutter dependency manifest and app entry.
- [x] HOTICE branding, premium reusable design system and responsive shell.
- [x] Welcome screen.
- [x] Sign in / create-account demo screen.
- [x] Project grid, new-project flow and navigate-to-editor.
- [x] Video generation prompt, duration, ratio, workflow picker and local draft queue.
- [x] Avatar Lab create/list demo presets.
- [x] HOTICE Credits pricing: 1 cent per Credit; USD 10 minimum; USD 10/20/50 choices.
- [x] Stripe, PayPal and card selection UI (no live checkout).
- [x] Demo account add/switch/sign-out.
- [x] Dark/light/system and five accent presets.
- [x] GitHub Actions workflow + basic Flutter tests (execution status must be checked in Actions).
- [x] Flutter analyze passing in GitHub Actions (run 40201075329).
- [x] Flutter widget tests passing in GitHub Actions (run 40201075329).
- [ ] On-device UI / responsive visual QA.

## M2 — Backend and identity
- [ ] Real login/register, validation, reset and refresh token policies.
- [ ] Secure account switching, session isolation and cloud persistence.
- [ ] Project and avatar storage, backup and recovery.
- [ ] Persisted per-account theme and preferences.

## M3 — Real video and avatar generation
- [ ] AI provider adapter interfaces and model discovery.
- [ ] Video render job queue and status tracking.
- [ ] Image/reference upload and likeness consistency.
- [ ] Saved video previews, exports, retries, cancellation, errors.
- [ ] Audio/video timeline and advanced editor.

## M4 — Real credits and payments
- [ ] Authenticated server-side wallet and immutable transaction ledger.
- [ ] Stripe Checkout, server-side verified webhooks and payment cards.
- [ ] PayPal order capture, verified webhook and reconciliation.
- [ ] Receipts, refund/chargeback adjustments, tax handling.
- [ ] Model-specific per-generation credits pricing.

## M5 — Quality and release
- [ ] UI polish, accessibility and tablet/desktop overflow checks.
- [ ] Integration tests with CI green.
- [ ] Android/iOS native project scaffolds committed and maintained.
- [ ] Device build and manual QA.
- [ ] Release signing and app-store distribution (not yet requested).

## Issue-based progress
Use GitHub Issues as separate task threads for each next phase; link commits/PRs to the issue, and close only once tested. Do not calculate a whole-project percentage from this checklist: the scope and weights are not fixed.
