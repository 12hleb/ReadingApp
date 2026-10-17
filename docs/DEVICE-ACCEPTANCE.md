# Device acceptance checklist

Record actual results rather than checking these boxes based on source review.

- Xcode version: __________
- SDK version: __________
- iPhone model: __________
- iPhone OS version: __________
- Simulator/runtime used for automated tests: __________
- Test date and tester: __________

## Build and persistence

- [ ] Open the project, configure signing, build without errors, and run all XCTest cases.
- [ ] Create a book with a typed title and no cover.
- [ ] Photograph a cover; verify title OCR and manually correct the title.
- [ ] Choose an existing Photos image, including a rotated image and an iCloud-only photo.
- [ ] Cancel the camera and the Photos picker without creating a book.
- [ ] Relaunch: title, cover, entries, context, dates, and edited translation persist.
- [ ] Save the same phrase twice in one book: one entry remains and edits are preserved.
- [ ] Save the phrase in a second book: it appears separately.
- [ ] Search English, Russian, and sentence text; verify no-results state.
- [ ] Delete one entry; verify its book remains.
- [ ] Delete one book; verify only its vocabulary and cover are removed.

## Camera, geometry, and selection — physical iPhone required

- [ ] First-time permission, denial, Settings grant, and restricted access produce useful UI.
- [ ] Live preview is upright with correctly placed word boundaries.
- [ ] Freeze a page: image and word boxes match, camera indicator turns off.
- [ ] Tap near each edge/corner of the frozen image and verify the correct word.
- [ ] Drag left-to-right, right-to-left, and across two lines; check reading order.
- [ ] Tap empty space: selection clears and an old translation cannot be saved.
- [ ] Scan Again restarts camera capture and clears previous selection/translation.
- [ ] Rotate the phone: the portrait UI, pixels, and overlay stay aligned.
- [ ] Background and foreground the app in live and frozen modes.
- [ ] Interrupt capture (another camera use or system interruption), then recover with Retry.
- [ ] Try a dim page, glare, small type, curved page, and no text; check guidance and recovery.
- [ ] Scan repeatedly for five minutes; assess heat, battery, memory, and responsiveness.

## Translation — physical iPhone required

- [ ] With language models absent, Apple shows the download prompt; allow download.
- [ ] Cancel the download and confirm a clear retry action.
- [ ] Translate a single word and a phrase into Russian.
- [ ] Change selection quickly; original text and translation always match.
- [ ] Save while translating: button is disabled.
- [ ] Repeat a completed selection: cached translation appears.
- [ ] After model installation, test airplane mode and relaunch.
- [ ] Verify a failed translation cannot be saved as a completed vocabulary entry.

## Interface and fixture

- [ ] Run Try Sample Page in simulator and on device; verify real OCR returns selectable words.
- [ ] Test both a small and a large iPhone simulator display.
- [ ] Test light/dark appearance and accessibility text sizes.
- [ ] Use VoiceOver to add a book, open an album, choose text with the word pickers, translate, and save.
- [ ] Dismiss/reopen the translation sheet; current selection and completed translation remain usable.

No items were marked complete in the Linux implementation environment.
