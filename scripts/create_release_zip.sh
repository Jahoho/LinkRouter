#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-}"
OUTPUT_DIR="${2:-$PROJECT_ROOT/releases}"

if [[ -z "$APP_PATH" ]]; then
  echo "Usage: scripts/create_release_zip.sh /path/to/LinkRouter.app [output-dir]" >&2
  exit 64
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle does not exist: $APP_PATH" >&2
  exit 66
fi

APP_NAME="$(basename "$APP_PATH" .app)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo dev)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo local)"
STAMP="$(date +%Y%m%d-%H%M%S)"
ZIP_NAME="${APP_NAME}-${VERSION}-${BUILD}-${STAMP}.zip"

mkdir -p "$OUTPUT_DIR"
ditto -c -k --keepParent "$APP_PATH" "$OUTPUT_DIR/$ZIP_NAME"

echo "$OUTPUT_DIR/$ZIP_NAME"
