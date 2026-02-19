#!/bin/bash
set -euo pipefail

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo '1.4.0')}"
BUILD_NUMBER="${2:-$(rg -n "CURRENT_PROJECT_VERSION = " rawctl.xcodeproj/project.pbxproj | head -n1 | sed 's/.*= //; s/;//')}"
DMG_PATH="releases/rawctl-${VERSION}.dmg"
APPCAST_PATH="releases/appcast.xml"
APPCAST_URL="https://releases.rawctl.com"

if [ ! -f "${DMG_PATH}" ]; then
  echo "❌ Missing DMG: ${DMG_PATH}"
  exit 1
fi

if [ -z "${BUILD_NUMBER}" ]; then
  echo "❌ Unable to resolve CURRENT_PROJECT_VERSION"
  exit 1
fi

FILE_SIZE=$(stat -f%z "${DMG_PATH}")
SIGNATURE=$(./bin/sign_update "${DMG_PATH}" 2>&1 | grep "sparkle:edSignature" | sed 's/.*"\(.*\)".*/\1/')
PUB_DATE=$(date -R)

cat > "${APPCAST_PATH}" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>rawctl Updates</title>
    <link>${APPCAST_URL}/appcast.xml</link>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <description><![CDATA[
        <h2>rawctl ${VERSION}</h2>
        <p>See release notes: <a href="https://rawctl.com/#release-notes">rawctl.com/#release-notes</a></p>
      ]]></description>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${APPCAST_URL}/rawctl-${VERSION}.dmg"
        sparkle:version="${BUILD_NUMBER}"
        sparkle:shortVersionString="${VERSION}"
        sparkle:edSignature="${SIGNATURE}"
        length="${FILE_SIZE}"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

echo "✅ Updated appcast.xml for version ${VERSION}"
echo "   Build number: ${BUILD_NUMBER}"
echo "   Signature: ${SIGNATURE:0:20}..."
echo "   File size: ${FILE_SIZE} bytes"
