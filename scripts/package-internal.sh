#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Agent永动机"
BUNDLE_ID="local.agent-yongdongji"
VERSION="${VERSION:-0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:-2}"

# === GitHub Release 配置 ===
GITHUB_OWNER="${GITHUB_OWNER:-Bbbtt04}"
GITHUB_REPO="${GITHUB_REPO:-screensaver}"
APPCAST_URL="${APPCAST_URL:-https://raw.githubusercontent.com/$GITHUB_OWNER/$GITHUB_REPO/main/appcast.xml}"

# Sparkle EdDSA 公钥（由 generate_keys 生成）
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-VUIugHtxsVA6LW6zrv/MCiFtHU5z9NGLiI7rhTvS2SY=}"

DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
STAGE_DIR="$DIST_DIR/dmg-stage"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
ASSETS_DIR="$ROOT_DIR/assets"
ICON_SOURCE_PATH="$ASSETS_DIR/AppIconSource.png"
ICONSET_PATH="$ASSETS_DIR/AppIcon.iconset"
ICON_PATH="$ASSETS_DIR/AppIcon.icns"

cd "$ROOT_DIR"

echo "==> Building release binary"
swift build -c release --product agent-privacy-lock-client
BIN_DIR="$(swift build -c release --show-bin-path)"
CLIENT_BIN="$BIN_DIR/agent-privacy-lock-client"

if [[ ! -x "$CLIENT_BIN" ]]; then
  echo "Missing release binary: $CLIENT_BIN" >&2
  exit 1
fi

echo "==> Generating app icon"
rm -rf "$ICONSET_PATH" "$ICON_PATH"
mkdir -p "$ASSETS_DIR"
if [[ -f "$ICON_SOURCE_PATH" ]]; then
  echo "    using $ICON_SOURCE_PATH"
  mkdir -p "$ICONSET_PATH"
  sips -z 16 16 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE_PATH" --out "$ICONSET_PATH/icon_512x512@2x.png" >/dev/null
else
  echo "    using generated fallback icon; put exact art at assets/AppIconSource.png to override"
  swift "$ROOT_DIR/scripts/render-app-icon.swift" "$ICONSET_PATH"
fi
iconutil -c icns "$ICONSET_PATH" -o "$ICON_PATH"

echo "==> Creating app bundle"
rm -rf "$APP_PATH" "$STAGE_DIR" "$DMG_PATH"
rm -rf "$DIST_DIR/隐幕守护.app" "$DIST_DIR/隐幕守护.dmg"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$CLIENT_BIN" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$ICON_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"

cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSUIElement</key>
  <true/>
  <key>SUFeedURL</key>
  <string>$APPCAST_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUCheckInterval</key>
  <integer>86400</integer>
</dict>
</plist>
EOF

echo "==> Embedding Sparkle framework"
swift package resolve 2>/dev/null || true

SPARKLE_XCFW="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework"

if [[ ! -d "$SPARKLE_XCFW" ]]; then
  echo "ERROR: Sparkle.xcframework not found at $SPARKLE_XCFW" >&2
  echo "Run: swift package resolve" >&2
  exit 1
fi

SPARKLE_FW_SRC="$SPARKLE_XCFW/macos-arm64_x86_64/Sparkle.framework"

if [[ ! -d "$SPARKLE_FW_SRC" ]]; then
  echo "ERROR: Sparkle.framework not found at $SPARKLE_FW_SRC" >&2
  exit 1
fi

mkdir -p "$APP_PATH/Contents/Frameworks"
cp -R "$SPARKLE_FW_SRC" "$APP_PATH/Contents/Frameworks/Sparkle.framework"

XPC_SRC="$SPARKLE_FW_SRC/Versions/B/XPCServices"
if [[ -d "$XPC_SRC" ]]; then
  mkdir -p "$APP_PATH/Contents/XPCServices"
  cp -R "$XPC_SRC/." "$APP_PATH/Contents/XPCServices/"
  echo "    Copied XPC services: $(ls "$APP_PATH/Contents/XPCServices/")"
else
  echo "    Warning: XPC services dir not found at $XPC_SRC"
fi

install_name_tool \
  -add_rpath "@executable_path/../Frameworks" \
  "$APP_PATH/Contents/MacOS/$APP_NAME" 2>/dev/null || true

echo "==> Ad-hoc signing app bundle"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Creating DMG"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Verifying DMG"
hdiutil imageinfo "$DMG_PATH" > /dev/null

echo "Done: $DMG_PATH"
echo
echo "Internal testing notes:"
echo "- This build is ad-hoc signed and not notarized."
echo "- Testers may need to right-click the app and choose Open the first time."
echo "- Testers still need to grant Accessibility and Input Monitoring permissions."
