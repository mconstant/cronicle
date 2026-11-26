#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc Sources/WatchLedger.swift Tests/LedgerTests.swift -o build/ledger-tests
build/ledger-tests
xcodegen generate
device=$(xcrun simctl list devices available -j | jq -er '
  [.devices | to_entries[] | select(.key | contains("watchOS"))
   | .value[] | select(.name | startswith("Apple Watch"))]
  | (map(select(.name | contains("40mm"))) + .)[0].udid')
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
xcodebuild -project CronicleWatch.xcodeproj -scheme CronicleWatch \
  -configuration Release -sdk watchsimulator -destination "id=$device" \
  -derivedDataPath build/derived CODE_SIGNING_ALLOWED=NO build -quiet
app="$PWD/build/derived/Build/Products/Release-watchsimulator/CronicleWatch.app"
test -d "$app"
bundle_id=com.mconstant.cronicle.watch
xcrun simctl install "$device" "$app"
xcrun simctl launch "$device" "$bundle_id"
sleep 3
xcrun simctl io "$device" screenshot build/cronicle-watch.png
test -s build/cronicle-watch.png
ditto -c -k --keepParent "$app" build/cronicle-watch-simulator.zip
