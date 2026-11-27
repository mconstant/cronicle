#!/usr/bin/env bash
set -euo pipefail
umask 077
script_dir=$(cd "$(dirname "$0")" && pwd)
cd "${1:-$script_dir}"
version=${2#v}
product=${3:-watch}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]

required=(APPLE_TEAM_ID ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY APPLE_DISTRIBUTION_P12_BASE64
          APPLE_DISTRIBUTION_P12_PASSWORD GITHUB_RUN_NUMBER GITHUB_RUN_ATTEMPT)
case "$product" in
    watch) required+=(APPLE_PROVISIONING_PROFILE_BASE64 APPLE_WATCH_PROVISIONING_PROFILE_BASE64) ;;
    iphone) required+=(APPLE_IPHONE_PROVISIONING_PROFILE_BASE64) ;;
    *) printf 'Unknown TestFlight product: %s\n' "$product" >&2; exit 2 ;;
esac
for name in "${required[@]}"; do
    [[ -n ${!name:-} ]] || { printf 'Missing TestFlight setting: %s\n' "$name" >&2; exit 1; }
done
[[ "$ASC_KEY_ID" =~ ^[A-Z0-9]+$ ]]
tmp=$(mktemp -d)
keychain="$tmp/signing.keychain-db"
profile_paths=()
cleanup() {
    security delete-keychain "$keychain" 2>/dev/null || true
    for path in ${profile_paths[@]+"${profile_paths[@]}"}; do rm -f "$path"; done
    rm -rf "$tmp"
}
trap cleanup EXIT

printf '%s' "$APPLE_DISTRIBUTION_P12_BASE64" | base64 -D > "$tmp/signing.p12"
printf '%s\n' "$ASC_PRIVATE_KEY" > "$tmp/AuthKey_$ASC_KEY_ID.p8"
profiles="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$profiles"

install_profile() {
    local bundle=$1 secret_name=$2 profile_uuid profile_path
    printf '%s' "${!secret_name}" | base64 -D > "$tmp/$bundle.mobileprovision"
    security cms -D -i "$tmp/$bundle.mobileprovision" > "$tmp/$bundle.plist"
    profile_name=$(python3 - "$tmp/$bundle.plist" "$APPLE_TEAM_ID" "$bundle" <<'PY'
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
    sys.exit("Profile must be a non-expired App Store profile for the requested Cronicle bundle and team.")
print(profile["Name"])
PY
)
    profile_uuid=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$tmp/$bundle.plist")
    profile_path="$profiles/$profile_uuid.mobileprovision"
    install -m 600 "$tmp/$bundle.mobileprovision" "$profile_path"
    profile_paths+=("$profile_path")
}
if [[ "$product" == watch ]]; then
    bundle_id=com.mconstant.cronicle.watch
    watch_bundle_id="$bundle_id.watchkitapp"
    scheme=CronicleDistribution
    spec=testflight-distribution.yml
    cp "$script_dir/distribution.yml" "$spec"
    install_profile "$bundle_id" APPLE_PROVISIONING_PROFILE_BASE64
    wrapper_profile=$profile_name
    install_profile "$watch_bundle_id" APPLE_WATCH_PROVISIONING_PROFILE_BASE64
    signing=("CRONICLE_WRAPPER_PROFILE=$wrapper_profile" "CRONICLE_WATCH_PROFILE=$profile_name")
    export_profiles=("$bundle_id" "$wrapper_profile" "$watch_bundle_id" "$profile_name")
else
    bundle_id=com.mconstant.cronicle.ios
    scheme=CroniclePhone
    spec=phone.yml
    install_profile "$bundle_id" APPLE_IPHONE_PROVISIONING_PROFILE_BASE64
    signing=("PROVISIONING_PROFILE_SPECIFIER=$profile_name")
    export_profiles=("$bundle_id" "$profile_name")
fi

password=$(openssl rand -hex 32)
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 1800 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$tmp/signing.p12" -P "$APPLE_DISTRIBUTION_P12_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain"
security list-keychains -d user -s "$keychain"

xcodegen generate --spec "$spec"
xcodebuild -project CronicleWatch.xcodeproj -scheme "$scheme" -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$tmp/Cronicle.xcarchive" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
    "${signing[@]}" \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER.$GITHUB_RUN_ATTEMPT" archive

app="$tmp/Cronicle.xcarchive/Products/Applications/$scheme.app"
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist" | grep -Fx "$bundle_id"

if [[ "$product" == watch ]]; then
    /usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Watch/CronicleWatch.app/Info.plist" | grep -Fx "$watch_bundle_id"
fi

python3 - "$tmp/export.plist" "$APPLE_TEAM_ID" "${export_profiles[@]}" <<'PY'
import plistlib
import sys

path, team, *profiles = sys.argv[1:]
with open(path, "wb") as f:
    plistlib.dump({
        "method": "app-store-connect",
        "destination": "upload",
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "teamID": team,
        "provisioningProfiles": dict(zip(profiles[::2], profiles[1::2])),
        "manageAppVersionAndBuildNumber": False,
        "testFlightInternalTestingOnly": True,
    }, f)
PY
xcodebuild -exportArchive -archivePath "$tmp/Cronicle.xcarchive" \
    -exportOptionsPlist "$tmp/export.plist" -exportPath "$tmp/export" \
    -allowProvisioningUpdates -authenticationKeyPath "$tmp/AuthKey_$ASC_KEY_ID.p8" \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
