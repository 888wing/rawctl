#!/bin/bash
#
# rawctl Release Script
# Automates: build → sign → package → notarize → sparkle sign → appcast update
#
# Usage: ./scripts/release.sh <version> [--dry-run] [--skip-notarize] [--skip-upload]
#
set -e

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

APP_NAME="rawctl"
BUNDLE_ID="Shacoworkshop.rawctl"
TEAM_ID="477VK7AAV5"
DEVELOPER_ID="Developer ID Application: Siu Fai Chui (${TEAM_ID})"

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
XCODE_PROJECT="${PROJECT_ROOT}/rawctl"
ARCHIVE_PATH="${XCODE_PROJECT}/build/${APP_NAME}.xcarchive"
EXPORT_PATH="${XCODE_PROJECT}/build/export"
RELEASE_DIR="${PROJECT_ROOT}/releases"
BIN_DIR="${PROJECT_ROOT}/bin"

# Remote server (customize for your setup)
REMOTE_HOST="releases.rawctl.com"
REMOTE_PATH="/var/www/releases"

# Appcast URL
APPCAST_URL="https://releases.rawctl.com"

# ═══════════════════════════════════════════════════════════════════════════════
# Parse Arguments
# ═══════════════════════════════════════════════════════════════════════════════

VERSION=""
DRY_RUN=false
SKIP_NOTARIZE=false
SKIP_UPLOAD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            SKIP_NOTARIZE=true
            SKIP_UPLOAD=true
            shift
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --skip-upload)
            SKIP_UPLOAD=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 <version> [options]"
            echo ""
            echo "Options:"
            echo "  --dry-run        Build locally, skip notarize and upload"
            echo "  --skip-notarize  Skip notarization step"
            echo "  --skip-upload    Skip upload to server"
            echo ""
            echo "Example: $0 1.1"
            exit 0
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "❌ Error: Version required"
    echo "Usage: $0 <version> [--dry-run]"
    exit 1
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${XCODE_PROJECT}/build/${DMG_NAME}"

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

print_step() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

print_info() {
    echo "  ℹ️  $1"
}

print_success() {
    echo "  ✅ $1"
}

print_warning() {
    echo "  ⚠️  $1"
}

