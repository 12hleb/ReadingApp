# Reading Translator

An Expo / React Native app for photographing English book pages, selecting words,
translating phrases into Russian, and keeping vocabulary in a book album.

Photo Mode is implemented in source and ready for native/device validation. It is
**not yet accepted against real physical pages**. Live Camera frame OCR and locked
frame selection are **not implemented**; the preview is explicitly Photo Mode.

## Develop

Use Node 24 (the tests use Node's SQLite driver), npm, and the committed lockfile.

```sh
npm ci
npm run check
npm start
```

A **native development build is required**. Expo Go and the browser do not include
the local `ReadingOCR` module. Build on a workstation with the appropriate SDK:

```sh
npm run ios -- --device      # macOS, Xcode, CocoaPods, signing for a physical iPhone
npm run android -- --device  # Android Studio SDK, JDK 17, connected Android device
```

The cloud checkout supports TypeScript, linting, tests, and Metro bundling. This
Linux environment has neither Xcode nor an Android SDK/device; JavaScript exports
are not evidence of a successful native build or camera operation.

## Workflow

1. Create a book album and choose **Read with camera**.
2. Enable the rear camera and capture a page. OCR runs locally.
3. Tap a word or drag through consecutive words in either direction and across lines.
4. Pinch to zoom; drag from blank space to pan. Collapse the bottom panel for more room.
5. Correct the English text, tap Translate, and optionally edit/copy the Russian result.
6. Save to Book. Select another phrase from the same photograph.
7. Return to the album to view entries, including after restarting the app.

English edits invalidate translations; old requests cannot overwrite new text.
Retake and navigation warn before discarding unsaved work. Duplicate entries require
explicit confirmation. Vocabulary is stored in SQLite, not the photo cache.

## OCR and translation

`modules/reading-ocr` uses Apple Vision on iOS and bundled Latin ML Kit on Android.
OCR returns word geometry, engine reading order, and confidence where available.
The original-resolution image is decoded and re-encoded upright before OCR and
display. Highlights and touch hit testing share one image-pixel transform.

`TranslationService` is independently replaceable. The default implementation calls
MyMemory's public HTTPS endpoint for English → Russian. **Only the selected English
text is sent**, on explicit Translate; images remain local. The public service has
provider-controlled quotas, translation quality, and a 500 UTF-8 byte request limit.
No API keys are embedded. A production provider can replace this service without
changing OCR, selection, or storage; credentialed providers should use a backend.
The app does not persist photos or unfinished entries after leaving the reading screen.

## Validation and remaining work

See [native setup and architecture](docs/native-setup.md) and
[device acceptance checklist](docs/device-acceptance.md). Unit tests cover selection,
geometry, OCR failure/empty recovery, translation races/retry, permission denial,
correct book association, duplicate saves, and file-backed SQLite persistence.
Fixtures use a representative printed-page layout; they are not captured OCR results.
Actual camera, native OCR, touch gestures, accessibility, and mobile restart behavior
remain device checks. Do not mark Photo Mode complete until those pass.
