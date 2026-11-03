# HOTICE Inspiration Library — source, rights and release specification

Updated 4 November 2026. This is a staged feature plan, not a claim of connected vendor models or launched scraping.

## Implemented first-party motion-study slice (4 November 2026)

The six original prompt templates each include a locally bundled 640×360 VP9 WebM for the browser, an H.264/yuv420p MP4 for Flutter's Android/iOS players, and a PNG poster. All are deterministic canvas animations authored for HOTICE with an embedded **HOTICE MOTION STUDY · CONCEPT ONLY · NOT AI OUTPUT** label. The Flutter card shows the poster and creates no video controller until the user opens a preview. The full-screen player starts paused and silent, provides play/pause and scrubbing, stops when dismissed, pauses when the app backgrounds, and has a retryable error state. Mobile concept clips are 24 fps, silent, and no larger than 127 KB each; posters are no larger than 145 KB each. No remote media is requested.

The checked-in MP4 and poster files are reproducible derivatives of the first-party WebM source. With FFmpeg available, generate an MP4 with `ffmpeg -i input.webm -an -vf "fps=24,scale=out_range=tv,format=yuv420p" -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -color_range tv -profile:v baseline -level 3.0 -movflags +faststart output.mp4`; extract its poster with `ffmpeg -ss 1 -i input.webm -frames:v 1 -vf "scale=640:360:flags=lanczos" -compression_level 9 output.png`. `tools/check_web.py` checks the H.264 MP4 signature, PNG signature and bundle-size ceilings. Flutter unit tests check catalog path derivation. Exact codec, dimensions, frame rate and silent stream were locally verified with ffprobe.

Catalog validation accepts only the exact local `/assets/examples/<template-id>.webm` path and first-party provenance. The static-site check also requires each bounded H.264 MP4 and PNG poster. The public copy distinguishes concept visuals and procedural loops from AI model output. Model names remain illustrative demo profiles; paid/live providers are not called.

Validation status: `flutter analyze --no-fatal-infos` reports no errors (24 informational lints remain); local Flutter unit/widget suite passed 51 tests; static site/catalog, JS syntax and whitespace checks passed; ffprobe verified all six MP4 streams as silent H.264 640×360 24 fps `yuv420p`; the browser run previously verified all six WebM responses and playback, plus synthetic export, local project/relink, and mock account/jobs/cloud paths (`realProviderCalls: 0`). Android emulator acceptance is encoded in `integration_test/android_smoke_test.dart`; no emulator is configured in the local environment, so exact-head Android CI must pass before the slice is verified. This branch is not merged.

## Product experience

**Public name:** Inspiration Library. Website showcase heading: **What's Possible with HOTICE**.

* Browse categories (cinematic, music, fantasy, camera motion, actors, advertising, social) and search original/permission-cleared prompt templates.
* Each template holds title, prompt text, model hint, tags, optional preview with correct rights, reference-asset requirements, up to N actor-role placeholders, suggested camera/mood metadata and compatibility profile version.
* **Use this prompt:** copy the editable prompt and compatible **demo** model into Normal Video composer. User chooses their own named Actors and locally-selected reference assets where model allows them, adjusts Advanced settings, then saves a draft. It **does not** start paid rendering.
* If a prompt was not published with a clip, never label a reconstructed prompt as the “original.” An editorial adaptation must be marked “HOTICE-written adaptation” in rights metadata.
* On public showcases, emphasize HOTICE rather than linking people away. Do **not** say third-party videos were made by HOTICE. Respect attribution and embedded-player branding restrictions; do not remove watermarks/source links embedded by providers. Use self-hosted, permission-cleared video where allowed.

## Research sources to monitor for candidate discovery (not automatic content rights)

1. Google Flow TV — `https://labs.google/flow/tv/faq` and `https://support.google.com/flow/answer/16353333`: curated clips with some publicly viewable prompts.
2. Runway Gen-4 video guide — `https://help.runwayml.com/hc/en-us/articles/39789879462419-Gen-4-Video-Prompting-Guide`, and Gen-4.5 examples `https://help.runwayml.com/hc/en-us/articles/47313504791059-Camera-Terms-Prompts-Examples`.
3. Google DeepMind Veo prompt guide — `https://deepmind.google/models/veo/prompt-guide/`; verify model-specific modes through official API documentation, not marketing pages.
4. User-submitted content with explicit non-exclusive reuse and edit license, plus an accessible withdrawal pathway.
5. Third-party official feeds or partner APIs **only when their ToS grant automation and republication rights**.

