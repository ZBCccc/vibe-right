#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/灵犀右键.app"
EXT_DIR="$APP_DIR/Contents/PlugIns/灵犀右键 Finder 扩展.appex"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" \
  "$APP_DIR/Contents/MacOS" \
  "$APP_DIR/Contents/Resources" \
  "$EXT_DIR/Contents/MacOS" \
  "$EXT_DIR/Contents/Resources"

swiftc \
  -swift-version 5 \
  -O \
  -module-name VibeRight \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreImage \
  -framework FinderSync \
  "$ROOT_DIR/Sources/Core/Localization.swift" \
  "$ROOT_DIR/Sources/Core/Models.swift" \
  "$ROOT_DIR/Sources/Core/FinderActionRequest.swift" \
  "$ROOT_DIR/Sources/Core/FinderContext.swift" \
  "$ROOT_DIR/Sources/Core/FinderScope.swift" \
  "$ROOT_DIR/Sources/Core/FileOperations.swift" \
  "$ROOT_DIR/Sources/Core/TerminalAutomation.swift" \
  "$ROOT_DIR/Sources/Core/TextServices.swift" \
  "$ROOT_DIR/Sources/FinderExtension/FinderSync.swift" \
  "$ROOT_DIR/Sources/App/Main.swift" \
  "$ROOT_DIR/Sources/App/AlternateMenuTriggerController.swift" \
  "$ROOT_DIR/Sources/App/FinderActionCoordinator.swift" \
  "$ROOT_DIR/Sources/App/MainWindowController.swift" \
  -o "$APP_DIR/Contents/MacOS/VibeRight"

clang \
  -fmodules \
  -c "$ROOT_DIR/Sources/FinderExtension/ExtensionMain.m" \
  -o "$BUILD_DIR/ExtensionMain.o"

swiftc \
  -swift-version 5 \
  -O \
  -parse-as-library \
  -module-name VibeRightFinderExtension \
  -framework AppKit \
  -framework CoreImage \
  -framework FinderSync \
  "$ROOT_DIR/Sources/Core/Localization.swift" \
  "$ROOT_DIR/Sources/Core/Models.swift" \
  "$ROOT_DIR/Sources/Core/FinderActionRequest.swift" \
  "$ROOT_DIR/Sources/Core/FinderContext.swift" \
  "$ROOT_DIR/Sources/Core/FinderScope.swift" \
  "$ROOT_DIR/Sources/Core/FileOperations.swift" \
  "$ROOT_DIR/Sources/Core/TerminalAutomation.swift" \
  "$ROOT_DIR/Sources/Core/TextServices.swift" \
  "$ROOT_DIR/Sources/FinderExtension/FinderSync.swift" \
  "$BUILD_DIR/ExtensionMain.o" \
  -o "$EXT_DIR/Contents/MacOS/VibeRightFinderExtension"

cp "$ROOT_DIR/Resources/App-Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/Extension-Info.plist" "$EXT_DIR/Contents/Info.plist"
cp -RX "$ROOT_DIR/Resources/Templates" "$APP_DIR/Contents/Resources/"
cp -RX "$ROOT_DIR/Resources/Templates" "$EXT_DIR/Contents/Resources/"
cp -RX "$ROOT_DIR/Resources/Localization.bundle" "$APP_DIR/Contents/Resources/"
cp -RX "$ROOT_DIR/Resources/Localization.bundle" "$EXT_DIR/Contents/Resources/"
cp -RX "$ROOT_DIR/Resources/AppLocalizations/." "$APP_DIR/Contents/Resources/"

plutil -lint "$APP_DIR/Contents/Info.plist" "$EXT_DIR/Contents/Info.plist"
codesign --force --sign - --entitlements "$ROOT_DIR/Resources/Extension.entitlements" "$EXT_DIR"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built: $APP_DIR"
