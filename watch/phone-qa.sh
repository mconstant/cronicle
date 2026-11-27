#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
xcodegen generate --spec phone.yml
device=$(xcrun simctl list devices available -j | jq -er '
  [.devices | to_entries | sort_by(.key) | reverse[] | select(.key | contains("SimRuntime.iOS-"))
   | .value[] | select(.name | startswith("iPhone"))][0].udid')
xcodebuild -project CronicleWatch.xcodeproj -scheme CroniclePhone \
    -destination "platform=iOS Simulator,id=$device" \
    -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 90 \
    -derivedDataPath build/phone-derived CODE_SIGNING_ALLOWED=NO test
