#!/usr/bin/env bash
set -euo pipefail

PROJECT="rawctl.xcodeproj"
SCHEME="rawctl-mas"
CONFIGURATION="Release"
INFO_PLIST="Info-MAS.plist"
DERIVED_DATA="$(mktemp -d -t latent-mas-check)"
BUILD_SETTINGS_FILE="$(mktemp -t latent-mas-settings)"
BUILD_LOG="$(mktemp -t latent-mas-build)"

cleanup() {
  rm -rf "$DERIVED_DATA" "$BUILD_SETTINGS_FILE" "$BUILD_LOG"
}
trap cleanup EXIT

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "[MAS-CHECK] Missing ${INFO_PLIST}" >&2
  exit 1
fi

if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings >"$BUILD_SETTINGS_FILE"; then
  echo "[MAS-CHECK] Unable to read build settings for ${SCHEME}" >&2
  exit 1
fi

if ! rg -q "INFOPLIST_FILE = ${INFO_PLIST}" "$BUILD_SETTINGS_FILE"; then
  echo "[MAS-CHECK] ${SCHEME} must use ${INFO_PLIST}" >&2
  exit 1
fi

if ! rg -q "SWIFT_ACTIVE_COMPILATION_CONDITIONS = .*DISTRIBUTION_CHANNEL_MAS" "$BUILD_SETTINGS_FILE"; then
  echo "[MAS-CHECK] ${SCHEME} missing DISTRIBUTION_CHANNEL_MAS compilation condition" >&2
  exit 1
fi

if rg -q "<key>SU(FeedURL|PublicEDKey|EnableAutomaticChecks|ScheduledCheckInterval|AllowsAutomaticUpdates|ShowReleaseNotes)</key>" "$INFO_PLIST"; then
  echo "[MAS-CHECK] Sparkle SU* keys are not allowed in ${INFO_PLIST}" >&2
  exit 1
fi

echo "[MAS-CHECK] Building unsigned ${SCHEME} for artifact validation..."
if ! xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build >"$BUILD_LOG" 2>&1; then
  echo "[MAS-CHECK] Build failed. Tail log:" >&2
  tail -n 120 "$BUILD_LOG" >&2
  exit 1
fi

APP_PATH="$(find "$DERIVED_DATA/Build/Products" -type d -name '*.app' | head -n 1)"
if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "[MAS-CHECK] Could not find built .app artifact" >&2
  exit 1
fi

if [[ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]]; then
  echo "[MAS-CHECK] Sparkle.framework found in MAS app bundle" >&2
  exit 1
fi

APP_BIN_DIR="$APP_PATH/Contents/MacOS"
APP_BIN="$(find "$APP_BIN_DIR" -type f | head -n 1)"
if [[ -z "${APP_BIN:-}" || ! -f "$APP_BIN" ]]; then
  echo "[MAS-CHECK] Could not find app executable inside bundle" >&2
  exit 1
fi

if otool -L "$APP_BIN" | rg -qi "Sparkle"; then
  echo "[MAS-CHECK] Executable links Sparkle" >&2
  exit 1
fi

for key in SUFeedURL SUPublicEDKey SUEnableAutomaticChecks SUScheduledCheckInterval SUAllowsAutomaticUpdates SUShowReleaseNotes; do
  if /usr/libexec/PlistBuddy -c "Print :${key}" "$APP_PATH/Contents/Info.plist" >/dev/null 2>&1; then
    echo "[MAS-CHECK] Built Info.plist still contains disallowed key ${key}" >&2
    exit 1
  fi
done

echo "[MAS-CHECK] PASS"