**Do not deploy** blind scraping/circumvention, extract videos by bypassing website controls, crop out watermarks, or clone complete public prompt collections. External search discovery and importing approved material are separate steps.

## Admin-only ingestion pipeline (future PHP/MySQL backend)

`source_registry` (source ID, API/feed URL, allowed hosts, terms URL, polling limit, content scope, last checked, status); `ingest_candidate` (source URL, source content hash, claim of authorship, published at, discovery timestamp, media URL, exact prompt? boolean, proposed model, moderation state); `rights_clearance` (asset/prompt license IDs, permission evidence, effective dates, attribution required, revocation status); `templates` (owner, prompt provenance, model profile revision, publish status, tags, actor placeholder definitions, audience scope, immutable version, approved by); `media_assets` (storage key, sha256, MIME, file size, virus scan, license, approved delivery URL); `audit_log` (actor, action, old/new hash, IP redaction, timestamp).

Cron job schedule for shared hosting: every 30–60 minutes **only for allowlisted sources**; respect rate limits and 429/Retry-After; acquire a MySQL lease to avoid duplicate concurrent polls, use cursor/high-water mark and exponential backoff. Normalize records; hash deduplicate by original URL + media hash + normalized prompt hash; reject absent rights; queue for human review; publish only after approval. Disable/revoke immediately on rights withdrawal. Never treat AI-generated prompt guesses as original captions.

Security: server-side secrets encrypted at rest, admin auth + TOTP/WebAuthn/passkeys where supported, recovery codes, secure HttpOnly SameSite cookies, CSRF protections, RBAC, scoped expiring tokens, rate limits, hardened uploads, URL-fetch SSRF allowlist with DNS/IP validation on each redirect, prepared queries, output escaping, CSP and audit trails. Shared Namecheap hosting should serve only static frontend and supported PHP/MySQL services; intensive media render, queues and AI proxy require separate suitable compute as scale grows.

## Model truth / affordability

The live model catalog must come from server-approved provider adapters and versioned metadata. Demo model labels are *illustrative*, not actual costs. Real duration, output formats, reference limits, cost, commercial permissions and face-continuity controls can differ per model and over time. Never claim universal support or “best price” without comparable verified quotes.

## Delivery gates

- Phase 1: locally authored seed templates, gallery search/filter, **Use this prompt** to scene draft with model hint and Actors.
- Phase 2: responsive browser gallery and local video editor; usable Namecheap static files; admin security specification.
- Phase 3: server-admin installer, authenticated model catalog, moderated uploads and manual publish/unpublish, user accounts/2FA.
- Phase 4: permissioned source connectors, scheduled ingestion and moderation notifications.
- Phase 5: paid model adapters, secure AI gateway, reliable generation billing, actor reference controls and editing integration.

Every phase requires test results, security review, and a release note. Never merge incomplete API credentials into Git.

## Provenance contract for public entries

The v1 JSON catalog is first-party editorial prompt text only. Each entry carries a `provenance` record with creator, source URL (nullable for first-party text), prompt origin, reuse scope, evidence note, attribution requirement/text, media license, embed permission, and last-verified date. The mobile and browser clients reject approved entries that lack this record. Both show HOTICE credit and the reuse scope. Current entries have no preview media, no third-party prompt text, and no embed permission. Do not convert a source discovery into a public entry automatically.

For future partner/community records, keep the canonical source URL, creator identity, exact-versus-adapted prompt status, prompt rights, media rights, allowed distribution/embed method, required credit, evidence reference, expiry/withdrawal status, approver, and verification timestamp. Public display must show credit required by the license/player. Keep source evidence and takedown details in the admin record. A source page being public, or an embed control being available, is not by itself permission to republish its prompt, thumbnail, video file, or adapted copy.

## Official-source research (checked 26 October 2026)

