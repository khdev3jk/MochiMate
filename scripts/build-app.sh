#!/bin/zsh
# Regenerates the sprite sheets, builds a release binary and wraps it in MochiMate.app.
set -euo pipefail
cd "$(dirname "$0")/.."
# The in-app updater compares this with the newest GitHub release tag (vX.Y.Z).
VERSION=${VERSION:-1.0.0}

swift run -c release SpriteGen
swift build -c release --product MochiMate

APP=build/MochiMate.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/MochiMate" "$APP/Contents/MacOS/"
cp -R Sources/MochiMate/Resources/Sprites Sources/MochiMate/Resources/Content "$APP/Contents/Resources/"
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.mochimate.app</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleName</key><string>MochiMate</string>
    <key>CFBundleExecutable</key><string>MochiMate</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MochiMate cần điều khiển Finder để nhân vật đá icon trên Desktop (chỉ khi bạn bật tính năng này).</string>
</dict>
</plist>
PLIST

# Ad-hoc by default; set SIGN_IDENTITY (see `security find-identity -v -p codesigning`) to keep permissions between builds.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP"