print_error() {
    echo "  ❌ $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Pre-flight Checks
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Pre-flight Checks"

# Check we're in the right directory
if [ ! -f "${XCODE_PROJECT}/rawctl.xcodeproj/project.pbxproj" ]; then
    print_error "Must run from rawctl/rawctl directory"
    exit 1
fi

# Check for Sparkle sign_update tool
if [ ! -f "${BIN_DIR}/sign_update" ]; then
    print_warning "Sparkle sign_update not found at ${BIN_DIR}/sign_update"
    print_info "Download from: https://github.com/sparkle-project/Sparkle/releases"
    print_info "Extract and copy 'sign_update' to ${BIN_DIR}/"

    if [ "$DRY_RUN" = false ]; then
        exit 1
    fi
fi

# Check for create-dmg
if ! command -v create-dmg &> /dev/null; then
    print_warning "create-dmg not found, will use hdiutil fallback"
    print_info "Install with: brew install create-dmg"
fi

# Check for Developer ID certificate
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    print_error "Developer ID Application certificate not found"
    print_info "Install from Apple Developer portal"
    exit 1
fi

print_success "All checks passed"

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - Will build locally only"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Step 1: Clean Build Directory
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Step 1: Cleaning Build Directory"

rm -rf "${XCODE_PROJECT}/build"
mkdir -p "${XCODE_PROJECT}/build"
mkdir -p "${RELEASE_DIR}"

print_success "Build directory cleaned"

# ═══════════════════════════════════════════════════════════════════════════════
# Step 2: Build Archive
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Step 2: Building Archive (Release Configuration)"

# Archive without forcing CODE_SIGN_IDENTITY to avoid SPM package conflicts
# -allowProvisioningUpdates allows automatic profile generation
# Code signing will be handled during export via ExportOptions.plist
xcodebuild archive \
    -project "${XCODE_PROJECT}/rawctl.xcodeproj" \
    -scheme rawctl \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    MARKETING_VERSION="${VERSION}" \
    2>&1 | xcpretty 2>/dev/null || xcodebuild archive \
    -project "${XCODE_PROJECT}/rawctl.xcodeproj" \
    -scheme rawctl \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    MARKETING_VERSION="${VERSION}"

print_success "Archive created at ${ARCHIVE_PATH}"

# ═══════════════════════════════════════════════════════════════════════════════
# Step 3: Export App
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Step 3: Exporting App (Developer ID Signed)"

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${SCRIPT_DIR}/ExportOptions.plist"

print_success "App exported to ${EXPORT_PATH}"

# ═══════════════════════════════════════════════════════════════════════════════
# Step 4: Create DMG
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Step 4: Creating DMG"

if command -v create-dmg &> /dev/null; then
    # Check if background image exists
    BG_OPTION=""
    if [ -f "${SCRIPT_DIR}/dmg-background.png" ]; then
        BG_OPTION="--background ${SCRIPT_DIR}/dmg-background.png"
    fi

    # Get app icon path
    ICON_PATH="${EXPORT_PATH}/${APP_NAME}.app/Contents/Resources/AppIcon.icns"
    if [ ! -f "$ICON_PATH" ]; then
        ICON_PATH=""
    fi

    create-dmg \
        --volname "${APP_NAME}" \
        ${ICON_PATH:+--volicon "$ICON_PATH"} \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 450 185 \
        ${BG_OPTION} \
        "${DMG_PATH}" \
        "${EXPORT_PATH}/${APP_NAME}.app" || true
else
    # Fallback to hdiutil
    print_info "Using hdiutil fallback..."
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${EXPORT_PATH}/${APP_NAME}.app" \
        -ov -format UDZO \
        "${DMG_PATH}"
fi

# Verify DMG was created
if [ ! -f "${DMG_PATH}" ]; then
    print_error "DMG creation failed"
    exit 1
fi

FILE_SIZE=$(stat -f%z "${DMG_PATH}")
print_success "DMG created: ${DMG_PATH} (${FILE_SIZE} bytes)"

# ═══════════════════════════════════════════════════════════════════════════════
# Step 5: Notarize DMG
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$SKIP_NOTARIZE" = true ]; then
    print_step "Step 5: Notarization (SKIPPED)"
else
    print_step "Step 5: Notarizing DMG"

    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "notarization" \
        --wait

    print_info "Stapling notarization ticket..."
    xcrun stapler staple "${DMG_PATH}"

    print_success "DMG notarized and stapled"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Step 6: Sparkle Signature
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Step 6: Generating Sparkle EdDSA Signature"

SIGNATURE=""
if [ -f "${BIN_DIR}/sign_update" ]; then
    SIGNATURE=$("${BIN_DIR}/sign_update" "${DMG_PATH}" 2>&1 | grep "sparkle:edSignature" | sed 's/.*"\(.*\)".*/\1/' || echo "")

    if [ -n "$SIGNATURE" ]; then
        print_success "Signature generated"
        print_info "Signature: ${SIGNATURE:0:40}..."
    else
        print_warning "Could not extract signature automatically"
        print_info "Run manually: ${BIN_DIR}/sign_update ${DMG_PATH}"
    fi
else
    print_warning "sign_update not found, skipping signature"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Step 7: Update Appcast
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Step 7: Updating Appcast"

# Get build number from archive
BUILD_NUMBER=$(defaults read "${ARCHIVE_PATH}/Info.plist" CFBundleVersion 2>/dev/null || echo "1")
PUB_DATE=$(date -R)

# Create appcast.xml
cat > "${RELEASE_DIR}/appcast.xml" << EOF
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
                <p>See the release notes for details.</p>
            ]]></description>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url="${APPCAST_URL}/${DMG_NAME}"
                sparkle:version="${BUILD_NUMBER}"
                sparkle:shortVersionString="${VERSION}"
                sparkle:edSignature="${SIGNATURE}"
                length="${FILE_SIZE}"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
EOF

# Copy DMG to releases
cp "${DMG_PATH}" "${RELEASE_DIR}/"

# Generate checksum
shasum -a 256 "${RELEASE_DIR}/${DMG_NAME}" > "${RELEASE_DIR}/${DMG_NAME}.sha256"

print_success "Appcast updated"
print_info "Files ready in ${RELEASE_DIR}/"

