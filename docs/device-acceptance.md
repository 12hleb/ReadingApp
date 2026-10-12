# Device acceptance — not yet run

Run with a real printed English book, a smaller-screen iPhone, and an Android phone.
Record OS/device/build, page photo characteristics, results, and failures. These
checks are pending; automated logic tests do not mark them passed.

- [ ] Compile and launch native development builds on both platforms; verify local OCR autolinking.
- [ ] Create two albums and enter the camera from each; header and saves keep the active book.
- [ ] Deny camera permission; manual entry works. Grant permission via Settings; camera recovers.
- [ ] Capture portrait and landscape pages; native OCR returns correctly located words.
- [ ] Tap one word; highlight aligns and English fills without adjacent words.
- [ ] Drag just “strangely exhilarating” from a longer sentence in both directions.
- [ ] Drag across a line wrap; natural order and punctuation remain correct.
- [ ] Move through nearby whitespace without jumping to distant text or columns.
- [ ] Pinch/zoom and pan at image edges; highlights stay aligned and no unwanted selection finalizes.
- [ ] Begin a gesture in blank space; it pans. Change from selection to two fingers; previous entry survives.
- [ ] Rotate the phone after capture; fit/touch mapping still agrees with highlights.
- [ ] Capture a blank or poorly lit page; no-text recovery says “No text detected. Try another photo with better lighting.”
- [ ] Exercise an OCR failure; captured image and manual-entry/Retake recovery remain usable.
- [ ] Edit English after translating; old Russian clears. Edit while a request is pending; stale response is ignored.
- [ ] Translate using real MyMemory response, edit/copy both fields, and save.
- [ ] Disable internet; original stays intact and the requested offline message appears. Reconnect and retry.
- [ ] Exercise provider timeout/error/quota; no fake translation or success appears.
- [ ] Double-tap Save; only one entry. Reselect an existing phrase; duplicate prompt supports cancel or intentional copy.
- [ ] Save two entries from one photo; neither action requires reopening the camera.
- [ ] Retake or navigate back with unsaved edits; warning appears. Saved entries survive.
- [ ] Return to each album; entries belong to the correct book. Kill/reopen the app; entries persist.
- [ ] Collapse panel and use keyboard on a small screen; page selection remains available.
- [ ] Enable large system text and VoiceOver/TalkBack; labels, controls, copying/manual entry are usable.
- [ ] Repeated capture/retake/back cycles release camera/OCR resources and cached images; profile memory.

Photo Mode acceptance is pending all relevant device checks. Live Camera is an
unimplemented second milestone and has no passing acceptance claim.
