#!/bin/bash
set -e

VERSION="${1:-$(git describe --tags --abbrev=0 | sed 's/^v//')}"
DMG_PATH="releases/rawctl-${VERSION}.dmg"
APPCAST_PATH="releases/appcast.xml"

# Get file size
FILE_SIZE=$(stat -f%z "${DMG_PATH}")

# Get EdDSA signature (requires Sparkle's sign_update tool)
SIGNATURE=$(./bin/sign_update "${DMG_PATH}" 2>&1 | grep "sparkle:edSignature" | sed 's/.*"\(.*\)".*/\1/')

# Get current date in RFC 2822 format
PUB_DATE=$(date -R)

# Create or update appcast.xml
cat > "${APPCAST_PATH}" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>rawctl Updates</title>
    <link>https://rawctl.app</link>
    <description>rawctl release updates</description>
    <language>en</language>

    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>What's New in ${VERSION}</h2>
        <p>See the full changelog on GitHub.</p>
      ]]></description>
      <enclosure
        url="https://releases.rawctl.app/rawctl-${VERSION}.dmg"
        sparkle:edSignature="${SIGNATURE}"
        length="${FILE_SIZE}"
        type="application/octet-stream"/>
    </item>

  </channel>
</rss>
EOF

echo "✅ Updated appcast.xml for version ${VERSION}"
echo "   Signature: ${SIGNATURE:0:20}..."
echo "   File size: ${FILE_SIZE} bytes"
