#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_NAME="DualLecturePresenter"
APP_NAME="쌤쌤이"
BUNDLE_DIR="$PROJECT_DIR/${APP_NAME}.app"
VERSION="${1:-0.1.0}"

echo "🔨 Building Release binary for ${BIN_NAME} (${APP_NAME} v${VERSION})..."
swift build -c release --package-path "$PROJECT_DIR"

echo "📦 Assembling ${APP_NAME}.app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
cp "$PROJECT_DIR/.build/release/$BIN_NAME" "$BUNDLE_DIR/Contents/MacOS/$BIN_NAME"

# Copy AppIcon if exists
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
fi

# Copy Sample PDFs if exist
if [ -f "$PROJECT_DIR/../Sample_Instructor.pdf" ]; then
    cp "$PROJECT_DIR/../Sample_Instructor.pdf" "$BUNDLE_DIR/Contents/Resources/"
fi
if [ -f "$PROJECT_DIR/../Sample_Student.pdf" ]; then
    cp "$PROJECT_DIR/../Sample_Student.pdf" "$BUNDLE_DIR/Contents/Resources/"
fi

# Create Info.plist
cat << EOF > "$BUNDLE_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DualLecturePresenter</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.ssamssami</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>쌤쌤이</string>
    <key>CFBundleDisplayName</key>
    <string>쌤쌤이</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
</dict>
</plist>
EOF

# Codesign bundle (ad-hoc)
echo "🔏 Applying ad-hoc codesign..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "✅ Successfully built: $BUNDLE_DIR"
