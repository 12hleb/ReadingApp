#!/bin/bash
# Run from any directory on a Mac with Xcode and an iOS 26+ simulator runtime.
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if ! command -v xcodebuild >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
    echo "BLOCKED: Xcode and the Apple SDK tools are required. No build or XCTest run occurred."
    exit 69
fi
mkdir -p build
xcodebuild -version | tee build/xcode-version.txt
xcodebuild -showsdks | tee build/sdks.txt
xcrun simctl list runtimes | tee build/runtimes.txt
sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
if [[ "${sdk_version%%.*}" -lt 26 ]]; then
    echo "BLOCKED: Select Xcode with an iOS 26 or newer SDK. Installed simulator SDK: $sdk_version"
    exit 69
fi
xcodebuild -project SwipeTranslate.xcodeproj -scheme SwipeTranslate \
    -configuration Debug -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build \
    | tee build/build.log
if [[ "${1:-}" == "--build-only" ]]; then exit 0; fi
if [[ -z "${SIMULATOR_UDID:-}" ]]; then
    xcrun simctl list devices available --json > build/devices.json
    simulator_id="$(python3 - <<'PY'
import json, re
with open('build/devices.json') as f:
    devices = json.load(f)['devices']
for runtime, items in sorted(devices.items(), reverse=True):
    match = re.search(r'iOS-(\d+)', runtime)
    if not match or int(match.group(1)) < 26:
        continue
    for device in items:
        if device.get('isAvailable') and 'iPhone' in device['name']:
            print(device['udid'])
            raise SystemExit(0)
raise SystemExit('BLOCKED: Install an iOS 26+ iPhone simulator runtime in Xcode Settings > Components.')
PY
)"
else
    simulator_id="$SIMULATOR_UDID"
fi
result_path="build/Tests-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project SwipeTranslate.xcodeproj -scheme SwipeTranslate \
    -configuration Debug -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath build/DerivedData -resultBundlePath "$result_path" \
    CODE_SIGNING_ALLOWED=NO test | tee build/test.log
echo "Build and simulator tests completed. Results: $result_path"
