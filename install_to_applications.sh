#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$PROJECT_DIR/쌤쌤이.app"
APP_DEST="/Applications/쌤쌤이.app"
OLD_APP_DEST="/Applications/DualLecturePresenter.app"

if [ ! -d "$APP_SRC" ]; then
    echo "🔨 Building app first..."
    "$PROJECT_DIR/build_app.sh"
fi

echo "📦 Installing to /Applications..."
rm -rf "$OLD_APP_DEST"
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"
codesign --force --deep --sign - "$APP_DEST"

echo "✅ Installed successfully to: $APP_DEST"
echo "🚀 Launching 쌤쌤이 from /Applications..."
open "$APP_DEST"
