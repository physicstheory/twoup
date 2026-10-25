#!/usr/bin/env bash
# Builds Two-Up on a Mac and packages an .ipa into ./build.
#
#   ./scripts/build_ipa.sh                 unsigned IPA (for re-signing, or sideloading tools that sign for you)
#   TEAM_ID=ABCDE12345 ./scripts/build_ipa.sh   signed IPA for TestFlight / App Store (needs your signing set up in Xcode)
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen"; exit 1; }

swift test
xcodegen

mkdir -p build
if [[ -n "${TEAM_ID:-}" ]]; then
  xcodebuild archive -project TwoUp.xcodeproj -scheme TwoUp -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/TwoUp.xcarchive \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates
  cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>${TEAM_ID}</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath build/TwoUp.xcarchive \
    -exportOptionsPlist build/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
  echo "Signed IPA: build/export/TwoUp.ipa"
else
  xcodebuild archive -project TwoUp.xcodeproj -scheme TwoUp -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/TwoUp.xcarchive \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
  rm -rf build/Payload build/TwoUp-unsigned.ipa
  mkdir build/Payload
  cp -R build/TwoUp.xcarchive/Products/Applications/TwoUp.app build/Payload/
  (cd build && zip -qry TwoUp-unsigned.ipa Payload)
  echo "Unsigned IPA: build/TwoUp-unsigned.ipa (it must be signed before it will install on a device)"
fi
