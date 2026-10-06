#!/bin/sh
# Builds build/Sonar.app and build/Sonar.zip (ad-hoc signed, Apple Silicon).
# `./bundle.sh install` also copies it to /Applications so it shows up in Launchpad.
set -e
cd "$(dirname "$0")"

# SwiftUI's macros ship with Xcode, not the Command Line Tools.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed "s/^v//")}" # latest release tag, e.g. v1.1.0 -> 1.1.0
VERSION="${VERSION:-1.0}"

swift build -c release

APP=build/Sonar.app
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Sonar "$APP/Contents/MacOS/Sonar"
cp icon/Sonar.icns "$APP/Contents/Resources/Sonar.icns"
cp CHANGELOG.md "$APP/Contents/Resources/CHANGELOG.md"  # shown in Settings → About

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Sonar</string>
    <key>CFBundleDisplayName</key><string>Sonar</string>
    <key>CFBundleIdentifier</key><string>com.vladanisov.sonar</string>
    <key>CFBundleExecutable</key><string>Sonar</string>
    <key>CFBundleIconFile</key><string>Sonar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Sonar.zip
echo "Built $APP and build/Sonar.zip"

if [ "$1" = install ]; then
    pkill -x Sonar || true
    rm -rf /Applications/Sonar.app
    cp -R "$APP" /Applications/
    open /Applications/Sonar.app
    echo "Installed /Applications/Sonar.app"
fi
