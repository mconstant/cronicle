# Internal TestFlight releases

The TestFlight workflow uploads signed watchOS builds to your internal
tester group. It runs after a successful stable GitHub release that includes
the TestFlight workflow, or manually for such a tag. GitHub simulator
releases work independently of Apple credentials.

## One-time Apple setup

1. Activate your Apple Developer Program membership and accept current
   agreements. Register the explicit bundle ID `com.mconstant.cronicle.watch`
   and create its watchOS app record in App Store Connect.
2. Create an Apple Distribution certificate, export it with its private key
   as a password-protected `.p12`, and create an App Store Connect
   distribution provisioning profile for that bundle and certificate.
   Register the embedded Watch app as `com.mconstant.cronicle.watch.watchkitapp`
   and create a second App Store Connect profile with the same certificate.
3. In App Store Connect, create an API key for uploading builds. Apple
   allows the Developer role to upload. Use a key scoped to the necessary
   role and retain your own secure copy of the private file.
4. Create an internal TestFlight group, add yourself, and turn on automatic
   distribution for builds for that group.

## GitHub Actions setup

Create a repository environment named `testflight` in **Settings →
Environments**. Add these values in that environment.

| Environment secret | Value |
| --- | --- |
| `APPLE_DISTRIBUTION_P12_BASE64` | Base64 of the exported certificate and private key |
| `APPLE_DISTRIBUTION_P12_PASSWORD` | Password on that export |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64 of the wrapper App Store Connect `.mobileprovision` |
| `APPLE_WATCH_PROVISIONING_PROFILE_BASE64` | Base64 of the embedded Watch app App Store Connect `.mobileprovision` |
| `ASC_PRIVATE_KEY` | Complete App Store Connect `.p8` file, including the header and footer |

| Environment variable | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Developer Team ID |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID |

To encode a binary file on Linux or macOS, run
`base64 < signing.p12 | tr -d '\n'` locally. Base64 is an encoding.
Keep the results in GitHub secrets and the original files in secure
storage. The workflow uses a temporary keychain on a hosted macOS runner.

After setting up the environment, add the **repository Actions variable**
`CRONICLE_TESTFLIGHT_ENABLED` with the value `true`. Leave it unset to
skip uploads. For the first run, either publish the next stable tag or run
the **TestFlight** workflow manually with a compatible published tag.
The workflow verifies that the tag points to a released commit on main.

After Apple processes the build, open TestFlight on the paired iPhone and
install the available Watch beta. A successful GitHub upload only confirms
delivery to Apple. Processing and tester availability are separate.

If the upload result is ambiguous, check App Store Connect for the build
before retrying. The workflow uses a build number derived from the GitHub
workflow run and attempt.
