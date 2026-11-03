# HOTICE browser editor: local video export

## User workflow

1. Import video clips with the editor's file picker. Files are represented by local browser object URLs; the editor does not upload them.
2. Select clips, reorder them, set trim points and playback speed, and preview the sequence.
3. Choose 720p (recommended) or 1080p, then choose **Export video**.
4. Keep the tab open while the sequence is recorded. Export can be canceled without changing source clips. When it is ready, choose **Download exported video**.

The export uses the first playable clip's aspect ratio. Other clips are scaled to fit against a black background, without cropping. The canvas produces video at 30 frames per second; the selected resolution controls the short edge for ordinary landscape and portrait footage. Source audio is passed through a browser audio graph along with the rendered video.

## Safety, limits and recovery

- The export uses the browser's Canvas Capture, Web Audio and MediaRecorder APIs. It makes no HOTICE API request and no provider call.
- Supported container/codec is selected from formats reported by the current browser. The download extension follows the resulting MIME type; Chromium CI currently verifies WebM. Other browsers and device hardware encoders still need their own acceptance runs.
- A file must expose a finite, readable duration before trimming or export is enabled. Some browser-created or malformed WebM files report no finite duration; the editor explains how to recover by re-exporting the source in a standard format.
- An export is limited to five minutes to bound browser memory use. The browser tab must remain open and active enough to continue playback; suspend, device sleep, decoder failure or exhausted memory can interrupt recording.
- The export is held as a temporary browser object URL until a replacement export succeeds or the page closes. Download it to keep it. It is not added to a project archive or cloud copy.
- Errors and cancellation retain the original imported files and any prior completed export. Failed partial recordings are never offered as downloads.

## Verification

`tools/e2e_web_project_sync.cjs` uses a checked-in synthetic color-pattern WebM fixture with a generated 440 Hz tone. The Chromium test imports it, waits for decoded duration, records and downloads a local export, verifies playable video and non-silent audio, cancels a later export without losing the completed file, and asserts that no HOTICE API request occurred during either export.

This proves the exercised Chromium path only. It does not prove Safari/WebKit, Firefox, iOS/Android browser support, large-media performance, hardware encoder availability, professional mastering quality, cloud export, or server-side rendering. Keep production export claims scoped to browsers/devices that pass the release matrix.
