#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")"

required=(APPLE_TEAM_ID ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY APPLE_DISTRIBUTION_P12_BASE64
          APPLE_DISTRIBUTION_P12_PASSWORD APPLE_PROVISIONING_PROFILE_BASE64 GITHUB_RUN_NUMBER GITHUB_RUN_ATTEMPT)
for name in "${required[@]}"; do
    [[ -n ${!name:-} ]] || { printf 'Missing TestFlight setting: %s\n' "$name" >&2; exit 1; }
done
[[ "$ASC_KEY_ID" =~ ^[A-Z0-9]+$ ]]
tmp=$(mktemp -d)
keychain="$tmp/signing.keychain-db"
profile_path=
cleanup() {
    security delete-keychain "$keychain" 2>/dev/null || true
    if [[ -n "$profile_path" ]]; then rm -f "$profile_path"; fi
    rm -rf "$tmp"
}
trap cleanup EXIT

printf '%s' "$APPLE_DISTRIBUTION_P12_BASE64" | base64 -D > "$tmp/signing.p12"
printf '%s' "$APPLE_PROVISIONING_PROFILE_BASE64" | base64 -D > "$tmp/app.mobileprovision"
printf '%s\n' "$ASC_PRIVATE_KEY" > "$tmp/AuthKey_$ASC_KEY_ID.p8"
security cms -D -i "$tmp/app.mobileprovision" > "$tmp/profile.plist"
bundle_id=com.mconstant.cronicle.watch
profile_name=$(python3 - "$tmp/profile.plist" "$APPLE_TEAM_ID" "$bundle_id" <<'PY'
from datetime import datetime, timezone
import plistlib
import sys

with open(sys.argv[1], "rb") as f:
    profile = plistlib.load(f)
team, bundle = sys.argv[2:]
entitlements = profile["Entitlements"]
if (team not in profile["TeamIdentifier"]
        or entitlements["application-identifier"] != f"{team}.{bundle}"
        or profile["ExpirationDate"].replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc)
        or "ProvisionedDevices" in profile
        or profile.get("ProvisionsAllDevices")
        or entitlements.get("get-task-allow")):
    sys.exit("Profile must be a non-expired App Store profile for the Cronicle Watch bundle and team.")
print(profile["Name"])
PY
)
profile_uuid=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$tmp/profile.plist")
profiles="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$profiles"
profile_path="$profiles/$profile_uuid.mobileprovision"
install -m 600 "$tmp/app.mobileprovision" "$profile_path"

password=$(openssl rand -hex 32)
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 1800 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$tmp/signing.p12" -P "$APPLE_DISTRIBUTION_P12_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain"
security list-keychains -d user -s "$keychain"

xcodegen generate
xcodebuild -project CronicleWatch.xcodeproj -scheme CronicleWatch -configuration Release \
    -destination 'generic/platform=watchOS' -archivePath "$tmp/CronicleWatch.xcarchive" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
    PROVISIONING_PROFILE_SPECIFIER="$profile_name" \
    CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER.$GITHUB_RUN_ATTEMPT" archive

python3 - "$tmp/export.plist" "$APPLE_TEAM_ID" "$bundle_id" "$profile_name" <<'PY'
import plistlib
import sys

path, team, bundle, profile = sys.argv[1:]
with open(path, "wb") as f:
    plistlib.dump({
        "method": "app-store-connect",
        "destination": "upload",
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "teamID": team,
        "provisioningProfiles": {bundle: profile},
        "manageAppVersionAndBuildNumber": False,
        "testFlightInternalTestingOnly": True,
    }, f)
PY
xcodebuild -exportArchive -archivePath "$tmp/CronicleWatch.xcarchive" \
    -exportOptionsPlist "$tmp/export.plist" -exportPath "$tmp/export" \
    -allowProvisioningUpdates -authenticationKeyPath "$tmp/AuthKey_$ASC_KEY_ID.p8" \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
