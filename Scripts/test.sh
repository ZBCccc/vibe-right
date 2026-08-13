#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
BUILD_DIR="$ROOT_DIR/.build/tests"
mkdir -p "$BUILD_DIR"

swiftc \
  -swift-version 5 \
  -framework AppKit \
  -framework CoreImage \
  "$ROOT_DIR/Sources/Core/Models.swift" \
  "$ROOT_DIR/Sources/Core/FileOperations.swift" \
  "$ROOT_DIR/Sources/Core/TerminalAutomation.swift" \
  "$ROOT_DIR/Tests/CoreTests.swift" \
  -o "$BUILD_DIR/CoreTests"

"$BUILD_DIR/CoreTests"
