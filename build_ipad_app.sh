#!/bin/bash
set -e

DEVICE_NAME="iPad mini (A17 Pro)"
DEVICE_ID="CC8638E2-3C48-4E37-9ED2-D12B20313486"
BUNDLE_ID="com.quocdung.finderbooks"
EXEC_NAME="PdfSplitter"

echo "========================================================="
echo "📱 Bắt đầu Build & Khởi chạy ứng dụng lên $DEVICE_NAME..."
echo "========================================================="

# 1. Build for iOS Simulator SDK
echo "🔨 Đang biên dịch mã nguồn cho iOS Simulator ($DEVICE_NAME)..."
xcodebuild -scheme PdfSplitter \
  -destination "id=$DEVICE_ID" \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  build

BINARY_PATH=$(find .build/DerivedData/Build/Products/Debug-iphonesimulator -name "$EXEC_NAME" -type f -perm +111 | head -n 1)

if [ -z "$BINARY_PATH" ]; then
    echo "❌ Không tìm thấy file binary sau khi build!"
    exit 1
fi

echo "📦 Đã tìm thấy binary tại: $BINARY_PATH"

# 2. Package proper iOS .app Bundle
IPAD_APP_DIR=".build/FinderBooks.app"
rm -rf "$IPAD_APP_DIR"
mkdir -p "$IPAD_APP_DIR"

# Copy binary to matching executable name
cp "$BINARY_PATH" "$IPAD_APP_DIR/$EXEC_NAME"
chmod +x "$IPAD_APP_DIR/$EXEC_NAME"

# Create Info.plist for iPadOS
cat << EOF > "$IPAD_APP_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$EXEC_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Finder Books</string>
    <key>CFBundleDisplayName</key>
    <string>Finder Books</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSBonjourServices</key>
    <array>
        <string>_finderbooks-pen._tcp</string>
        <string>_finderbooks-pen._udp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Ứng dụng cần sử dụng mạng cục bộ để đồng bộ nét vẽ Apple Pencil giữa Mac và iPad.</string>
</dict>
</plist>
EOF

# Codesign the app bundle for Simulator
echo "🔏 Đang ký số ứng dụng iPad..."
codesign --force --sign - --timestamp=none "$IPAD_APP_DIR"

# 3. Boot iPad Simulator
echo "📲 Đang khởi động $DEVICE_NAME Simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
open -a Simulator

# 4. Uninstall old version & Install Fresh
echo "🚀 Đang cài đặt và mở ứng dụng trên $DEVICE_NAME..."
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_ID" "$IPAD_APP_DIR"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "========================================================="
echo "🎉 THÀNH CÔNG! Đã khởi chạy Finder Books lên $DEVICE_NAME!"
echo "========================================================="
