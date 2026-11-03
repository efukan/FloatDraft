#!/usr/bin/env bash
# Builds a Mac App Store archive.
#
#   scripts/archive.sh --local          # ad-hoc signed archive: checks that Release archives cleanly (no Apple account needed)
#   TEAM_ID=XXXXXXXXXX scripts/archive.sh
#                                       # team-signed archive + App Store export (.pkg) via automatic signing.
#                                       # Needs your Apple ID signed in to Xcode; may create certificates/profiles.
#
# Upload the exported .pkg with Transporter or Xcode's Organizer.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="build/FloatDraft.xcarchive"
EXPORT="build/export"
mkdir -p build/logs
xcodegen generate --quiet
rm -rf "$ARCHIVE" "$EXPORT"

if [[ "${1:-}" == "--local" ]]; then
    xcodebuild -project FloatDraft.xcodeproj -scheme FloatDraft -configuration Release \
        -archivePath "$ARCHIVE" archive >build/logs/archive.log 2>&1 \
        || { grep -E 'error:' build/logs/archive.log | sort -u; echo "archive failed (see build/logs/archive.log)"; exit 1; }
    echo "Local archive: $ARCHIVE"
    exit 0
fi

: "${TEAM_ID:?Set TEAM_ID to your Apple Developer Team ID, or pass --local}"
SIGNING=(CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_IDENTITY="Apple Development")

xcodebuild -project FloatDraft.xcodeproj -scheme FloatDraft -configuration Release \
    -archivePath "$ARCHIVE" -allowProvisioningUpdates "${SIGNING[@]}" archive >build/logs/archive.log 2>&1 \
    || { grep -E 'error:' build/logs/archive.log | sort -u; echo "archive failed (see build/logs/archive.log)"; exit 1; }

OPTIONS="build/ExportOptions.plist"
cat >"$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" -exportOptionsPlist "$OPTIONS" \
    -allowProvisioningUpdates >build/logs/export.log 2>&1 \
    || { grep -E 'error' build/logs/export.log | sort -u; echo "export failed (see build/logs/export.log)"; exit 1; }
ls "$EXPORT"
echo "Upload $EXPORT/*.pkg with Transporter or Xcode Organizer."
