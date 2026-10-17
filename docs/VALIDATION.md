# Validation record

Implementation date: October 17, 2026.

## Environment inspection

- Host: Linux x86_64.
- Repository: `12hleb/ReadingApp`. The previous React Native/Expo files were replaced with this native project at the user’s request; they remain available in Git history.
- Native project was initially authored at `/workspace/SwipeTranslate` and then copied to the repository root for this replacement commit.
- `xcodebuild -version`: command not found.
- `xcodebuild -showsdks`: command not found.
- `xcrun simctl list runtimes`: command not found.
- `swift`/`xcodebuild` executable discovery: none installed.
- No installed Apple SDK is available as a compatible fallback.
- Requested Xcode 26.6 and iOS 26.6.2 availability cannot be established from this host.

## Checks performed

| Check | Result | What it establishes |
| --- | --- | --- |
| Swift grammar parsing, tree-sitter-swift | Passed for 27 files | Source has no grammar ERROR/missing nodes according to that parser |
| Full OpenStep project parse, Python pbxproj | Passed | `project.pbxproj` is parseable; two native targets exist |
| Project/source graph validation | Passed | All 24 app sources and 3 test files are linked exactly once to separate source phases |
| Shared scheme and references | Passed | Scheme resolves app/test targets; referenced source/resources exist |
| Plist and asset checks | Passed | Camera description, portrait orientation, privacy manifest, asset JSON and PNG dimensions are consistent |
| Build script syntax, `bash -n` | Passed | Shell syntax is valid |
| macOS verification script invocation on this host | Blocked, exit 69 | Correctly reports missing Xcode; does not claim a successful build |
| `xcodebuild` build | Not run | Apple build tools absent |
| 18 XCTest tests | Not run | Apple SDK, test runtime, and simulator absent |
| SwiftUI previews / screen-size checks | Not run | Xcode absent |
| Real camera / translation / OS 26.6.2 validation | Not run | Physical iPhone required |

No simulator-tested or device-tested behavior is claimed. Grammar parsing does not expand Swift macros, resolve Apple framework APIs, type-check actor isolation, link the app, or run any XCTest assertions. The project still needs a first build with Apple's SDK, and compiler or device-specific issues may remain.

## Reproduce the completed portable checks

```sh
python3 scripts/validate_project.py
python3 scripts/validate_project.py --swift-syntax
bash -n scripts/verify-macos.sh
```

The optional grammar check needs the Python packages `tree-sitter` and `tree-sitter-swift`; they are validation tooling only, not app dependencies. A full project parse can also be performed with the Python `pbxproj` package. These tools were installed outside the deliverable.

## Required next validation

On a Mac, run `bash scripts/verify-macos.sh` and retain its Xcode/SDK/runtime logs and `.xcresult`. Then complete `DEVICE-ACCEPTANCE.md` on the intended iPhone. In particular, verify the portrait camera rotation/overlay transform, book-cover permissions, initial English/Russian model downloads, translation after rapid selection changes, save/relaunch behavior, small/large screen layouts, and accessibility.
