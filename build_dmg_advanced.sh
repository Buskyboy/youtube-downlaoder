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
DMG_RW="${APP_NAME}_rw.dmg"

echo ""
echo "🚀 Starting macOS DMG build process with icon..."
echo ""

# Step 1: Clean up previous builds
echo "🧹 Cleaning up previous builds..."
rm -rf "$DIST_PATH" "$DMG_TEMP" "$DMG_NAME" "$DMG_RW" build *.spec 2>/dev/null || true

# Step 2: Build .app bundle with PyInstaller
echo "🔨 Building app with PyInstaller..."
pyinstaller \
  --windowed \
  --onefile \
  --name "$APP_NAME" \
  --icon="$ICON_FILE" \
  "$MAIN_SCRIPT"

echo "✅ App bundle created"

# Step 3: Verify and copy icon to bundle
echo "📦 Embedding icon in app bundle..."
if [ ! -f "$ICON_FILE" ]; then
  echo "❌ Error: Icon file '$ICON_FILE' not found!"
  exit 1
fi

mkdir -p "$APP_BUNDLE_PATH/Contents/Resources"
cp "$ICON_FILE" "$APP_BUNDLE_PATH/Contents/Resources/"
echo "✅ Icon embedded in app bundle"

# Step 4: Create DMG staging directory
echo "📁 Creating DMG staging directory..."
rm -rf "$DMG_TEMP"
mkdir "$DMG_TEMP"

# Copy app
cp -R "$APP_BUNDLE_PATH" "$DMG_TEMP/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP/Applications"

# Step 5: Create read-write DMG from folder
echo "💿 Creating read-write DMG..."
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$DMG_RW"

echo "✅ Read-write DMG created"

# Step 6: Mount the DMG and set icon
echo "🎨 Mounting DMG and setting icon..."
MOUNT_POINT=$(hdiutil attach "$DMG_RW" | grep /Volumes | awk '{print $NF}')
echo "Mounted at: $MOUNT_POINT"

# Copy icon to volume
cp "$ICON_FILE" "$MOUNT_POINT/.VolumeIcon.icns"

# Hide the icon file
chflags hidden "$MOUNT_POINT/.VolumeIcon.icns"

# Set the volume icon using SetFile
if command -v SetFile &> /dev/null; then
  # Set the custom icon attribute
  SetFile -a C "$MOUNT_POINT"
  echo "✅ Volume icon set with SetFile"
else
  echo "⚠️  SetFile not available - icon may not display properly"
  echo "   Install Xcode CLI tools: xcode-select --install"
fi

# Force Finder to update
touch "$MOUNT_POINT"

# Step 7: Unmount and finalize
echo "📤 Unmounting DMG..."
hdiutil detach "$MOUNT_POINT"

# Step 8: Convert to compressed format
echo "🗜️  Converting to compressed DMG..."
hdiutil convert "$DMG_RW" \
  -format UDZO \
  -o "$DMG_NAME"

echo "✅ DMG compressed successfully"

# Step 9: Clean up
echo "🧹 Cleaning up temporary files..."
rm -f "$DMG_RW"
rm -rf "$DMG_TEMP" build *.spec

# Step 10: Verify icon
echo ""
echo "=================================================="
echo "✨ Success! DMG created with icon"
echo "=================================================="
echo "📊 File name: $DMG_NAME"
echo "📈 File size: $(du -h "$DMG_NAME" | cut -f1)"
echo "📍 Location: $(pwd)/$DMG_NAME"
echo ""
echo "🔍 To verify the icon was embedded:"
echo "   hdiutil info '$DMG_NAME' | grep -i icon"
echo "=================================================="
echo ""
