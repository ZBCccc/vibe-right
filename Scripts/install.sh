#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SOURCE_APP="$ROOT_DIR/dist/灵犀右键.app"
INSTALL_ROOT="/Applications"
TARGET_APP="$INSTALL_ROOT/灵犀右键.app"
EXTENSION_ID="com.vibecoding.VibeRight.FinderExtension"

mkdir -p "$INSTALL_ROOT"
pkill -x VibeRight 2>/dev/null || true
pkill -x VibeRightFinderExtension 2>/dev/null || true
ditto "$SOURCE_APP" "$TARGET_APP"
pluginkit -a "$TARGET_APP/Contents/PlugIns/灵犀右键 Finder 扩展.appex"
pluginkit -e use -i "$EXTENSION_ID" || true
open "$TARGET_APP"

echo "Installed: $TARGET_APP"
echo "Extension: $EXTENSION_ID"
