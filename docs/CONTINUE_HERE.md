# HOTICE — CURRENT HANDOFF (4 NOVEMBER 2026)

**Canonical repo:** https://github.com/parmtech/HOTICE
**Integration PR:** [#86](https://github.com/parmtech/HOTICE/pull/86) remains draft on PR #79. Current portable actor recovery is draft [PR #87](https://github.com/parmtech/HOTICE/pull/87), branch `feat/avatar-reference-portable-backup`, head `f9318d57a0b649bab22747bf6591a98763a33996`; it targets PR #86. Re-fetch exact heads and CI before proceeding.
**Source PRs:** #32 and #79 remain open and unchanged; neither is merged into main.
**Scope:** Integrate the consented 2D capture vault and smart reference planner with PR #79’s encrypted local project archive.
**Master product contract:** [HOTICE_HANDOFF.md](https://github.com/parmtech/HOTICE/blob/docs/ready-to-publish-release-gates/HOTICE_HANDOFF.md), currently proposed in open PR #34. Its section W sets the dependency-safe packets; its section X defines release gates.

Read the NEW authoritative contracts before proceeding:
- [AI Model Compatibility](API_MODEL_COMPATIBILITY.md): official provider docs, retired models, strict role/duration/ratio rules, security, and implementation gaps.
- [Smart Avatar & Reference Engine](SMART_REFERENCE_ENGINE.md): encrypted face-photo storage, privacy and 3D/reconstruction gaps.
- [Progress](PROGRESS.md): current phase gates.

## Current continuation checkpoint

The integration branch combines PR #79 head `8d01b0c` with PR #32 head `f3571e3`; draft PR #86 targets `feat/native-archive-save-health`. The original PR #32 and #79 branches remain untouched. PR #32 remains open at `f3571e3`; PR #79 remains open at `8d01b0c`.

- The Android/iOS face-reference vault stores accepted JPG/PNG/WebP images as AES-256-GCM ciphertext in private app storage. OS secure storage holds the device key; authentication binds each blob to vault format v2 and its reference UUID. If data exists but the key is unavailable, reads fail closed and cleanup preserves the ciphertext.
- Portable actor recovery now has a typed `.hoticeactor` envelope: AES-256-GCM, PBKDF2-HMAC-SHA256 (180,000 rounds), random salt/nonce, strict image/count/size checks, preserved FaceView/MIME and no account IDs, local paths or saved passwords. Restore encrypts photo buffers directly into the device vault, adds actor metadata in one store notification, waits for encrypted archive persistence, and rolls back metadata in the captured workspace plus staged ciphertext on failure. The format and wrong-password/tamper/rejection/account-switch rollback paths have unit coverage. Exact-head run [41726815125](https://github.com/parmtech/HOTICE/actions/runs/41726815125) passed inventory, static web, Flutter analysis/tests; APK and emulator smoke remain active at this checkpoint.
- Camera capture is encrypted immediately and the raw capture is removed after use. Manual imports preserve the user's source and remove only recognized picker-cache copies. Cache cleanup is best effort.
- Avatar and scene reference metadata, ownership, and selected reference IDs now round-trip in the encrypted device-local project archive. Restore rejects malformed UUIDs, owner mismatches, unsupported MIME/format values, duplicate IDs, and paths not ending in the matching `<uuid>.aes` vault filename. Avatar/project deletion removes associated ciphertext through vault path validation.
- **Face-photo key separation:** v3 blobs use HMAC-SHA256 workspace-derived AES-GCM keys rooted in OS secure storage, and bind format version, workspace ID and reference ID as authenticated metadata. v2 blobs lazily migrate on successful access in their original workspace. The migration keeps a recoverable ciphertext backup across interrupted file replacement. This does not protect against device compromise or root-key theft. Portable restore is an optional user-managed file on Android/iOS; HOTICE does not retain its password or provide cloud sync. Physical-device picker/save, migration interruption, low-storage, account-switch and deletion lifecycle QA remains outstanding.
- Draft [PR #88](https://github.com/parmtech/HOTICE/pull/88), child of #87, implements workspace-derived keys and lazy v2→v3 migration on branch `feat/avatar-reference-workspace-key-separation`. Current head `5babc9893b40c84de8bebd73ba1d783175b1aae7` includes interrupted migration cleanup and a user-facing key-unavailable recovery explanation that preserves ciphertext and guides backup restore/reference removal. Local validation: all 137 Flutter tests pass; analysis passes with informational lints; diff check passes. Actions run [41730193591](https://github.com/parmtech/HOTICE/actions/runs/41730193591) validated prior implementation head `8272a56`: Flutter analysis/tests, web/catalog, dependency inventory and APK passed; Android emulator smoke remains in progress. This latest code head needs its own CI result. Keep PR #88 draft pending physical Android/iOS vault and migration QA.
- Local integration verification (4 Nov 2026): `flutter pub get` passed; `flutter analyze --no-pub --no-fatal-infos` passed with 106 informational lints and no errors; all 124 Flutter tests passed; staged diff whitespace checks passed. PHP tests could not run locally because PHP is unavailable.
- Actor detail copy now correctly describes saved face-reference metadata as persisted in the encrypted local archive, with image bytes encrypted separately in the device vault; it no longer labels persisted references as “session only.” This wording does not imply cloud backup or cross-device recovery.
- Exact-head CI for initial integration commit `4a66f939`: [backend run 41712127198](https://github.com/parmtech/HOTICE/actions/runs/41712127198) passed. [Flutter/web/Android run 41712127380](https://github.com/parmtech/HOTICE/actions/runs/41712127380) passed analysis/tests, web checks, SBOM and APK build, but emulator smoke failed because the test expected `Avatar Studio` after returning to the Actors page. The page title is `Actors Studio`; the assertion was corrected in `9dee7773`.
- Current code head `78ecc6fb0098fee86821e3ab31fb6cda196fc83c`: backend run [41720730349](https://github.com/parmtech/HOTICE/actions/runs/41720730349) and all client jobs in [41720730344](https://github.com/parmtech/HOTICE/actions/runs/41720730344), including Android APK and emulator smoke, passed. Local test/analyze evidence is recorded above.
- Previous code head `b2ed67668ef5336b4719cc7f95bdd90187d1719e`: [backend run 41718473309](https://github.com/parmtech/HOTICE/actions/runs/41718473309) and all client jobs in [41718473425](https://github.com/parmtech/HOTICE/actions/runs/41718473425), including APK and emulator smoke, passed. Older code-head run 41713719942's emulator job was cancelled after remaining active beyond the configured timeout; its other client jobs and backend passed.
- PR #34 documentation head `808e692` passed all client jobs, including APK and emulator, in [run 41719183170](https://github.com/parmtech/HOTICE/actions/runs/41719183170). PR #86 latest head `abf785bc0567e7abbb4d4d53e2236cd8fb76ff82` is docs-only; backend run [41721148433](https://github.com/parmtech/HOTICE/actions/runs/41721148433) passed. PR #32 and #79 remain open and unchanged.
- Local verification at feature-code head `600cd14`: 87 Flutter unit/widget tests pass; `flutter analyze --no-fatal-infos` exits successfully with informational lints only; `git diff --check` passes. Exact-head [Flutter/Android run 41704681779](https://github.com/parmtech/HOTICE/actions/runs/41704681779) and [PHP/backend run 41704681962](https://github.com/parmtech/HOTICE/actions/runs/41704681962) both passed all jobs, including APK and emulator smoke on the Flutter workflow.
- Current PR head `cb5185d` also has passing Flutter analysis/tests and PHP/backend checks in [Flutter/Android run 41705798056](https://github.com/parmtech/HOTICE/actions/runs/41705798056) and [PHP/backend run 41705797971](https://github.com/parmtech/HOTICE/actions/runs/41705797971). Its APK compilation and emulator smoke were still running at the last check; recheck before making a full current-head CI claim.
- The earlier commit `2604b7d` initially failed CI due an unused-variable warning; this was removed in `29fd098`. Latest code includes the subsequent v2 authenticated-metadata change.

### Next implementation sequence

1. Run the portable actor backup/export and restore flows on physical Android/iOS devices, including file picker/save-dialog behavior, cancel/retry, interruption, low storage and account switching. Preserve the device-key vault and never write plaintext staging files.
2. Validate v2→v3 media migration and workspace key separation on physical Android/iOS devices; add recovery/deletion/retention options. Continue treating PR #24's email-derived vault and untyped list format as a separate migration source; preserve PR #24 and competing vault PR #22.
3. Preserve the current tested client branch and all open stacks; review exact PR heads and dependencies from master handoff PR #34 before selecting any broader integration work. No PR is merged by this handoff.
4. Schedule real Android/iOS capture, file chooser, orientation, permission, key-loss and restore acceptance. Emulator navigation is not physical camera or key-store validation.
5. Track gates in [issue #33](https://github.com/parmtech/HOTICE/issues/33). Release remains **NOT READY TO PUBLISH**; cPanel staging, live provider/billing, account/admin security, media/job production paths, iOS/device QA, accessibility/legal/licensing and rollback/restore evidence remain open.

## Existing capability boundary

Typed official-source research catalog in `lib/src/model_registry.dart`, in-app model browser, trust-bounded backend manifest parser, server-only PHP text-envelope builders for two routes, and CI contract tests are present. There is no connected live provider API, production keys, actual billing or real video rendering. Unknown model counts/features fail closed. No consumer-facing promise of permanent 100% compatibility is possible.

**Attention before release:**
1. Confirm CI at the latest *head commit*, including Android APK and Android emulator, not a previous green commit.
2. Run real-device camera/face pose QA. Existing emulator only tests navigation/permission entry, not face-angle accuracy.
3. Verify and deploy an authenticated PHP backend with vendor secrets outside webroot, entitlement/format/price probes, secure uploads and immutable credit reservation.
4. Activate providers *one model/version/task at a time* only after real successful low-cost test calls; keep all others read-only.
5. Never automatically migrate retired Sora 2 Videos API or Gemini Veo 3.1 Preview endpoints to unrelated providers.
6. Use independent role-aware attachment planners, not the four-image demo slot count; provider input semantics differ.
7. Backend catalog version, exact aspect/duration/resolution tuples, USD→HOTICE-credit price and idempotency must be revalidated before submit.

**Pricing invariant:** 1 HOTICE Credit = USD 0.01. Prices of individual model requests remain unconfigured. No key ever belongs in a Flutter bundle.

---

# HOTICE — LATEST DEVELOPMENT HANDOFF (26 OCTOBER 2026)

**Canonical repository:** https://github.com/parmtech/HOTICE
**New work branch:** `feat/android-preview-music-studio` (compare to `main`)
**Product brand:** HOTICE only
**Verification:** [Flutter analyze, widget tests and debug APK all succeeded on run 40201075329](https://github.com/parmtech/HOTICE/actions/runs/40201075329). Later avatar edit/delete commits also passed analysis and tests in [run 40201280827](https://github.com/parmtech/HOTICE/actions/runs/40201280827); recheck that run's Android APK result before calling the latest code build verified.

### What was implemented beyond the historical baseline
- One-tap demo guest entry and email-only optional demo, without mock passwords.
- Main generator separated into Normal Video and Music Video Studio. Storyboard is a local offline template; scenes can be edited, moved and saved in an account-scoped temporary workspace.
- Dedicated Avatar Studio with local create/edit/delete, appearance notes and a multi-angle face-scan **planning guide**. No actual camera or facial capture.
- `AvatarPromptComposer` integrates the text-only identity profile into saved Normal Video scene drafts for each illustrative demo model; there is no actual likeness matching or 3D identity lock.
- Better mobile More navigation, style/font presets and a temporary HOTICE launcher icon generated by `tools/brand_android.py`.
- GitHub Actions now builds an Android debug APK after passing static analysis and Flutter tests. Download it from the **Artifacts** section of a successful run; do not invent a direct APK URL.

### Current release gates
1. Confirm the very latest commit's analysis/tests **and** APK upload in Actions; then merge the tested feature branch into `main` if appropriate.
2. Conduct Android device UX/overflow/accessibility testing. A green Flutter test is not equivalent to real device usability.
3. Follow [3D capture, consent, privacy and model compatibility contract](AVATAR_IDENTITY_AND_SCAN.md). Multi-angle capture is deliberately not implemented; this is UI preparation only.
4. Add actual file permissions/capture, encrypted media storage, server-side accounts and real vendor adapters only in later approved phases. Verify each model's current reference input capabilities and pricing.
5. Add song upload, timing/transcription corrections, script planner, storyboard sync, export and proper media editing later. Keep prompt entry simple (one scene/story box per mode).
6. Credits value is still **1 Credit = US$0.01**, minimum purchase **US$10**, and all payments remain previews. Never charge demo credits or pretend unconfigured rendering costs are zero.

### Historical handoff follows
The below section records the prior baseline before these updates; **do not treat older failure counts, missing features, or requested next actions as more current than the 26 Oct update above**.

---

# HOTICE — CONTINUE HERE / NEXT MODEL HANDOFF
**Last reviewed:** 2026-10-26 (Australia/Sydney)
**Repository:** https://github.com/parmtech/HOTICE
**Branch:** `main`
**Verified baseline before this handoff:** `70608d76b4eca33ca7c1149e84af93361eae8784`
**Project name / product credit:** HOTICE (not ParmTech)
**GitHub account:** `manbir6-ux`

> **For any future ChatGPT model or developer:** Read THIS file first, then `README.md`, `docs/BLUEPRINT.md`, `docs/PROGRESS.md`, GitHub Issues and the latest commits/Actions. This is a dated handoff, NOT a guarantee of the current state forever. Re-fetch `main` and workflow results before making claims, and update this file after meaningful completed work. Continue existing code; don't restart the project.

## 1. What HOTICE is
HOTICE is a premium Flutter-based AI filmmaking application. Its target product includes a **Normal Video generator** and a separate **Music Video Studio**, accounts, projects, avatar/character library, several AI models/providers, and HOTICE Credits. The user wants striking, premium, professional UI (not cheap or generic), multiple themes, a proper app logo/icon, and an **Android APK for testing the UI before production integrations**. Branding within the product should be HOTICE. Do not add ParmTech product branding.

**Important scope distinction:** The currently committed application is a **local UI prototype**. It is not a working AI renderer or music editor, and is not production secure. The user previously requested no APK while developing screens, but later explicitly **requested a testable Android build**. That later instruction supersedes the earlier one.

## 2. Verified implementation committed to GitHub (baseline)
- `lib/main.dart`: Flutter entry point, responsive navigation shell, welcome/sign-in routing, projects/generation/avatars/credits/settings/account navigation. Small-screen header work has been committed.
- `lib/src/welcome.dart`: premium welcome, demo sign-in and register forms. No real authentication. Email validation improved.
- `lib/src/projects_generation.dart`: projects grid and create-project dialog; single free-text scene prompt, project selection, demo workflow/model chooser, duration, ratio, avatar and scene-draft saving with placeholder previews. No live video.
- `lib/src/account_credits.dart`: avatar presets, credits purchase **preview**, settings/themes, local demo accounts.
- `lib/src/state.dart`: ChangeNotifier in-memory app state; model draft data; demo workspace separation per account, guards for stale project selections, duplicate avatar rejection, email validation.
- `lib/src/video_models.dart`: **demo-only** model capability records and validation for selected model -> allowed duration/aspect combinations -> attachment types -> generation quote. The names/limits in this file are invented UI demo profiles, NOT verified vendor models. No real provider pricing is configured.
- `lib/src/design.dart`: reusable HOTICE theme and styling elements.
- `test/widget_test.dart`: approximately **12 declared tests** (unit and widgets), including credits conversion, account separation, avatar uniqueness, missing projects, and model capabilities. Their presence in source does NOT mean tests passed.
- `pubspec.yaml`: Flutter-only base dependencies and lint/test dependencies.
- `.github/workflows/flutter_ci.yml`: Flutter analysis and widget test workflow (NOT an APK build workflow).
- `docs/BLUEPRINT.md`, `docs/PROGRESS.md`, `docs/CREDITS.md`: architecture, roadmap, state and branding.

### Bug fixes already written to source
Account-switching demo data previously mixed between profiles; state was isolated in memory by profile. Duplicate avatar names could break the dropdown and are now rejected. Empty project lists could break the generator and are now guarded. Selected avatar is saved on scene drafts, email validation improved, and the mobile header/navigation was adjusted. **These fixes were code-reviewed/committed, but not yet proven with successful Flutter execution or device QA.** Do not call them verified bug-free.

## 3. Verified blocking issues as of this handoff
- GitHub Actions had **13 runs in the checked history, all with `conclusion: failure`** as of the baseline above. Latest observed: https://github.com/parmtech/HOTICE/actions/runs/40197914603
- GitHub connector returned a failed `validate` job without steps; prior attempts to obtain job logs returned 404/not found. **Do not infer this is a Flutter compilation failure** without evidence: investigate repository Actions permissions/runner provisioning first, then rerun.
- No `flutter analyze` or `flutter test` has been confirmed passing. No real-device responsive QA has been confirmed.
- The repo has **no checked-in `android/` or `ios/` platform scaffold** at the verified baseline. The README instructs `flutter create . --project-name hotice --platforms=android,ios`.
- No Android APK artifact or verified download link exists in the checked GitHub repository. No dedicated APK build workflow existed at baseline. Do not claim otherwise.
- No backend, database, live auth, AI video generation, audio transcription, file upload, production credit ledger, Stripe or PayPal checkout are implemented.
- A HOTICE visual concept/logo mockup was generated during conversation, but its assets have NOT been confirmed committed or installed as an application icon. A real scalable brand asset and platform icons still need implementation.

## 4. User decisions to PRESERVE
### One prompt box
The user **rejected multiple separate advanced prompt detail boxes**. Keep **one main free-text prompt field**, so users can describe location, action, camera angle, characters, background and lighting in one place. There may be concise settings for model, duration, ratio, attachments, etc. Do not reintroduce unnecessary location/character-placement subforms.

### Two creative modes
**A. Normal Video**: generate from text prompt, optionally with a user-selected photo/reference when the chosen provider supports that input; allow model, compatible aspect ratio/duration and supported attachments; show accurate credit quote once verified.

**B. Music Video Studio** (separate workflow; mostly NOT implemented):
1. User uploads a song and/or gives a brief story / creative description of the intended music video.
2. Choose an actual text/script-planning AI provider (ChatGPT/OpenAI, Gemini/Google, Claude/Anthropic or another *supported* integration; do not present any as connected until implemented).
3. Audio analysis/transcription should derive lyrics with accurate **word timings**, musical sections, mood and beats. Transcriptions, timing and mood are not guaranteed accurate without an actual tested audio pipeline; allow user corrections.
4. AI creates a cohesive narrative, full scene-by-scene script and timestamps, proposing shots synced to audio. User can review/edit/reorder/regenerate individual scenes.
5. Allow a choice among **roughly 7–8 visual directions**, for instance realistic, cinematic, anime, cartoon/animation, stylized 3D, fantasy, animals/creatures, illustrative; exact list may be refined. Animal is a content category rather than a universal visual rendering style: clarify gently in UI.
6. Scene duration often 4–10 seconds when supported by the selected rendering model; preserve beat/lyric sync, character facial consistency and optional lip-sync.
7. Use a timeline for scenes, transitions and final synchronized music video rendering; keep editing flexible enough to extend later.

**Music Video Studio is a product requirement, not a completed feature.** Do not label the current app as already supporting song upload or lyric extraction.

### Dynamic model rules and credits
- **1 HOTICE Credit = USD $0.01**. USD $10 minimum purchase = **1,000 Credits**, USD $20 = 2,000, USD $50 = 5,000. These are purchase values, not video-rendering charges.
- **Every actual AI video model has its own allowed durations, aspect ratios, reference attachment types, provider limitations and generation credit cost.** Update controls immediately when a model changes; check valid *duration + aspect ratio pairs*, not each dimension in isolation. Reject unsupported input combinations before submitting jobs.
- Current `video_models.dart` includes only sample/demo capability profiles. Do not invent/advertise official model specs or per-generation credit prices. For production verify **up-to-date official API docs** for each provider and model version, then control the capability/pricing catalog from the backend and validate requests server-side. Unconfigured price = **unavailable**, not free.
- The model used to analyze a song and write a music video script is separate from the model that renders video clips; the user can select each as supported.
- Payment UI offers Stripe, PayPal and credit/debit cards but **does not process real payments**. Never credit user wallets from unverified client actions; use server-side verified webhooks and an immutable ledger.
- User expects multiple accounts with safe switching, attractive themes, useful avatar creation, and consistent faces across scenes. Real auth and storage are still pending.

## 5. Immediate next tasks — in order
1. **Reverify the repository** after this handoff, because the owner may edit it externally. Read existing files and open GitHub Actions run details.
2. **Unblock CI**. Inspect why `validate` jobs are failing with no observable steps (repo Actions policy, permissions, runners, account limitations, YAML; avoid speculative diagnosis). Run `flutter pub get`, `flutter analyze`, and `flutter test` in a real Flutter environment. Fix confirmed compile, lint, test, overflow and lifecycle bugs; commit changes with evidence. Do not equate adding tests with passing tests.
3. **Prepare a genuine testable Android APK** as now requested: establish Android scaffold and build workflow; include HOTICE branding/app icon; run build, check for a successfully uploaded artifact, share the **actual** GitHub Actions artifact or release link only after confirmed success. No fabricated APK link. Ideally test on narrow Android sizes.
4. **Add explicit mode selection** for Normal Video and Music Video Studio. Implement a high-quality **demo-only** Music Video Studio UI: song selector (only if a file picker is actually wired), story brief, planning-model picker, visual-style options, transcript/timing placeholder, scene storyboard/timeline and status. Clearly distinguish placeholders from working features.
5. Verify behavior of model-dependent duration, ratio, reference attachments and generation credit display. For models with no price quote, state price unavailable and do not enable billable generation.
6. Then design and implement real server-side auth, per-account persistent data, uploads/storage, song transcription and alignment, script-generation AI, model/provider adapters, video render jobs, payment systems and cost controls. Put secrets on server, never in the Flutter client.
7. Update this handoff, `docs/PROGRESS.md`, GitHub Issues and README as each stage is **actually** tested/finished. Share meaningful commits, exact run IDs and build links.

## 6. GitHub tracking
- [Issue #1 — Flutter CI + responsive QA](https://github.com/parmtech/HOTICE/issues/1)
- [Issue #2 — Auth and persistent workspace](https://github.com/parmtech/HOTICE/issues/2)
- [Issue #3 — Real video models, avatars, uploads](https://github.com/parmtech/HOTICE/issues/3)
- [Issue #4 — Stripe, PayPal, HOTICE Credits ledger](https://github.com/parmtech/HOTICE/issues/4)
- [Issue #5 — QA and app release](https://github.com/parmtech/HOTICE/issues/5)
- [Latest Actions runs](https://github.com/parmtech/HOTICE/actions)
- [Full blueprint](BLUEPRINT.md)
- [Existing progress checklist](PROGRESS.md)

**Status labels:** `Implemented in source` != `CI passed` != `running on Android` != `production ready`. Do not calculate a misleading completion percentage while feature scope is growing.

## 7. Prompt to start the NEXT model (copy verbatim or paraphrase)
> Continue the existing HOTICE Flutter application in https://github.com/parmtech/HOTICE. Start by reading docs/CONTINUE_HERE.md and docs/PROGRESS.md, and inspect the latest commits, issues and GitHub Actions. Don't recreate the project or assume old status is current. First diagnose and fix failed Flutter CI/tests, then prepare a real debug/test Android APK with HOTICE icon, then add separate Normal Video and Music Video Studio UI according to the handoff. Respect one free-form prompt box, model-specific valid durations/aspects/attachments, no invented provider fees, 1 HOTICE Credit = US$0.01, USD $10 minimum purchase, HOTICE-only branding, no live AI/payments claims. Commit tested fixes, link actual results and keep GitHub handoff/progress updated.

_This file records the verified state at the moment of writing and the user's explicit future requirements. If later commits conflict, verify those changes first._
