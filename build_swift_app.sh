#!/bin/bash
set -e

APP_NAME="PdfSplitter.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Bắt đầu biên dịch và đóng gói $APP_NAME thuần Native Swift..."

# 1. Biên dịch binary Swift ở chế độ Release
swift build -c release

RELEASE_BIN="$(swift build -c release --show-bin-path)/PdfSplitter"

if [ ! -f "$RELEASE_BIN" ]; then
    echo "❌ Không tìm thấy file binary đã biên dịch tại: $RELEASE_BIN"
    exit 1
fi

# 2. Tạo cấu trúc thư mục .app
rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Copy binary thực thi vào MacOS
cp "$RELEASE_BIN" "$MACOS_DIR/PdfSplitter"
chmod +x "$MACOS_DIR/PdfSplitter"

# 4. Copy AppIcon vào Resources nếu có
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$RESOURCES_DIR/"
fi

# 5. Tạo file Info.plist chuẩn macOS
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PdfSplitter</string>
    <key>CFBundleDisplayName</key>
    <string>Sách PDF Pro</string>
    <key>CFBundleIdentifier</key>
    <string>com.pdfsplitter.swiftapp</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>PdfSplitter</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_fb-sync._tcp</string>
        <string>_fb-sync._udp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Ứng dụng cần sử dụng mạng cục bộ để đồng bộ sách và nét vẽ Apple Pencil với iPad.</string>
</dict>
</plist>
EOF

# 6. Ký số Ad-hoc trên macOS
if command -v codesign >/dev/null 2>&1; then
    echo "🔏 Đang ký số ứng dụng (Ad-hoc signature)..."
    codesign --force --deep -s - "$APP_NAME"
fi

echo "========================================================="
echo "🎉 THÀNH CÔNG! Đã đóng gói ứng dụng Native Swift: $APP_NAME"
echo "👉 Bạn có thể mở trực tiếp bằng lệnh: open $APP_NAME"
echo "👉 Hoặc kéo thả $APP_NAME vào thư mục /Applications"
echo "========================================================="
