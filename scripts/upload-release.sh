#!/bin/bash
set -e

# Configuration
APP_NAME="Latent"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-latent}"
BUCKET_NAME="${R2_BUCKET:-rawctl-releases}"
R2_URL="${RELEASE_BASE_URL:-https://releases.latent-app.com}"
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")}"

echo "📤 Uploading ${APP_NAME} v${VERSION} to Cloudflare R2..."

# Check if files exist
DMG_FILE="releases/${ARTIFACT_PREFIX}-${VERSION}.dmg"
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
wrangler r2 object put "${BUCKET_NAME}/${ARTIFACT_PREFIX}-${VERSION}.dmg" \
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
wrangler r2 object put "${BUCKET_NAME}/${ARTIFACT_PREFIX}-latest.dmg" \
    --file="${DMG_FILE}" \
    --content-type="application/octet-stream" \
    --remote

echo ""
echo "✅ Upload complete!"
echo ""
echo "📥 Download URLs:"
echo "   DMG:     ${R2_URL}/${ARTIFACT_PREFIX}-${VERSION}.dmg"
echo "   Latest:  ${R2_URL}/${ARTIFACT_PREFIX}-latest.dmg"
echo "   Appcast: ${R2_URL}/appcast.xml"
