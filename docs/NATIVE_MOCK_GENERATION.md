# Native authenticated mock-generation workflow

## Purpose and honest product boundary

The Flutter client can exercise the server's authenticated asynchronous job queue without claiming to render a video. The workflow is enabled only when an authenticated HOTICE server reports `mockGeneration.enabled: true`. It always uses the fixed `hotice.mock.video.v1` backend model; the in-app model names and capability settings remain illustrative.

The mock provider produces status/result metadata only. It does not call a real video or image provider, upload attachments, create a playable video, or charge money. Any displayed balance/reservation is a server-side simulated-credit ledger with no cash value.

## User journey

1. The authenticated creator opens a project with a personal UUID. Guest/demo-only sample projects cannot start a server request.
2. The creator explicitly checks whether the configured server has mock generation enabled.
3. A clear notice explains that requesting a quote sends only the plain text in **Describe your shot**. It excludes Actor identity notes/names, reference filenames or bytes, media, selected model preview, aspect ratio, duration, seed, negative prompt and audio settings.
4. The creator requests a simulated-credit quote. A quote is short-lived and tied by the server to the authenticated account and exact prompt.
5. Before submission, a confirmation shows the exact prompt and simulated-credit amount. Choosing **Keep local** sends no job-creation request and reserves no credits.
6. On confirmation, HOTICE first stores the request prompt and stable idempotency key inside the encrypted local project archive. Only then does it submit the authenticated mock job.
7. The creator can refresh server job history, cancel a still-queued job (which returns simulated credits), or safely resume an uncertain submission after a restart.

## API contract

- `GET /v1/me`: authenticated capability check and current simulated-credit balance.
- `POST /v1/jobs/quote`: sends `{ request: { modelId, prompt } }`; returns a short-lived signed quote and simulated-credit cost.
- `POST /v1/jobs`: sends the quote and same normalized request with an `Idempotency-Key` header; returns a durable queue record.
- `GET /v1/jobs`: lists the authenticated account's recent job records.
- `POST /v1/jobs/{uuid}/cancel`: cancels only a queued job; the server performs the refund transaction.

The native client never sends the illustrative catalog model ID to the mock route and never puts the account bearer token in a URL. Job ownership, feature enablement, quote validation, idempotency, credit reservation/refund and status authority remain server-side.

## Timeout and duplicate-debit safety

The network can fail after the server commits a job but before the device receives the response. Therefore, each confirmed intent gets one random UUIDv4 idempotency key. The client persists it with the exact prompt, project ID and authenticated server user ID in its encrypted device archive before the POST. It will not retry that intent under a different account, even if the email address is later reused. If the request outcome is uncertain, the intent is retained and the project cannot be deleted until it is resolved.

After restart, **Quote & retry** gets a fresh quote for the saved prompt and resubmits with the same key. The backend checks for an existing account-owned idempotency record before consuming a quote; a replay returns the same job instead of reserving credits again. The intent is removed from local pending state only after a valid job response. Cloud-project snapshots do not include pending idempotency intents.

If the server has not received the first request, a fresh quote with the same intent key can create the job. If the server already has it, the same call returns that job. The client does not automatically retry an ambiguous POST, and never silently creates a new key for that intent.

## Verification and release limits

Flutter tests cover API schema/authorization/header routing, explicit consent, cancellation without job creation, strict prompt-only payloads, simulated credit display, timeout retention, encrypted snapshot restoration, same-key retry and responsive phone layout. GitHub Actions additionally builds the versioned Android APK and runs the Android emulator journey.

These checks prove the mock workflow only. They do not establish real provider/model compatibility, production rates/costs, successful video generation, media upload security, payment billing, production hosting, store signing or release readiness. See GitHub issue #33 for the remaining release gates.