- [Google Flow FAQ](https://labs.google/fx/tools/flow/faq) describes Flow TV as a place to watch curated clips with prompts. Treat it as discovery and model-specific inspiration; verify each prompt's reuse rights and each clip's embedding permissions separately. Do not bulk copy the gallery.
- [Runway Text-to-Video Prompting Guide](https://help.runwayml.com/hc/en-us/articles/42460036199443-Text-to-Video-Prompting-Guide) and [Runway Introduction to Prompting](https://help.runwayml.com/hc/en-us/articles/47313698911891-Introduction-to-Prompting) publish instructional examples. Use them as references for HOTICE-authored guidance; don't mirror their example collection as HOTICE templates.
- [YouTube's embedding instructions](https://support.google.com/youtube/answer/171780) require using the platform's embed code and remain subject to the YouTube API terms and developer policies; some videos disable embeds. Do not download, rehost, hide player branding, or strip attribution. An enabled embed is not permission to copy its prompt or preview image.
- [Vimeo's embed instructions](https://help.vimeo.com/hc/en-us/articles/12426259908881-How-to-embed-my-video) describe owner-controlled embed privacy, including Anywhere/Nowhere/domain restrictions. Respect the selected setting and recheck it before publication.

Release decision: publish original HOTICE procedural motion studies with explicit “concept, not AI output” disclosure. Keep third-party examples out until each item passes documented rights and player checks. Searchable prompts and motion visuals must never imply HOTICE generated AI output when it did not.

## Namecheap-compatible admin and provider gateway (planned)

Deploy the public gallery as static HTML/CSS/JavaScript under `public_html`; keep PHP application code, environment configuration, provider secrets, private source evidence and uploaded originals outside the web root. Use a same-origin HTTPS PHP API on a configured Namecheap Shared Hosting/cPanel account with MySQL/MariaDB for account, template, rights, moderation and audit records. Confirm the actual plan's PHP modules, database limits, cron availability and upload limits before installing. The current repository contains no admin, API endpoint, database schema migration, credential store, user authentication, or provider integration.

The PHP admin should use named roles (reviewer, publisher, admin), MFA for privileged accounts, secure session cookies, CSRF tokens, password hashing, rate limits, prepared statements, HTML escaping, audit records, and manual two-person review for uncertain reuse rights. Public clients may only read published, unexpired records and submit a prompt-draft request; they must never be able to change model credentials, moderation state, price, provider, or template rights.

The planned API proxy should expose narrow versioned routes such as `GET /api/v1/catalog`, `POST /api/v1/drafts`, and (only after a later provider launch) `POST /api/v1/generations`. Authenticate and authorize every request; validate model IDs, compatible settings, asset types and size server-side; apply per-user quotas and idempotency keys; calculate prices from the server catalog; require explicit paid-job confirmation; log redacted request/response metadata; and return provider job IDs without revealing secrets. Provider adapters are allowlisted server code; the proxy must never accept a client-supplied arbitrary upstream URL or provider key. Store secrets outside `public_html`, encrypt at rest where available, restrict file permissions, rotate keys, and keep staging and production credentials separate. Use signed short-lived uploads and verify webhooks before crediting or completing a job.

For scheduled ingestion, prefer provider-approved APIs/feeds or creator submissions that explicitly grant the required rights. Shared-hosting cron should be a low-frequency allowlisted poller that only queues candidates for human review; it must not spider public websites, evade access controls, scrape videos, or auto-publish. Namecheap states that shared-host cron intervals below five minutes and more than five simultaneous cron jobs are disallowed, and its shared-hosting AUP prohibits web spiders/indexers. Start at 30–60 minute intervals only where source terms permit; run media processing and larger queues on a separate worker rather than a shared-host daemon. Store source/media/prompt hashes for deduplication and preserve an immediate unpublish/takedown path.

Namecheap references: [shared-host cron policy](https://www.namecheap.com/support/knowledgebase/article.aspx/1212/22/do-you-allow-cron-jobs/), [cron setup guide](https://www.namecheap.com/support/knowledgebase/article.aspx/9453/29/how-to-run-scripts-via-cron-jobs/), and [hosting acceptable-use policy](https://www.namecheap.com/legal/hosting/aup/). These are hosting capability constraints, not a confirmation of HOTICE deployment or legal advice.
