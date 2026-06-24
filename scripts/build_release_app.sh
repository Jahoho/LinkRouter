#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${1:-/private/tmp/LinkRouterReleaseBuild}"
CONFIGURATION="${CONFIGURATION:-Release}"

xcodebuild \
  -quiet \
  -project "$PROJECT_ROOT/LinkRouter.xcodeproj" \
  -scheme LinkRouter \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/LinkRouter.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app was not found at: $APP_PATH" >&2
  exit 66
fi

echo "$APP_PATH"
