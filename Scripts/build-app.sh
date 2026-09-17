#!/usr/bin/env bash
# Compiles Debrowse with swiftc and assembles a signed .app bundle in ./build.
#
# Environment overrides:
#   CONFIG=debug|release   optimisation level (default: release)
#   ARCHS="arm64 x86_64"   architectures to build; more than one produces a universal binary
#                          (default: the host architecture)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Debrowse"
BUNDLE_ID="com.debrowse.Debrowse"
MIN_MACOS="13.0"
CONFIG="${CONFIG:-release}"
ARCHS="${ARCHS:-$(uname -m)}"
if [ -z "${ARCHS// /}" ]; then
  echo "ARCHS must name at least one architecture (e.g. arm64, x86_64)" >&2
  exit 1
fi
BUILD_DIR="$ROOT/build"
OBJ_DIR="$BUILD_DIR/obj"
APP="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"

cd "$ROOT"

SDK="$(xcrun --show-sdk-path --sdk macosx)"
case "$CONFIG" in
  release) OPT_FLAGS=(-O -whole-module-optimization) ;;
  debug)   OPT_FLAGS=(-Onone -g) ;;
  *) echo "CONFIG must be 'debug' or 'release'" >&2; exit 1 ;;
esac

SOURCES=()
while IFS= read -r -d '' file; do
  SOURCES+=("$file")
done < <(find "$ROOT/Sources/Debrowse" -type f -name '*.swift' -print0 | sort -z)
if [ "${#SOURCES[@]}" -eq 0 ]; then
  echo "No Swift sources found under Sources/Debrowse" >&2
  exit 1
fi

mkdir -p "$OBJ_DIR"
SLICES=()
for ARCH in $ARCHS; do
  echo "▸ Compiling $ARCH ($CONFIG)"
  OUT="$OBJ_DIR/$APP_NAME-$ARCH"
  swiftc \
    -swift-version 5 \
    -target "$ARCH-apple-macosx$MIN_MACOS" \
    -sdk "$SDK" \
    "${OPT_FLAGS[@]}" \
    -module-name "$APP_NAME" \
    -framework AppKit \
    -framework ApplicationServices \
    -framework ServiceManagement \
    "${SOURCES[@]}" \
    -o "$OUT"
  SLICES+=("$OUT")
done
if [ "${#SLICES[@]}" -eq 0 ]; then
  echo "Nothing was compiled; check ARCHS" >&2
  exit 1
fi

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
if [ "${#SLICES[@]}" -gt 1 ]; then
  lipo -create "${SLICES[@]}" -output "$CONTENTS/MacOS/$APP_NAME"
else
  cp "${SLICES[0]}" "$CONTENTS/MacOS/$APP_NAME"
fi
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "▸ Rendering app icon"
ICONSET="$BUILD_DIR/AppIcon.iconset"
if swift "$ROOT/Scripts/make-icon.swift" "$ICONSET" && iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"; then
  rm -rf "$ICONSET"
else
  echo "  (icon generation failed; continuing without a custom icon)" >&2
fi

echo "▸ Signing (ad-hoc)"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

echo "✓ Built $APP"
