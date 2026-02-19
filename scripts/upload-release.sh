#!/bin/bash
set -euo pipefail

# Configuration
BUCKET_NAME="latent-releases"
R2_URL="https://releases.latent-app.com"
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")}"

echo "📤 Uploading Latent v${VERSION} to Cloudflare R2..."

if ! command -v wrangler >/dev/null 2>&1; then
    echo "❌ wrangler CLI not found. Install with: npm install -g wrangler"
    exit 1
fi

# Check if files exist
DMG_FILE="releases/latent-${VERSION}.dmg"
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
wrangler r2 object put "${BUCKET_NAME}/latent-${VERSION}.dmg" \
    --file="${DMG_FILE}" \
    --content-type="application/octet-stream" \
    --remote

# Upload appcast.xml
echo "📋 Uploading appcast.xml..."
wrangler r2 object put "${BUCKET_NAME}/appcast.xml" \
    --file="${APPCAST_FILE}" \
    --content-type="application/xml" \
    --remote

# Also upload as latest for easy download link
echo "🔗 Creating latest symlink..."
wrangler r2 object put "${BUCKET_NAME}/latent-latest.dmg" \
    --file="${DMG_FILE}" \
    --content-type="application/octet-stream" \
    --remote

echo ""
echo "✅ Upload complete!"
echo ""
echo "📥 Download URLs:"
echo "   DMG:     ${R2_URL}/latent-${VERSION}.dmg"
echo "   Latest:  ${R2_URL}/latent-latest.dmg"
echo "   Appcast: ${R2_URL}/appcast.xml"
