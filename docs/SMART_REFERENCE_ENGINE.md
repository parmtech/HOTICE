# HOTICE Smart Avatar & Reference Engine — implementation status

**Date:** 4 November 2026
**Feature branch:** `feat/avatar-reference-workspace-key-separation` (child of portable actor backup PR #87)
**Status:** Offline planner + Android/iOS live guided 2D capture, workspace-derived encrypted image blobs, v2→v3 lazy ciphertext migration, encrypted device-local archive metadata, and user-managed encrypted actor export/restore implemented in source; NOT a 3D reconstruction, liveness/biometric identity verification, cloud media sync, or connected AI generation adapter. Live camera, file-picker, and physical-device migration behaviour await field testing.

## Live camera capture added 28 October 2026

- `lib/src/live_face_capture.dart`: on-device Camera2/NV21 on Android or BGRA on iOS, ML Kit face detection, yaw/pitch/roll guidance, face count/framing, front-view eye-open checks, sampled exposure/detail heuristics and three good frames required before automatic still capture.
- After each shutter, reruns ML Kit on the actual captured still and rejects missing/multiple faces or front-view closed eyes.
- Capture requires explicit consent; the camera plugin creates one transient raw still which is immediately validated, encrypted with AES-256-GCM, copied to app-private support storage, and deleted before the next capture. The five encrypted photos are added to the chosen Actor reference pack only after confirmation. Cancelling, retaking, removal, and app-start cleanup remove HOTICE-owned files where possible.
- Imported JPG/PNG/WebP face photos are copied into the same encrypted device vault after file-signature and size checks; the user's source file is not modified and the known file-picker cache copy is deleted immediately after use. AES-GCM authentication binds each encrypted blob to its format version, stable workspace identity, and reference ID, so moving a blob across workspaces or records fails authentication. An OS-held device root key derives a separate HMAC-SHA256 workspace key. Existing v2 blobs decrypt only in the original workspace, then migrate atomically to v3 on first access; a retained backup allows recovery after interrupted replacement. If an encrypted blob exists but its root key is unavailable, the vault fails closed and leaves the blob intact.
- The reference index and ownership metadata persist in the encrypted device-local project archive. Media uses a workspace-derived key from the device-held root key; the files are not backed up or synced, and clearing or losing the OS key makes them unreadable. Workspace separation protects records on one installation; it does not protect against a compromised device or OS key store.
- Avatar Studio performs a best-effort cache sweep on entry: abandoned HOTICE scanner batches and raw stills matching the pinned Android/iOS camera plugin's exact generated names are removed after an app restart, while encrypted paths still referenced by restored local archive records are preserved. The sweep leaves unknown files, links and nested content untouched.
- Camera lifecycle pause/resume handling, streaming throttling, capture reentrancy guard, retries and user-controlled yaw mirror reversal. No selfie audio.
- Prominent Live face capture tab in Avatar Studio, with a character selector, separate from the original nonfunctional 3D scan guide.
- `tools/configure_face_capture.py`: idempotent Android permission and iOS 15.5 camera/privacy configuration after ephemeral Flutter scaffold generation.
- Unit tests cover eye-open and pose gates, poor framing, lighting and three-frame stability. CI and device results must be checked per commit.

**Do not call this full 3D scanning.** ML Kit face detection estimates pose and face features, not an accurate textured 3D reconstruction or identity guarantee. Image sharpness/exposure heuristics are not calibrated across device cameras, and selfie yaw may need inversion.

## Implemented in this branch

- `lib/src/smart_references.dart`: typed `AvatarReference`, `AvatarAssetPack`, `ReferenceModelCapability`, `SmartReferencePlanner`, and immutable selection output.
- Explicit face-reference image import (JPG/PNG/WebP under 15 MB) from Avatar Studio, manually tagged front, 45°, profile, up and down.
- User-controlled password-encrypted actor backup export/restore (`.hoticeactor`) preserves actor notes, image MIME and face-view labels. The versioned AES-256-GCM envelope derives its key with PBKDF2-HMAC-SHA256 (180,000 rounds), uses a fresh salt/nonce, and validates photo signatures/count/size before restore. Passwords and device paths are not included. Restore stages ciphertext in the device vault before adding actor metadata as one store event, waits for the encrypted project archive to report a saved snapshot, and removes both staged metadata and ciphertext on failure. Rollback targets the original workspace if the user switches accounts mid-restore. Plain photos remain in memory during restore; no plaintext staging file is written.
- Avatar reference metadata is saved with the encrypted local workspace archive and scene image metadata is project-scoped. Archive restore validates UUID ownership and vault path suffix before reattaching records. Avatar rename migrates reference ownership; deleting an avatar or project removes the metadata in that workspace.
- Normal Video composer: select Actor, import location/prop/style photos, auto-plan from camera direction in one free-text prompt, manual selection, pin/clear references and inspect preview/warnings.
- The planner prefers scene-compatible angle, normally at most two automatic avatar images, then leaves room for location/objects.
- Models can be described with verified formats and numeric attachment/mesh limits. **Current demo models provide ONLY explicitly unverified simulated limits**; no generation API is called.
- Native GLB asset selection **inside the planner only** if a verified model capability enables it and a real GLB record is supplied. **No GLB generation, face scan or upload is implemented.**
- Invalid locks, missing/duplicate IDs, wrong avatar owner and unconsented identity references are errors, not silent substitutions.
- Draft stores an immutable ID snapshot; it does NOT upload photos or perform identity recognition.

## Important limitations

The avatar reference index and ownership metadata are persisted in the encrypted local project archive with workspace and project records. The photo ciphertext is separately held in private app storage under workspace-derived keys rooted in an OS secure-storage device key. Decryption reads are capped at the 15 MiB image limit plus envelope overhead before rejecting oversized files. This is cryptographic separation between workspaces on the same installation, but not against device compromise, root-key theft, or malware with app access. The `.hoticeactor` file is an optional user-managed encrypted export that can be restored on supported Android/iOS installs; HOTICE does not store the password or provide cloud backup. Losing both the original device key and the backup password makes that copy unrecoverable. Portable restore and v2→v3 migration have local unit coverage but still need physical-device QA (picker/save-dialog behavior, interruption, low storage and account switching). Manually imported photos are **not** quality-assessed or converted to 3D. The live scanner uses ML Kit face detection and open-eye checks, but this is neither biometric identity validation nor anti-spoof liveness detection. Do not label either capture method a 3D mesh scan.

Four image slots in `ReferenceModelCapability.demo` are a **UI simulation**, not an official provider capability. No model adapter should read the demo limits as true. Neither the backend nor real generation endpoint currently accepts these reference plans. The planner's `canSubmit` is false for unverified profiles. No vendor input is silently inferred from the extension.

A production implementation must separately verify the server's account authorization, consent, byte size, MIME-by-file-signature, media ownership, model capabilities, pricing/entitlement, expiry and model provider API specifics. A front camera image cannot be claimed to provide a high-fidelity 3D head mesh without reconstruction and quality validation.

## Next implementation sequence

1. Validate guided capture and portable actor backup on physical Android/iOS devices (native orientation, ML Kit yaw, eye confidence, lighting, autofocus, repeated sessions, picker/save-dialog behavior, interruption, permission rejection, foreground/background, temporary-file deletion); calibrate pose/blur heuristics. Camera2 is preferred on Android for NV21 compatibility.
2. Validate v2→v3 media migration and workspace key separation on physical Android/iOS devices. The app now explains missing-key recovery during backup/import and links to existing reference deletion controls; complete an all-workspace purge/recovery flow, then confirm deletion and retention behavior on real devices.
3. Multi-view reconstruction pipeline with transparent confidence and RGB-photo fallback; actual GLB/GLTF export and photorealistic side render derivation.
4. Signed, least-privilege optional paid-cloud sync through Namecheap cPanel PHP/MySQL backend; secrets always server-side, opt-in for facial data.
5. Verified/versioned per-provider catalog served by backend with reference type/size/count semantics, server-side attachment packer and safe transforms. No fake 3D handling.
6. Real-generation API tests: identity stability across angles, skin details, clothing/scene/style limits, multi-character cases, unsupported formats and cancellation.
7. Flutter CI, Android APK and real-device testing including file permission/cancel/reopen and temporary file lifecycle.

## Data and privacy contract

- Model response/prompt includes *no local file path*, biometrics, or raw face embedding.
- User manually locked attachments are never swapped without an explicit error.
- All identity media requires explicit user action/consent; real biometric capture needs a stronger capture-specific consent and deletion workflow.
- Do not persist a profile's references to another demo account.
- Model price remains unavailable, not free, until verified and configured. One HOTICE Credit remains USD 0.01.
- HOTICE is the product brand; keep the single prompt field and the existing Normal Video / Music Video Studio workflows.
