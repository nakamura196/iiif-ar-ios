#!/usr/bin/env bash
#
# build_and_submit.sh — Build, archive, and submit IIIF AR to App Store Connect.
#
# This script documents the full submission flow for the IIIF AR app.
# Run each step manually or execute the whole script end-to-end.
#
# Prerequisites:
#   - Xcode with valid signing identity and provisioning profile
#   - XcodeGen installed (brew install xcodegen)
#   - ExportOptions.plist configured for App Store distribution
#   - App Store Connect API key or Apple ID credentials for upload
#
# Usage:
#   ./scripts/build_and_submit.sh
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="IIFAR.xcodeproj"
SCHEME="IIFAR"
ARCHIVE_PATH="/tmp/IIFAR.xcarchive"
EXPORT_PATH="/tmp/IIFAR_export"
EXPORT_OPTIONS="${PROJECT_DIR}/ExportOptions.plist"

cd "$PROJECT_DIR"

echo "=== Step 1: Generate Xcode project from project.yml ==="
# Regenerate the .xcodeproj from project.yml whenever project settings,
# targets, or build settings have changed.
xcodegen generate

echo ""
echo "=== Step 2: Clean and archive for Release ==="
# Build a Release archive suitable for App Store distribution.
# -allowProvisioningUpdates lets Xcode resolve signing automatically.
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    clean archive \
    -allowProvisioningUpdates

echo ""
echo "=== Step 3: Export IPA from archive ==="
# Export the archive to an IPA using the ExportOptions.plist, which specifies:
#   - method: app-store
#   - teamID
#   - signing style (automatic or manual)
#   - upload settings
#
# Create ExportOptions.plist if it doesn't exist:
#   <?xml version="1.0" encoding="UTF-8"?>
#   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
#   <plist version="1.0">
#   <dict>
#       <key>method</key>
#       <string>app-store</string>
#       <key>teamID</key>
#       <string>YOUR_TEAM_ID</string>
#       <key>uploadBitcode</key>
#       <false/>
#       <key>uploadSymbols</key>
#       <true/>
#   </dict>
#   </plist>
if [ ! -f "$EXPORT_OPTIONS" ]; then
    echo "Error: ExportOptions.plist not found at $EXPORT_OPTIONS"
    echo "Create it with your team ID and distribution settings."
    exit 1
fi

xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates

echo ""
echo "=== Step 4: Upload to App Store Connect ==="
# Upload the exported IPA to App Store Connect.
# Uses xcrun altool (or xcrun notarytool for notarization).
#
# Option A: altool with App Store Connect API key (recommended for CI)
#   xcrun altool --upload-app \
#       -f "$EXPORT_PATH/IIFAR.ipa" \
#       -t ios \
#       --apiKey YOUR_API_KEY_ID \
#       --apiIssuer YOUR_ISSUER_ID
#
# Option B: altool with Apple ID (interactive)
#   xcrun altool --upload-app \
#       -f "$EXPORT_PATH/IIFAR.ipa" \
#       -t ios \
#       -u "your@apple.id" \
#       -p "@keychain:AC_PASSWORD"
#
# Note: altool is deprecated in Xcode 15+. Use xcrun notarytool or
# Transporter.app as alternatives.

IPA_PATH="$EXPORT_PATH/IIFAR.ipa"
if [ ! -f "$IPA_PATH" ]; then
    # The exported file name may vary; find the IPA
    IPA_PATH="$(find "$EXPORT_PATH" -name '*.ipa' -print -quit)"
fi

if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
    echo "Error: No IPA found in $EXPORT_PATH"
    exit 1
fi

echo "IPA ready for upload: $IPA_PATH"
echo ""
echo "Upload with one of:"
echo "  xcrun altool --upload-app -f \"$IPA_PATH\" -t ios --apiKey KEY_ID --apiIssuer ISSUER_ID"
echo "  xcrun altool --upload-app -f \"$IPA_PATH\" -t ios -u EMAIL -p @keychain:AC_PASSWORD"
echo ""
echo "Or drag the IPA into Transporter.app for manual upload."
echo ""
echo "=== Done ==="
