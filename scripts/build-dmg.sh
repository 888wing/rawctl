#!/bin/bash
set -e

# Configuration
APP_NAME="rawctl"
VERSION="${1:-1.0.0}"
BUNDLE_ID="com.888wing.rawctl"
TEAM_ID="YOUR_TEAM_ID"  # Replace with your Apple Developer Team ID
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
DMG_PATH="build/${APP_NAME}-${VERSION}.dmg"
RELEASE_DIR="releases"

echo "🔨 Building ${APP_NAME} v${VERSION}..."

# Clean previous builds
rm -rf build/
mkdir -p build ${RELEASE_DIR}

# Build archive
echo "📦 Creating archive..."
xcodebuild archive \
  -project rawctl.xcodeproj \
  -scheme rawctl \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (${TEAM_ID})" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"

# Export app
echo "📤 Exporting app..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist scripts/ExportOptions.plist

# Create DMG
echo "💿 Creating DMG..."
if command -v create-dmg &> /dev/null; then
  create-dmg \
    --volname "${APP_NAME}" \
    --volicon "${EXPORT_PATH}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 450 185 \
    --background "scripts/dmg-background.png" \
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
shasum -a 256 "${DMG_PATH}" > "${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg.sha256"

echo "✅ Build complete!"
echo "   DMG: ${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg"
echo "   SHA256: $(cat ${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg.sha256)"
