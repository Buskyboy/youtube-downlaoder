#!/bin/bash
set -e

# Configuration
APP_NAME="YouTubeDownloader"
MAIN_SCRIPT="main.py"
ICON_FILE="downloading.icns"
VOLUME_NAME="YouTubeDownloader Installer"
DMG_NAME="${APP_NAME}.dmg"
DIST_PATH="dist"
APP_BUNDLE_PATH="${DIST_PATH}/${APP_NAME}.app"
DMG_TEMP="dmg_temp"

echo ""
echo "🚀 Starting macOS DMG build process..."
echo ""

# Step 1: Clean up previous builds
echo "🧹 Cleaning up previous builds..."
rm -rf "$DIST_PATH" "$DMG_TEMP" "$DMG_NAME" build *.spec 2>/dev/null || true

# Step 2: Build .app bundle with PyInstaller
echo "🔨 Building app with PyInstaller..."
pyinstaller \
  --windowed \
  --onefile \
  --name "$APP_NAME" \
  --icon="$ICON_FILE" \
  "$MAIN_SCRIPT"

echo "✅ App bundle created at $APP_BUNDLE_PATH"

# Step 3: Ensure icon is in app bundle resources
echo "📦 Copying icon to app bundle..."
mkdir -p "$APP_BUNDLE_PATH/Contents/Resources"
cp "$ICON_FILE" "$APP_BUNDLE_PATH/Contents/Resources/"

# Step 4: Create DMG staging directory
echo "📁 Creating DMG staging directory..."
rm -rf "$DMG_TEMP"
mkdir "$DMG_TEMP"

# Copy app and create Applications symlink
cp -R "$APP_BUNDLE_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# Step 5: Set DMG volume icon
echo "🎨 Setting DMG volume icon..."
cp "$ICON_FILE" "$DMG_TEMP/.VolumeIcon.icns"
chflags hidden "$DMG_TEMP/.VolumeIcon.icns" || true

# Use SetFile to assign icon (requires Xcode command line tools)
if command -v SetFile &> /dev/null; then
  SetFile -a C "$DMG_TEMP"
  echo "✅ SetFile icon assignment complete"
else
  echo "⚠️  SetFile not found. Install Xcode command line tools with: xcode-select --install"
fi

# Step 6: Create the DMG
echo "💾 Creating compressed DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

# Step 7: Clean up temporary files
echo "🧹 Cleaning up temporary files..."
rm -rf "$DMG_TEMP" build *.spec

# Step 8: Print summary
echo ""
echo "=================================================="
echo "✨ Success! DMG created successfully"
echo "=================================================="
echo "📊 File name: $DMG_NAME"
echo "📈 File size: $(du -h "$DMG_NAME" | cut -f1)"
echo "📍 Location: $(pwd)/$DMG_NAME"
echo "=================================================="
echo ""
