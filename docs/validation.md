# Current cloud validation

Passed:

- Clean `npm ci` with the committed lockfile.
- TypeScript strict checking and ESLint with no warnings.
- 30 automated tests across four suites. File-backed SQLite is closed/reopened to verify persistence.
- Expo SDK bundled dependency compatibility check (offline mode).
- iOS and Android JavaScript/Hermes exports.
- Expo native project generation for iOS and Android (without dependency install/compilation).
- Local OCR module discovery via Expo autolinking for both platforms.
- Metro startup/restart, status response, and iOS/Android development bundle requests.

Blocked/unrun:

- Real MyMemory probe: cloud HTTPS proxy denied the CONNECT with HTTP 403. The required
  `api.mymemory.translated.net` domain was added to the saved environment draft; draft
  saving does not activate network changes. Real-provider behavior remains unverified.
- Native Swift/Kotlin compilation: no Xcode or Android SDK/device in this Linux environment.
- Physical camera, OCR accuracy, rotation, gestures, accessibility, and mobile app-restart
  checks: pending the device acceptance checklist. Logic tests use representative layout
  fixtures and controlled provider responses, not camera photos or a live provider.
- Live Camera frame OCR/selection: not implemented; pending Photo Mode device acceptance.

The installation script, Metro startup instructions, and translation network domain
are saved in the environment draft for review. Publication and validation in a new
cloud task have not been performed. No native or device acceptance claim is made.
