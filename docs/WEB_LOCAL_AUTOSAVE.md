# Browser project auto-save

## Behavior

Auto-save applies after a project has first been created with **Save project** or opened from this device. Changes to its title, scene prompt/model draft, saved scene ideas, Actor names, and timeline edit decisions are written to that browser's IndexedDB after a short quiet period.

The project status reports pending changes, successful local save, or a recoverable storage failure. A failed save keeps the current page state and directs the creator to retry with **Save project**. Opening another project, deleting the active project, or starting its cloud sync flushes pending local edits first.

Auto-save is local only. It does not upload prompts or media. Cloud sync still requires account access, explicit consent, entitlement and a separate project action. Project sync retains optimistic revision conflict handling.

## Media and browser limits

The saved timeline stores clip name/type, order, trim, readable duration and speed. It never stores browser object URLs or video bytes. After a reload, source clips are marked missing; re-importing the same filenames reconnects them. Media remains local to that browser session and must be re-imported after a later reload.

Browser storage can be cleared or evicted by the browser or device. Auto-save reduces the chance of losing recent edits but is not a backup or a durability guarantee. Use the explicit project/cloud backup actions where appropriate. No cross-device synchronization happens automatically.

## Verification

`tools/e2e_web_project_sync.cjs` exercises a saved project's timeline and composer auto-save, waits for the local saved state, reloads the browser and confirms the prompt draft and trim/speed values are recoverable. The same dry run verifies media bytes and URLs remain excluded, media relinking works, cloud sync remains consent-gated and no paid provider call occurs.
