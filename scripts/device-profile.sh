#!/usr/bin/env bash
# Makes sure a development provisioning profile for the app exists and covers the iPad.
#
# A free (Personal Team) Apple ID gets no developer portal, so Xcode is the only thing that
# can create the profile. This script builds a throwaway stub app with automatic signing,
# which makes Xcode register the iPad and download "iOS Team Provisioning Profile: <bundle id>".
# Bazel then finds that profile with rules_apple's local_provisioning_profile.
#
# Free profiles last 7 days: `make device` runs this first and only rebuilds the stub
# when the profile is missing, about to expire, or does not list the iPad.
#
# Usage: scripts/device-profile.sh <bundle id> <device udid>
# The team comes from the Apple Development certificate in the keychain; set DEVICE_TEAM to
# pick another one. Nothing personal is written into the repository.
set -euo pipefail

BUNDLE_ID="${1:?bundle id}"
UDID="${2:?device udid}"
PROFILE_NAME="iOS Team Provisioning Profile: ${BUNDLE_ID}"

team="${DEVICE_TEAM:-}"
if [[ -z "$team" ]]; then
  team=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU=\([A-Z0-9]*\).*/\1/p' | head -1)
fi
if [[ -z "$team" ]]; then
  echo "device-profile: no Apple Development certificate found." >&2
  echo "  Sign in to Xcode once (Settings > Accounts) with your Apple ID, then retry." >&2
  exit 1
fi

# Prints the newest matching profile that is valid for at least another day and lists the iPad.
find_profile() {
  python3 - "$PROFILE_NAME" "$team" "$UDID" <<'PY'
import datetime, glob, os, plistlib, subprocess, sys
name, team, udid = sys.argv[1:]
home = os.path.expanduser("~")
paths = glob.glob(f"{home}/Library/Developer/Xcode/UserData/Provisioning Profiles/*.mobileprovision")
paths += glob.glob(f"{home}/Library/MobileDevice/Provisioning Profiles/*.mobileprovision")
soon = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)
best = None
for path in paths:
    try:
        raw = subprocess.check_output(["security", "cms", "-D", "-i", path], stderr=subprocess.DEVNULL)
        plist = plistlib.loads(raw)
    except Exception:
        continue
    expires = plist["ExpirationDate"].replace(tzinfo=datetime.timezone.utc)
    if (plist.get("Name") == name and team in plist.get("TeamIdentifier", [])
            and udid in plist.get("ProvisionedDevices", []) and expires > soon):
        if best is None or expires > best[0]:
            best = (expires, path)
if best:
    print(f"{best[1]}\t{best[0]:%Y-%m-%d}")
PY
}

found=$(find_profile)
if [[ -n "$found" ]]; then
  echo "device-profile: profile valid until ${found##*$'\t'}"
  exit 0
fi

echo "device-profile: asking Xcode for a new profile (team ${team})..."
work=$(mktemp -d -t fp-profile)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Stub"
cat > "$work/Stub/StubApp.swift" <<'SWIFT'
import SwiftUI

@main
struct StubApp: App {
    var body: some Scene { WindowGroup { Text("Stub") } }
}
SWIFT
cat > "$work/project.yml" <<YML
name: ProfileStub
options:
  deploymentTarget:
    iOS: "26.0"
targets:
  ProfileStub:
    type: application
    platform: iOS
    sources: [Stub]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${BUNDLE_ID}
        DEVELOPMENT_TEAM: ${team}
        CODE_SIGN_STYLE: Automatic
        GENERATE_INFOPLIST_FILE: YES
        TARGETED_DEVICE_FAMILY: "2"
        SWIFT_VERSION: "6.0"
YML
(cd "$work" && xcodegen generate --quiet)
if ! xcodebuild -project "$work/ProfileStub.xcodeproj" -scheme ProfileStub -configuration Debug \
     -destination "id=${UDID}" -derivedDataPath "$work/dd" \
     -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
     build > "$work/xcodebuild.log" 2>&1; then
  grep -E "error:|Signing|provision" "$work/xcodebuild.log" | head -20 >&2
  echo "device-profile: Xcode could not create the profile (log above)." >&2
  exit 1
fi

found=$(find_profile)
if [[ -z "$found" ]]; then
  echo "device-profile: Xcode built the stub but no matching profile appeared." >&2
  exit 1
fi
echo "device-profile: new profile valid until ${found##*$'\t'}"
