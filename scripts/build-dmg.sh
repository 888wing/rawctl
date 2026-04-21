#!/bin/bash
set -euo pipefail

# Configuration
APP_NAME="Latent"
ARTIFACT_PREFIX="latent"
VERSION="${1:-1.6.0}"
BUNDLE_ID="Shacoworkshop.latent"
TEAM_ID="${TEAM_ID:-DTR8DL89SD}"
SCHEME="${SCHEME:-latent-direct}"
ARCHIVE_PATH="build/${ARTIFACT_PREFIX}.xcarchive"
EXPORT_PATH="build/export"
DMG_PATH="build/${ARTIFACT_PREFIX}-${VERSION}.dmg"
RELEASE_DIR="releases"
DMG_BACKGROUND="scripts/dmg-background.png"

echo "🔨 Building ${APP_NAME} v${VERSION}..."

# Clean previous builds
rm -rf build/
mkdir -p build ${RELEASE_DIR}

# Build archive
echo "📦 Creating archive..."
xcodebuild archive \
  -project rawctl.xcodeproj \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  MARKETING_VERSION="${VERSION}"

# Export app
echo "📤 Exporting app..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist scripts/ExportOptions.plist

# Create DMG
echo "💿 Creating DMG..."
if command -v create-dmg &> /dev/null; then
  CREATE_DMG_ARGS=(
    --volname "${APP_NAME} Installer"
    --volicon "rawctl/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
    --window-pos 200 120
    --window-size 800 400
    --icon-size 100
    --icon "${APP_NAME}.app" 150 190
    --hide-extension "${APP_NAME}.app"
    --app-drop-link 450 185
  )

  if [[ -f "${DMG_BACKGROUND}" ]]; then
    CREATE_DMG_ARGS+=(--background "${DMG_BACKGROUND}")
  fi

  create-dmg \
    "${CREATE_DMG_ARGS[@]}" \
    "${DMG_PATH}" \
    "${EXPORT_PATH}/${APP_NAME}.app"
else
  # Fallback to hdiutil
  hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${EXPORT_PATH}/${APP_NAME}.app" \
    -ov -format UDZO \
    "${DMG_PATH}"
fi

# Notarize DMG
echo "🔐 Notarizing DMG..."
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "notarization" \
  --wait

# Staple notarization ticket
echo "📎 Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"

# Copy to releases
cp "${DMG_PATH}" "${RELEASE_DIR}/"

# Generate checksum
echo "🔢 Generating checksum..."
CHECKSUM_PATH="${RELEASE_DIR}/$(basename "${DMG_PATH}").sha256"
shasum -a 256 "${DMG_PATH}" > "${CHECKSUM_PATH}"

echo "✅ Build complete!"
echo "   DMG: ${RELEASE_DIR}/$(basename "${DMG_PATH}")"
echo "   SHA256: $(cut -d' ' -f1 "${CHECKSUM_PATH}")"