# ═══════════════════════════════════════════════════════════════════════════════
# Step 8: Upload to Cloudflare R2
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$SKIP_UPLOAD" = true ]; then
    print_step "Step 8: Upload to Cloudflare R2 (SKIPPED)"
    print_info "Files to upload manually:"
    print_info "  - ${RELEASE_DIR}/${DMG_NAME}"
    print_info "  - ${RELEASE_DIR}/appcast.xml"
else
    print_step "Step 8: Uploading to Cloudflare R2"

    R2_BUCKET="rawctl-releases"

    # Check for wrangler
    if ! command -v wrangler &> /dev/null; then
        print_error "wrangler CLI not found"
        print_info "Install with: npm install -g wrangler"
        print_info "Then authenticate: wrangler login"
        SKIP_UPLOAD=true
    else
        # Upload DMG
        print_info "Uploading DMG..."
        wrangler r2 object put "${R2_BUCKET}/${DMG_NAME}" \
            --file="${RELEASE_DIR}/${DMG_NAME}" \
            --content-type="application/octet-stream" \
            --remote

        # Upload appcast.xml
        print_info "Uploading appcast.xml..."
        wrangler r2 object put "${R2_BUCKET}/appcast.xml" \
            --file="${RELEASE_DIR}/appcast.xml" \
            --content-type="application/xml" \
            --remote

        # Upload as latest
        print_info "Creating latest symlink..."
        wrangler r2 object put "${R2_BUCKET}/rawctl-latest.dmg" \
            --file="${RELEASE_DIR}/${DMG_NAME}" \
            --content-type="application/octet-stream" \
            --remote

        print_success "Uploaded to Cloudflare R2"
        print_info "DMG URL: ${APPCAST_URL}/${DMG_NAME}"
        print_info "Latest:  ${APPCAST_URL}/rawctl-latest.dmg"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Step 9: Create GitHub Release
# ═══════════════════════════════════════════════════════════════════════════════

if [ "$SKIP_UPLOAD" = true ]; then
    print_step "Step 9: GitHub Release (SKIPPED)"
else
    print_step "Step 9: Creating GitHub Release"

    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        print_warning "gh CLI not found, skipping GitHub release"
        print_info "Install with: brew install gh"
    else
        # Check if release already exists
        if gh release view "v${VERSION}" &>/dev/null; then
            print_warning "Release v${VERSION} already exists"
            print_info "Updating existing release..."
            gh release upload "v${VERSION}" "${RELEASE_DIR}/${DMG_NAME}" --clobber
        else
            print_info "Creating new release v${VERSION}..."

            # Create release with DMG
            gh release create "v${VERSION}" \
                "${RELEASE_DIR}/${DMG_NAME}" \
                --title "rawctl ${VERSION}" \
                --notes "## rawctl ${VERSION}

See [Release Notes](https://rawctl.com/#release-notes) for details.

### Downloads
- **DMG**: [rawctl-${VERSION}.dmg](${APPCAST_URL}/${DMG_NAME})
- **Latest**: [rawctl-latest.dmg](${APPCAST_URL}/rawctl-latest.dmg)

### Checksums
\`\`\`
$(cat ${RELEASE_DIR}/${DMG_NAME}.sha256)
\`\`\`
"
        fi
        print_success "GitHub Release created"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════

print_step "Release Summary"

echo ""
echo "  Version:     ${VERSION}"
echo "  Build:       ${BUILD_NUMBER}"
echo "  DMG:         ${RELEASE_DIR}/${DMG_NAME}"
echo "  Size:        ${FILE_SIZE} bytes"
echo "  SHA256:      $(cat ${RELEASE_DIR}/${DMG_NAME}.sha256 | cut -d' ' -f1)"
if [ -n "$SIGNATURE" ]; then
    echo "  Signature:   ${SIGNATURE:0:40}..."
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN - No files were uploaded"
fi

print_success "Release ${VERSION} ready!"

echo ""
echo "Next steps:"
echo "  1. Update ReleaseNotes.swift with new version (if not done)"
echo "  2. Update landing/src/sections/ReleaseNotes.tsx"
echo "  3. Deploy landing page: cd landing && npm run build"
echo "  4. Test update in app: rawctl → Check for Updates"
echo ""
echo "URLs:"
echo "  Appcast:  ${APPCAST_URL}/appcast.xml"
echo "  DMG:      ${APPCAST_URL}/${DMG_NAME}"
echo "  GitHub:   https://github.com/nicholaschuayunzhi/rawctl/releases/tag/v${VERSION}"
echo ""
