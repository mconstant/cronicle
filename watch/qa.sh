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
xcodebuild -project CronicleWatch.xcodeproj -scheme CronicleWatch \
  -sdk watchsimulator -destination "id=$device" -parallel-testing-enabled NO \
  -derivedDataPath build/derived CODE_SIGNING_ALLOWED=NO test -quiet
xcodebuild -project CronicleWatch.xcodeproj -scheme CronicleWatch \
  -configuration Release -sdk watchsimulator -destination "id=$device" \
  -derivedDataPath build/derived CODE_SIGNING_ALLOWED=NO build -quiet
app="$PWD/build/derived/Build/Products/Release-watchsimulator/CronicleWatch.app"
test -d "$app"
bundle_id=com.mconstant.cronicle.watch
if ! xcrun simctl list devices booted -j | jq -e --arg id "$device" '.devices[][] | select(.udid == $id and .state == "Booted")' >/dev/null; then
    xcrun simctl boot "$device"
fi
for attempt in {1..10}; do
    if xcrun simctl install "$device" "$app"; then break; fi
    if [[ $attempt == 10 ]]; then exit 1; fi
    sleep 3
done
xcrun simctl launch "$device" "$bundle_id"
sleep 3
xcrun simctl io "$device" screenshot build/cronicle-watch.png
test -s build/cronicle-watch.png
ditto -c -k --keepParent "$app" build/cronicle-watch-simulator.zip
