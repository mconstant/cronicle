#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
xcodegen generate --spec phone.yml
device=$(xcrun simctl list devices available -j | jq -er '
  [.devices | to_entries | sort_by(.key) | reverse[] | select(.key | contains("SimRuntime.iOS-"))
   | .value[] | select(.name | startswith("iPhone"))][0].udid')
mkdir -p build
result_dir=$(mktemp -d "$PWD/build/phone-test.XXXXXX")
xcodebuild -project CronicleWatch.xcodeproj -scheme CroniclePhone \
    -destination "platform=iOS Simulator,id=$device" \
    -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 90 \
    -resultBundlePath "$result_dir/phone-results.xcresult" -derivedDataPath build/phone-derived CODE_SIGNING_ALLOWED=NO test
