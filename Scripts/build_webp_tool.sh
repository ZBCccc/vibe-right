#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
VERSION="1.6.0"
DEPLOYMENT_TARGET="13.0"
SOURCE_SHA256="e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564"
SOURCE_URL="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${VERSION}.tar.gz"
BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/VibeRightWebP.XXXXXX")"
OUTPUT="$ROOT_DIR/Resources/Tools/webp-encoder"

cleanup() {
  case "$BUILD_ROOT" in
    "${TMPDIR:-/tmp}"/VibeRightWebP.*) rm -rf -- "$BUILD_ROOT" ;;
    *) echo "Refusing to remove unexpected build directory: $BUILD_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT

ARCHIVE="$BUILD_ROOT/libwebp.tar.gz"
curl -fL --retry 3 -o "$ARCHIVE" "$SOURCE_URL"
ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$SOURCE_SHA256" ]]; then
  echo "libwebp source checksum mismatch" >&2
  exit 1
fi
tar -xzf "$ARCHIVE" -C "$BUILD_ROOT"
SOURCE_DIR="$BUILD_ROOT/libwebp-${VERSION}"

for ARCH in arm64 x86_64; do
  ARCH_BUILD="$BUILD_ROOT/build-$ARCH"
  mkdir -p "$ARCH_BUILD"
  HOST_OPTIONS=()
  if [[ "$ARCH" == "x86_64" && "$(uname -m)" != "x86_64" ]]; then
    HOST_OPTIONS=(--build=aarch64-apple-darwin --host=x86_64-apple-darwin)
  fi
  (
    cd "$ARCH_BUILD"
    CC="clang -arch $ARCH" \
      CFLAGS="-O3 -mmacosx-version-min=$DEPLOYMENT_TARGET" \
      LDFLAGS="-arch $ARCH -mmacosx-version-min=$DEPLOYMENT_TARGET" \
      "$SOURCE_DIR/configure" \
        "${HOST_OPTIONS[@]}" \
        --disable-shared \
        --enable-static \
        --disable-libwebpmux \
        --disable-libwebpdemux \
        --disable-png \
        --disable-jpeg \
        --disable-tiff \
        --disable-gif \
        --disable-dependency-tracking
    make -j"$(sysctl -n hw.ncpu)"
    clang \
      -arch "$ARCH" \
      -mmacosx-version-min="$DEPLOYMENT_TARGET" \
      -O3 \
      "$ROOT_DIR/Sources/Tools/WebPEncoder.c" \
      -I"$SOURCE_DIR/src" \
      "$ARCH_BUILD/src/.libs/libwebp.a" \
      "$ARCH_BUILD/sharpyuv/.libs/libsharpyuv.a" \
      -framework CoreFoundation \
      -framework CoreGraphics \
      -framework ImageIO \
      -o "$BUILD_ROOT/webp-encoder-$ARCH"
  )
done

mkdir -p "${OUTPUT:h}"
lipo -create \
  "$BUILD_ROOT/webp-encoder-arm64" \
  "$BUILD_ROOT/webp-encoder-x86_64" \
  -output "$OUTPUT"
chmod 755 "$OUTPUT"
codesign --force --sign - "$OUTPUT"

file "$OUTPUT"
for ARCH in arm64 x86_64; do
  xcrun vtool -show-build -arch "$ARCH" "$OUTPUT" | grep -q "minos $DEPLOYMENT_TARGET"
done
echo "Built: $OUTPUT"
