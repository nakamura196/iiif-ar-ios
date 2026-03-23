#!/bin/bash
# Capture App Store screenshots from simulator
# Usage: ./scripts/capture_screenshots.sh

set -e

SIM="iPhone 17 Pro Max"
APP="com.nakamura196.iifar"
OUT="screenshots/raw"

mkdir -p "$OUT"

echo "=== IIIF AR Screenshot Capture ==="

# Grant camera permission
xcrun simctl privacy "$SIM" grant camera "$APP" 2>/dev/null || true

# Terminate and relaunch
xcrun simctl terminate "$SIM" "$APP" 2>/dev/null || true
sleep 1
xcrun simctl launch "$SIM" "$APP"
sleep 5

# 1. Gallery screen
xcrun simctl io "$SIM" screenshot "$OUT/01_gallery.png"
echo "1/4 Gallery captured"

# Wait for thumbnails
sleep 5
xcrun simctl io "$SIM" screenshot "$OUT/01_gallery_loaded.png"
echo "1b/4 Gallery with thumbnails captured"

echo ""
echo "=== Screenshots saved to $OUT ==="
echo ""
echo "NOTE: AR placement screenshots must be captured on a real device."
echo "Use iPhone screenshot (Power + Volume Up) while the app is running."
echo ""
echo "Next steps:"
echo "  1. Take AR screenshots on real device and save to $OUT/"
echo "  2. Run: python3 scripts/generate_marketing_screenshots.py --input-dir $OUT --output-dir screenshots/marketing --lang ja"
ls -la "$OUT"
