#!/bin/bash
set -euo pipefail

# IIIF AR Archive & Upload Script
# Usage:
#   ./scripts/build_and_submit.sh              # Archive only
#   ./scripts/build_and_submit.sh --upload     # Archive + upload to App Store Connect

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEME="IIFAR"
PROJECT="$PROJECT_DIR/IIFAR.xcodeproj"
ARCHIVE_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$ARCHIVE_DIR/export"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"

cd "$PROJECT_DIR"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

echo "=== IIIF AR Archive Script ==="
echo "Project: $PROJECT"
echo ""

# Step 1: Regenerate project (xcodegen)
if command -v xcodegen &> /dev/null; then
    echo "[1/5] Regenerating Xcode project..."
    xcodegen generate
else
    echo "[1/5] xcodegen not found, skipping project generation"
fi

# Step 2: Clean
echo "[2/5] Cleaning..."
rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

# Step 3: Archive
echo "[3/5] Archiving..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -quiet

echo "  Archive created: $ARCHIVE_PATH"

# Step 4: Export IPA
echo "[4/5] Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -quiet

IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
echo "  IPA created: $IPA_FILE"

# Step 5: Upload (optional)
if [[ "${1:-}" == "--upload" ]]; then
    echo "[5/5] Uploading to App Store Connect..."

    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_FILE" \
        --apiKey "${APP_STORE_API_KEY:-}" \
        --apiIssuer "${APP_STORE_API_ISSUER:-}" \
        2>&1 || {
        echo ""
        echo "If API key auth failed, try:"
        echo "  open \"$ARCHIVE_PATH\""
        exit 1
    }

    echo ""
    echo "Upload complete! Check App Store Connect for processing status."
else
    echo "[5/5] Skipping upload (use --upload flag)"
    echo ""
    echo "To upload:"
    echo "  xcrun altool --upload-app --type ios --file \"$IPA_FILE\" --apiKey \$APP_STORE_API_KEY --apiIssuer \$APP_STORE_API_ISSUER"
    echo ""
    echo "Or open archive in Xcode Organizer:"
    echo "  open \"$ARCHIVE_PATH\""
fi

echo ""
echo "=== Done ==="
