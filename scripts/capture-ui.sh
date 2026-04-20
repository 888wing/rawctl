#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/export/Latent.app}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/landing/public/captures}"
FIXTURE_DIR="${FIXTURE_DIR:-/tmp/latent-capture-library}"
WINDOW_NAME="${WINDOW_NAME:-latent-capture-library}"
LIBRARY_CAPTURE="$OUTPUT_DIR/latent-library.png"
EDIT_CAPTURE="$OUTPUT_DIR/latent-edit.png"
PRIMARY_CAPTURE="$ROOT_DIR/landing/public/screenshot.png"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  echo "Build/export a Latent.app first, then rerun this script." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

cleanup() {
  launchctl unsetenv RAWCTL_E2E_FOLDER >/dev/null 2>&1 || true
}

trap cleanup EXIT

build_fixture_library() {
  rm -rf "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR"

  find '/System/Library/Desktop Pictures/.thumbnails' -type f -name '*.heic' | head -n 18 | while read -r file; do
    cp "$file" "$FIXTURE_DIR/"
  done
}

window_info() {
  local expected_name="$1"

  EXPECTED_NAME="$expected_name" swift - <<'SWIFT'
import Foundation
import CoreGraphics

let expectedName = ProcessInfo.processInfo.environment["EXPECTED_NAME"] ?? ""
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []

for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    let name = window[kCGWindowName as String] as? String ?? ""
    guard owner == "Latent" else { continue }
    if !expectedName.isEmpty && !name.localizedCaseInsensitiveContains(expectedName) {
        continue
    }

    let id = window[kCGWindowNumber as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let x = Int(bounds["X"] ?? 0)
    let y = Int(bounds["Y"] ?? 0)
    let width = Int(bounds["Width"] ?? 0)
    let height = Int(bounds["Height"] ?? 0)
    print("\(id)\t\(x)\t\(y)\t\(width)\t\(height)\t\(name)")
    exit(0)
}

exit(1)
SWIFT
}

wait_for_window() {
  local expected_name="$1"

  for _ in {1..20}; do
    if window_info "$expected_name"; then
      return 0
    fi
    sleep 1
  done

  return 1
}

click_relative() {
  local window_id="$1"
  local rel_x="$2"
  local rel_y="$3"

  WINDOW_ID="$window_id" REL_X="$rel_x" REL_Y="$rel_y" swift - <<'SWIFT'
import Foundation
import AppKit
import CoreGraphics

let windowID = Int(ProcessInfo.processInfo.environment["WINDOW_ID"] ?? "") ?? 0
let relX = Double(ProcessInfo.processInfo.environment["REL_X"] ?? "") ?? 0
let relY = Double(ProcessInfo.processInfo.environment["REL_Y"] ?? "") ?? 0

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
guard let window = windows.first(where: { ($0[kCGWindowNumber as String] as? Int ?? 0) == windowID }) else {
    exit(1)
}

let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
let x = Double(bounds["X"] ?? 0) + relX
let y = Double(bounds["Y"] ?? 0) + relY
let point = CGPoint(x: x, y: y)

NSRunningApplication.runningApplications(withBundleIdentifier: "Shacoworkshop.latent").first?.activate()
usleep(300_000)

for type in [CGEventType.leftMouseDown, .leftMouseUp] {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
    event?.post(tap: .cghidEventTap)
    usleep(50_000)
}
SWIFT
}

quit_new_instances() {
  local before="$1"
  local after="$2"

  for pid in $after; do
    if ! grep -qx "$pid" <<<"$before"; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
}

build_fixture_library

before_pids="$(pgrep -x Latent || true)"
launchctl setenv RAWCTL_E2E_FOLDER "$FIXTURE_DIR"
open -na "$APP_PATH"
sleep 6
launchctl unsetenv RAWCTL_E2E_FOLDER

window_line="$(wait_for_window "$WINDOW_NAME")" || {
  echo "Could not locate a Latent window for $WINDOW_NAME" >&2
  exit 1
}

window_id="$(printf '%s\n' "$window_line" | cut -f1)"
screencapture -l "$window_id" -x "$LIBRARY_CAPTURE"
cp "$LIBRARY_CAPTURE" "$PRIMARY_CAPTURE"

# Pick a colorful asset in the center-right column, then switch to the single-image view.
click_relative "$window_id" 441 215
sleep 1
click_relative "$window_id" 205 18
sleep 2
screencapture -l "$window_id" -x "$EDIT_CAPTURE"

after_pids="$(pgrep -x Latent || true)"
quit_new_instances "$before_pids" "$after_pids"

echo "Captured:"
echo "  $LIBRARY_CAPTURE"
echo "  $EDIT_CAPTURE"
echo "  $PRIMARY_CAPTURE"
