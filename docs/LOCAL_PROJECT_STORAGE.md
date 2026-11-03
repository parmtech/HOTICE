# HOTICE device-local project storage

The Flutter app stores small project snapshots in the operating system's
application-support directory. The snapshot is encrypted with AES-256-GCM;
the 256-bit key is stored separately through `flutter_secure_storage` using the
platform keystore/keychain. The archive uses a versioned JSON envelope and
keeps the previous authenticated snapshot as a recovery copy. Writes are
serialized so rapid edits cannot reorder the saved snapshots.

Snapshot schema 2 uses separate local keys for demo profiles and authenticated
accounts. Authenticated workspace keys derive from the server's immutable user
ID; the current email is only a display label. A later email change therefore
continues to select the same local projects. The ID is stored only inside the
authenticated encrypted archive, and restoring that archive never restores an
authenticated session or grants cloud access.

Schema 1 snapshots used email keys. Migration retains those workspaces as local
demo profiles and does not silently claim or merge them into a server account.
Their projects remain available by switching to the matching local profile.
There is no automatic project upload or account transfer during migration.

While signed into an authenticated account, the Accounts page can explicitly
copy one eligible UUID project from a saved local profile into the current
account's encrypted device workspace. The confirmation names the source and
explains what is copied: prompts and generation settings, storyboard text,
Actor names/identity notes, and reference-file metadata. Media bytes and pending
generation attempts are excluded. The copy gets a new UUID; matching Actor
profiles are reused only when their style and identity notes also match, while
name collisions create a clearly suffixed local profile. The source and its
cloud revision state remain unchanged. This action makes no network request;
cloud save remains a separate explicit action. A copy that exceeds the archive
limit is rolled back in full.

The snapshot contains project titles and dates, actor names and identity notes,
scene prompts and settings, reference-file metadata, storyboard text, and local
appearance settings. It does not contain API credentials, server session
tokens, subscriptions, credits, or raw image/audio/video bytes. Media-file
storage and restoration are separate work and are not implemented by this
archive. The archive is limited to 2 MiB of clear project metadata.

If the key is missing or neither the primary archive nor its recovery copy can
be authenticated, HOTICE stops before opening the studio and leaves both files
untouched. It does not create a replacement key or silently initialize an
empty workspace over unreadable data. This protects against accidental data
loss, but it does not provide cross-device backup or key recovery. Device
backup/restore behavior must be validated on each supported OS before release.

During normal studio use, the app shows whether the latest local snapshot is
saving, saved, or could not be saved. A failed write offers a retry of the
latest complete snapshot and explains that the prior saved version is
protected. It never falls back to plaintext. Successful retry clears the
warning; the archive queue remains ordered so an older write cannot replace a
newer snapshot.

This local archive is independent of cloud sync. Cloud upload remains an
explicit, revocable operation and requires server authorization. A local
snapshot is not a server account, cloud entitlement, or backup guarantee.

## Validation

Run the archive-focused suite with:

```sh
flutter test test/local_store_test.dart
```

The tests cover encrypted restart restore, stable account-ID rebinding after an
email change, encrypted schema 1 migration, demo/account isolation, all
persisted scene draft settings, recovery from a damaged primary file, and
fail-closed behavior when the device key is wrong. Profile-copy tests cover
identity remapping, source preservation, excluded cloud retry state, rejection
of ineligible source/destination workspaces, zero API traffic, and complete
rollback when a copy would exceed the 2 MiB archive limit. Physical-device
keystore backup and restore acceptance remains a release gate.
