# SwipeTranslate

A native iPhone app for reading English books and saving Russian translations into book-specific vocabulary albums. Built from scratch with SwiftUI, SwiftData, AVFoundation, Vision, NaturalLanguage, and Apple's Translation framework. No package dependencies, account, API keys, backend, or third-party translation service.

## Version and build status — read this first

The requested device OS is **iOS 26.6.2**, with **Xcode 26.6**. This project sets its minimum iOS deployment target to **26.0** and uses the selected Xcode's `iphoneos` SDK. A minimum of 26.0 permits installation on later iOS 26 releases; it is not a claim of testing on 26.6.2.

The implementation environment is Linux. `xcodebuild`, `xcrun`, Swift, Apple SDKs, and simulator runtimes are absent. The availability of the exact requested Xcode/OS releases could not be verified here. There is no installed compatible Apple SDK to use as a fallback. **This project has not been compiled, run in a simulator, or tested on an iPhone.** Source grammar and project structure checks passed; these do not check Swift types or Apple API availability. See `docs/VALIDATION.md` for the precise results.

## Open and launch on your Mac

1. Copy the whole `SwipeTranslate` folder to your Mac. Install/select Xcode with the iOS 26 SDK (Xcode 26.6 if available).
2. Open `SwipeTranslate.xcodeproj`. There is no dependency installation or project-generation step.
3. Select the **SwipeTranslate** scheme. In the target's **Signing & Capabilities**, select your development team and change `com.example.SwipeTranslate` to a unique bundle identifier.
4. Connect your iPhone, enable Developer Mode if requested, trust the Mac, and select the iPhone as the run destination. Confirm its version under Settings → General → About → iOS Version.
5. Press **⌘R**. Allow camera access when you choose to take a cover photo or start reading.

For a simulator, select an installed iPhone running iOS 26 or newer. Start by creating a book with a typed title; a cover is optional. Open its album → **Start Reading** → **Reader Options (…) → Try Sample Page**. The sample runs real Vision OCR and the same selection code as the camera path. Simulator camera unavailability is expected. Native translation and language resource availability must also be checked on the physical device.

If Xcode reports SDK/toolchain errors, first inspect the selected installation:

```sh
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
```

When multiple Xcode versions are installed, select the intended one in Xcode Settings → Locations → Command Line Tools. Do not mistake a generic iOS simulator build for testing your exact phone OS.

## Build and test

From the project folder on your Mac:

```sh
bash scripts/verify-macos.sh
```

The script records Xcode/SDK/runtime versions, builds for the simulator, chooses an available iOS 26+ iPhone simulator, and runs the hosted XCTest target. Logs and an `.xcresult` bundle go into `build/`. It exits explicitly if the Apple tools or runtime are absent. Use `--build-only` to skip test execution, or choose a specific simulator:

```sh
SIMULATOR_UDID="YOUR-SIMULATOR-UDID" bash scripts/verify-macos.sh
```

In Xcode, **⌘U** runs the same test suite. The 18 tests cover book creation, disk persistence across container reopening, cascade deletion, word deletion, duplicate handling, validation, word ordering, reversed/multiline selection, punctuation and Unicode offsets, crop/letterbox geometry, hit testing, and OCR on the bundled image. Tests do not request camera access or language downloads.

Optional portable project checks (these are not app tests):

```sh
python3 scripts/validate_project.py
# With tree-sitter and tree-sitter-swift installed in a separate Python environment:
python3 scripts/validate_project.py --swift-syntax
```

## Using the app

- **My Library:** Add books and open their albums. Swipe to delete a book, then confirm deletion of its vocabulary.
- **Add Book:** Take a cover photo or choose one with the system Photos picker. Vision suggests a title from prominent text; check or edit it before creating the album. Covers are optional.
- **Book Album:** Start reading, search English/Russian/context text, open entry details, or swipe an entry to delete it.
- **Camera Reader:** Point at a flat, well-lit, single-column English page. Live word boundaries update about once per second. Tap **Freeze Page** to keep the most recent analyzed image, then tap a word or drag through a phrase. Reverse drags and drags across lines select a contiguous reading-order range. The camera stops while a page is frozen.
- **Translation:** A bottom sheet separates the original text from Russian. Apple may ask to download English and Russian language resources. Save a completed translation to the current book. Repeated selections reuse a small in-memory cache; stale results cannot be saved for another selection.
- **Details:** View the surrounding recognized sentence, book, and date; edit the Russian translation or delete the entry. Use **Save Changes** to persist an edit.
- **Accessible selection:** Reader Options → **Choose Text** offers first/last word pickers. Tap **Use Selection**, then **Translate**. This is also useful when the page text is too small for precise touch selection.

## Architecture and decisions

