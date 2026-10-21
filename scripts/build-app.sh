#!/usr/bin/env bash
# Builds TextPolish.app into ./build. Set SIGN_IDENTITY to a codesigning identity
# (e.g. "Apple Development: You (TEAMID)") to keep the Accessibility grant across rebuilds;
# without one the app is ad-hoc signed and macOS asks for Accessibility again after each rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/TextPolish.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TextPolish"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TextPolish"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.local.textpolish</string>
    <key>CFBundleName</key>
    <string>Text Polish</string>
    <key>CFBundleDisplayName</key>
    <string>Text Polish</string>
    <key>CFBundleExecutable</key>
    <string>TextPolish</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP (signed with ${SIGN_IDENTITY:-ad-hoc identity})"
