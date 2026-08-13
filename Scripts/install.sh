#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SOURCE_APP="$ROOT_DIR/dist/灵犀右键.app"
INSTALL_ROOT="/Applications"
TARGET_APP="$INSTALL_ROOT/灵犀右键.app"
EXTENSION_ID="com.vibecoding.VibeRight.FinderExtension"
mkdir -p "$INSTALL_ROOT"
INSTALL_TEMP="$(mktemp -d "$INSTALL_ROOT/.VibeRightInstall.XXXXXX")"
STAGED_APP="$INSTALL_TEMP/灵犀右键.app"
BACKUP_APP="$INSTALL_TEMP/previous.app"

cleanup() {
  case "$INSTALL_TEMP" in
    "$INSTALL_ROOT"/.VibeRightInstall.*) rm -rf -- "$INSTALL_TEMP" ;;
    *) echo "Refusing to remove unexpected install directory: $INSTALL_TEMP" >&2 ;;
  esac
}
trap cleanup EXIT

pkill -x VibeRight 2>/dev/null || true
pkill -x VibeRightFinderExtension 2>/dev/null || true
ditto "$SOURCE_APP" "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

if [[ -e "$TARGET_APP" ]]; then
  mv "$TARGET_APP" "$BACKUP_APP"
fi
if ! mv "$STAGED_APP" "$TARGET_APP"; then
  if [[ -e "$BACKUP_APP" ]]; then
    mv "$BACKUP_APP" "$TARGET_APP"
  fi
  exit 1
fi
pluginkit -a "$TARGET_APP/Contents/PlugIns/灵犀右键 Finder 扩展.appex"
pluginkit -e use -i "$EXTENSION_ID" || true
open "$TARGET_APP"

echo "Installed: $TARGET_APP"
echo "Extension: $EXTENSION_ID"