```text
SwipeTranslate.xcodeproj/       App and hosted unit-test targets; shared scheme
SwipeTranslate/
  App/                         Entry point, persistent container, in-memory preview data
  Models/                      Book and SavedWord SwiftData models
  Views/                       Six screens and accessible selection sheet
  ViewModels/                  Library, add-book, and reader state and actions
  Services/                    Camera, OCR, translation, cover files, persistence operations
  Core/                        Reading order, UTF-16 text ranges, geometry, selection
  Components/                  Preview layer, cover picker, rows, selection overlay
  Resources/                   Info.plist, privacy manifest, icon, accent, OCR fixtures
SwipeTranslateTests/           Selection, OCR, and persistence XCTest suites
scripts/                       macOS build/test and portable structural checks
docs/                          Validation record and physical-device acceptance checklist
```

Views observe small MVVM state objects. SwiftData's `@Query` updates the library; explicit repository saves make errors visible. A book owns its vocabulary through a cascade relationship. A saved word has an optional inverse reference to its book. Deleting an entry does not delete its book.

Duplicate checks normalize case, whitespace, diacritics, and surrounding punctuation **within the current book**. Saving a duplicate reports that it already exists and retains any manually edited translation. The same phrase can belong to different books. Store writes roll back on failure. An unavailable database shows a recoverable launch error; it is never silently replaced with an empty library.

Cover JPEGs live in Application Support/Covers, with relative filenames persisted in SwiftData. Absolute paths are avoided because iOS sandbox locations can change. Failed book creation removes its new cover; successful book deletion removes the corresponding cover. Normal iOS backup behavior applies; there is no app-operated cloud sync. Database contents and photos are not sent to a translation endpoint.

The camera has separate serial control and image-processing queues. Vision work is throttled to an interval of at least 0.85 seconds and late video frames are discarded. The rear camera produces upright portrait pixels; both preview and output connections use 90° rotation with mirroring disabled. Vision's bottom-left normalized boxes are transformed into top-left screen coordinates with explicit aspect-fill cropping for live preview and aspect-fit letterboxing for frozen images. Cover images are redrawn to apply EXIF orientation before OCR.

Freezing retains **the exact frame that produced the OCR results**. It does not combine a newer photograph with older word boxes. This can be a fraction of a second behind the live preview. The frozen image is fit to the available area to reveal the whole captured frame. Selection runs only on that stable image. Word ranges preserve punctuation between selected tokens; sentence segmentation treats printed line breaks as spaces. Context is limited to the visible recognized page.

The translation service is driven by SwiftUI's `translationTask`, the supported owner of a `TranslationSession`. It checks language availability, prepares language resources through Apple's UI, translates English → Russian, and reports errors with a retry action. Request identity checks discard stale results. The cache is memory-only and capped at 100 entries. There is no silent web translation fallback.

## Permissions and privacy

- Camera access is requested only when taking a cover or opening the reader. `NSCameraUsageDescription` is supplied. Denial offers Settings and the sample page/Photos alternatives.
- `PhotosPicker` grants access only to the image the user selects. Broad Photos library permission is unnecessary, so no blanket Photos access request is made.
- No microphone, location, tracking, analytics, advertising, login, or network service is added.
- Vision OCR runs locally. Apple's Translation framework handles model downloads and on-device translation. Internet connectivity may be required for the initial download; the app does not upload photographs.

## Known limits and physical-device checks

- The app is intentionally **iPhone portrait-only** for this MVP. Rotation does not switch camera coordinate systems. Landscape/iPad layouts are not implemented.
- Selection uses the frozen page. Live overlays are approximate hints and can lag moving paper; continuous live gesture tracking is not implemented.
- OCR assumes a flat, mostly horizontal, single-column English page. Multi-column layouts, page curvature, glare, handwriting, tiny type, and hyphenation at line ends can reduce accuracy. There is no perspective deskew, magnification, or manual OCR text editor in this version. Move closer and scan smaller sections for dense pages.
- Title detection is a heuristic and may read the author instead; the editable title is intentional.
- Some Vision words may not provide usable bounding boxes and will not be individually selectable. Sentence context cannot recover text outside the image.
- Apple controls device/language support and download prompts. English/Russian availability, offline operation after download, canceled downloads, and rapid selection changes require testing on the intended iPhone. No translation is fabricated if resources are missing.
- Real camera alignment, focusing, interruptions, portrait lock, thermal behavior, and permission flows require a physical iPhone. No camera testing is claimed from a simulator.
- This native project replaces the previous React Native/Expo implementation. There is no migration of old app data; Version 1 starts a new local library. The previous implementation remains available in Git history.
- Signing, distribution, and an installable IPA are not produced in this Linux environment. The first Xcode build and device acceptance pass are still required before treating this app as release-ready.

Follow `docs/DEVICE-ACCEPTANCE.md` on your actual iOS 26.6.2 phone and record the observed SDK, device, and OS versions.
