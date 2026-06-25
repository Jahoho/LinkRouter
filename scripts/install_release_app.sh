#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${1:-/private/tmp/LinkRouterReleaseInstallBuild}"
INSTALL_PATH="${INSTALL_PATH:-/Applications/LinkRouter.app}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if pgrep -x LinkRouter >/dev/null 2>&1; then
  echo "LinkRouter is currently running. Quit it before replacing the app bundle." >&2
  exit 69
fi

APP_PATH="$("$PROJECT_ROOT/scripts/build_release_app.sh" "$DERIVED_DATA_PATH")"

ditto "$APP_PATH" "$INSTALL_PATH"
"$LSREGISTER" -f "$INSTALL_PATH"

echo "$INSTALL_PATH"
