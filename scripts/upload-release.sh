#!/bin/bash
set -e

# Configuration
BUCKET_NAME="rawctl-releases"
R2_URL="https://releases.rawctl.com"
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")}"

echo "📤 Uploading rawctl v${VERSION} to Cloudflare R2..."

# Check if files exist
DMG_FILE="releases/rawctl-${VERSION}.dmg"
APPCAST_FILE="releases/appcast.xml"

if [ ! -f "${DMG_FILE}" ]; then
    echo "❌ DMG file not found: ${DMG_FILE}"
    echo "   Run ./scripts/build-dmg.sh ${VERSION} first"
    exit 1
fi

if [ ! -f "${APPCAST_FILE}" ]; then
    echo "❌ Appcast file not found: ${APPCAST_FILE}"
    echo "   Run ./scripts/update-appcast.sh ${VERSION} first"
    exit 1
fi

# Upload DMG
echo "📦 Uploading DMG..."
wrangler r2 object put "${BUCKET_NAME}/rawctl-${VERSION}.dmg" \
    --file="${DMG_FILE}" \
    --content-type="application/octet-stream"

# Upload appcast.xml
echo "📋 Uploading appcast.xml..."
wrangler r2 object put "${BUCKET_NAME}/appcast.xml" \
    --file="${APPCAST_FILE}" \
    --content-type="application/xml"

# Also upload as latest for easy download link
echo "🔗 Creating latest symlink..."
wrangler r2 object put "${BUCKET_NAME}/rawctl-latest.dmg" \
    --file="${DMG_FILE}" \
    --content-type="application/octet-stream"

echo ""
echo "✅ Upload complete!"
echo ""
echo "📥 Download URLs:"
echo "   DMG:     ${R2_URL}/rawctl-${VERSION}.dmg"
echo "   Latest:  ${R2_URL}/rawctl-latest.dmg"
echo "   Appcast: ${R2_URL}/appcast.xml"
