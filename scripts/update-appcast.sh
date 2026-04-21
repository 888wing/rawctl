#!/bin/bash
set -euo pipefail

APP_NAME="Latent"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-latent}"
APPCAST_URL="${RELEASE_BASE_URL:-https://releases.latent-app.com}"
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")}"
DMG_PATH="releases/${ARTIFACT_PREFIX}-${VERSION}.dmg"
APPCAST_PATH="releases/appcast.xml"
BUILD_NUMBER="${BUILD_NUMBER:-}"

resolve_build_number() {
  local info_plist
  for info_plist in \
    "export/${APP_NAME}.app/Contents/Info.plist" \
    "build/export/${APP_NAME}.app/Contents/Info.plist"
  do
    if [[ -f "${info_plist}" ]]; then
      /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${info_plist}" 2>/dev/null || true
      return
    fi
  done

  for info_plist in \
    "latent.xcarchive/Info.plist" \
    "build/${ARTIFACT_PREFIX}.xcarchive/Info.plist"
  do
    if [[ -f "${info_plist}" ]]; then
      /usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "${info_plist}" 2>/dev/null || true
      return
    fi
  done
}

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "❌ DMG not found at ${DMG_PATH}" >&2
  exit 1
fi

if [[ -z "${BUILD_NUMBER}" ]]; then
  BUILD_NUMBER="$(resolve_build_number)"
fi

if [[ -z "${BUILD_NUMBER}" ]]; then
  echo "❌ Failed to resolve CFBundleVersion for ${APP_NAME}. Set BUILD_NUMBER or keep the exported app/archive available." >&2
  exit 1
fi

# Get file size
FILE_SIZE=$(stat -f%z "${DMG_PATH}")

# Get EdDSA signature (requires Sparkle's sign_update tool)
SIGNATURE=$(./bin/sign_update "${DMG_PATH}" 2>&1 | perl -ne 'print "$1\n" if /sparkle:edSignature="([^"]+)"/')

if [ -z "${SIGNATURE}" ]; then
  echo "❌ Failed to extract Sparkle signature from ${DMG_PATH}" >&2
  exit 1
fi

# Get current date in RFC 2822 format
PUB_DATE=$(date -R)

# Create or update appcast.xml
cat > "${APPCAST_PATH}" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>${APP_NAME} Updates</title>
    <link>${APPCAST_URL}/appcast.xml</link>
    <description>${APP_NAME} release updates</description>
    <language>en</language>

    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <description><![CDATA[
        <h2>What's New in ${APP_NAME} ${VERSION}</h2>
        <p>See the full changelog on GitHub.</p>
      ]]></description>
      <enclosure
        url="${APPCAST_URL}/${ARTIFACT_PREFIX}-${VERSION}.dmg"
        sparkle:version="${BUILD_NUMBER}"
        sparkle:shortVersionString="${VERSION}"
        sparkle:minimumSystemVersion="14.0"
        sparkle:edSignature="${SIGNATURE}"
        length="${FILE_SIZE}"
        type="application/octet-stream"/>
    </item>

  </channel>
</rss>
EOF

echo "✅ Updated ${APP_NAME} appcast.xml for version ${VERSION}"
echo "   Build: ${BUILD_NUMBER}"
echo "   Signature: ${SIGNATURE:0:20}..."
echo "   File size: ${FILE_SIZE} bytes"
