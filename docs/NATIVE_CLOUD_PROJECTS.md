# Native project cloud copies

Android, iOS and Flutter desktop clients use the same authenticated, versioned project API as the HOTICE web client. The device archive remains the source of truth while offline. Cloud operations are explicit actions in **Account → Optional project cloud copy**; HOTICE does not background-upload projects.

## User flow and consent

1. The user signs in through the shared HOTICE account API and chooses a UUID-backed project from the current local workspace.
2. Before the first upload or each update, a confirmation explains what leaves the device.
3. The app sends only the selected project document. The private device archive remains available offline.
4. The user can refresh the account's cloud project list, restore a project to another device, replace a local project after an additional confirmation, or delete only the cloud copy.

The synced document includes the project title and creation time, scene prompt/settings, storyboard text, Actor display labels, and requested attachment roles. It excludes other local workspaces, raw media bytes, reference filenames/metadata, and private Actor identity notes. Media must be selected again on a device before any workflow that needs those local files. Account entitlement is enforced by the server.

## Contract

All calls use HTTPS and the OS-protected account bearer token:

- `GET /v1/projects` lists the authenticated account's cloud copies.
- `GET /v1/projects/{uuid}` fetches one copy for explicit restore.
- `PUT /v1/projects/{uuid}` creates or updates a copy using `{ title, expectedRevision, document }`.
- `DELETE /v1/projects/{uuid}` removes only the authenticated account's cloud copy and its cloud media; it does not delete local project data.

The server is authoritative for identity, project ownership, entitlement, request validation and optimistic revision checks. The client persists the last acknowledged cloud revision inside its encrypted local project archive. New projects use revision `0`. Updates use the last acknowledged revision; if a newer or deleted remote revision is observed, the client stops and asks the user to restore/review rather than silently overwriting or recreating cloud data. Concurrent updates are rejected by the server's `expectedRevision` check.

The client never puts credentials in a URL, logs, a project document or an exported project. A missing/invalid secure session fails closed. Network or service errors leave the local archive intact. Cloud list access requires the same entitlement as other cloud reads; deletion remains a server-authorized data-management operation.

## Limits and release gates

- Cloud copies are snapshots written only when the user confirms. Automatic background sync and three-way merge are not implemented.
- Source media and generated outputs are not transferred by this project snapshot flow. Their lifecycle uses separate upload/access APIs and requires a media-consent workflow.
- The UI reports server conflicts and preserves the local project; users can restore a remote revision explicitly. A full visual diff/merge editor remains future work.
- Live hosting, cPanel staging/restore, production malware scanning, real provider integration, store-signed builds and supported-device acceptance remain separate release gates. This feature does not make HOTICE production-ready.

## Verification

`flutter test` covers authenticated API paths/revision payload, missing-session rejection, single-project payload privacy, local archive revision persistence, import isolation, project-specific consent/cancel, and conflict behavior. CI remains the authoritative Android emulator/APK check for each proposed commit.
