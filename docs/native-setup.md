# Native setup and architecture

## Toolchain

- Node 24, npm with package-lock.json, Expo SDK 55, React Native 0.83.
- iOS: macOS, an Xcode version supported by Expo SDK 55, CocoaPods, an iPhone,
  and development signing. The generated Expo project sets its supported deployment
  target. Apple Vision is a system framework; no extra OCR model download is needed.
- Android: JDK 17, Android Studio SDK/build tools matching the generated Expo
  project, and a USB-debuggable device. Google Maven provides
  `com.google.mlkit:text-recognition:16.0.1`, including the offline Latin model.
- Camera permission is configured by the expo-camera plugin. No microphone permission
  is needed. Native folders are generated/ignored; native OCR sources are committed
  under modules/reading-ocr and discovered by Expo autolinking.

Run `npm ci`, then `npm run ios -- --device` or `npm run android -- --device`.
After native module changes, rebuild the development client. For ordinary TS edits,
start Metro with `npm start`. Expo Go cannot execute the OCR module. SDK generation
can be checked without a compiler with `npx expo prebuild --no-install`; this does not
compile native code. Do not use `--clean` on native directories containing local edits.

## Cloud workflow

Use the existing `/workspace/ReadingApp` checkout; do not create a worktree.
The sandbox uses a writable npm cache outside the checkout:

```sh
npm --cache /workspace/.npm-cache ci --no-audit --no-fund
npm run check
EXPO_NO_TELEMETRY=1 EXPO_OFFLINE=1 npx expo install --check
EXPO_NO_TELEMETRY=1 EXPO_OFFLINE=1 npx expo export --platform ios --platform android
XDG_CACHE_HOME=/workspace/.cache EXPO_NO_TELEMETRY=1 EXPO_OFFLINE=1 npm start -- --localhost --port 8081
```

Offline Expo mode uses the compatibility table bundled with the installed SDK and
avoids blocked Expo API lookups; npm downloads still use normal TLS/checksum checks.
If downloading the latest React Native DevTools is blocked, Expo uses its bundled
fallback. This does not prevent bundling. Metro's `/status` should return `packager-status:running`, and an internal request for
`/index.bundle?platform=ios&dev=true&minify=false` should produce the JavaScript bundle.
No mobile preview is supplied by this cloud environment. Run Metro locally on the
workstation for a physical device, or configure an appropriate reachable dev server.
Live processes do not survive environment publication; restart Metro when needed.

Required package destinations are supplied by the package-manager network preset.
MyMemory translation requires HTTPS access to `api.mymemory.translated.net`.
Mobile connectivity is separate from cloud egress settings. Expo/EAS cloud building
is optional and requires an Expo account; no signing credentials are requested here.

## Separation of responsibilities

- `src/core/ocr.ts`: engine-independent geometry normalization; never manufactures
  word boxes when an engine supplies no word coordinates.
- `src/core/geometry.ts`: contained image fitting, image/display/touch conversion,
  pixel-to-screen scaling, pan/zoom offsets, polygon distance hit testing.
- `src/core/selection.ts`: anchor/endpoint contiguous selection and reconstruction.
  Ambiguous visible line-ending hyphens are retained; only explicit soft hyphens
  within a block are joined. Native OCR reading order is retained, so complex
  columns, skew, punctuation, and word boundaries need physical-page validation.
- `src/core/reader.ts`: screen state and operation identity. Selection and English
  edits abort/invalidate old translations. Capture/OCR/save prevent conflicting work.
- `src/services/native.ts`: upright full-resolution image, native OCR, network status,
  cache cleanup, and the Expo SQLite adapter.
- `src/services/translation.ts`: explicit HTTPS text-only translation, cancellation,
  timeout, quota/status validation, configurable source/target language parameters.
- `src/core/storage.ts`: books and vocabulary with foreign keys, timestamps, language
  codes, per-book normalized duplicate detection, and transactional insert.
- `src/components`: CameraPreview, CapturedPageViewer, OCRWordOverlay,
  TranslationPanel, SaveVocabularyAction. Viewer uses the independent
  TextSelectionController. Gesture cancellation restores the prior entry, and
  two-finger gestures do not finalize a text selection.

## Screen states

Camera permission controls CAMERA_READY / CAMERA_PERMISSION_DENIED. Capture enters
CAPTURING → OCR_PROCESSING → PHOTO_READY. Selection enters SELECTING → TEXT_SELECTED.
Translate enters TRANSLATING → TRANSLATED or TRANSLATION_ERROR; retry preserves
English. Save enters SAVING → TRANSLATED or SAVE_ERROR. A successful save keeps the
page frozen. OCR failure retains the image and exposes manual entry/Retake. Permission
denial still permits manual entry. Retake clears page-specific state and cached images,
never SQLite vocabulary. Translation identity, selected word IDs, original/translated
text, page metadata, and book ID are stored separately.

## Validation limits

Cloud tests exercise the production repository SQL against Node's real file-backed
SQLite implementation, closing/reopening the database. They do not substitute for
Expo SQLite integration on a phone. JS exports and autolink resolution do not compile
Swift or Kotlin. Native compilation, actual OCR output, EXIF/device orientation,
gesture arbitration and memory behavior must be confirmed with native builds.

## Live Camera milestone

No frame OCR is shipped or represented as complete. After Photo Mode acceptance,
add a native frame processor with a controlled recognition interval; keep frame,
orientation, and word snapshot atomic. Lock the corresponding image on interaction,
reuse the selection and translation layers, and offer explicit Resume Camera.
Never overlay a newer OCR result on a locked older frame. Expo Camera photo capture
is not a live-frame processor and must not be relabeled as one.
