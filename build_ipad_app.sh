#!/bin/bash
set -e

BUNDLE_ID="com.quocdung.finderbooks"
EXEC_NAME="FinderBooks"
APP_NAME="Finder Books"
BUILD_DIR=".build"
OUTPUT_DIR="build"

echo "========================================================="
echo "📱 TRÌNH BUILD & ĐỒNG BỘ ỨNG DỤNG CHO IPAD (Finder Books)"
echo "========================================================="

# 1. Detect Code Signing Identity
SIGN_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F '"' '{print $2}' || true)
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
fi

# 2. Parse Arguments or Detect Devices
TARGET_MODE=""
TARGET_ID=""
TARGET_NAME=""

if [ "$1" == "physical" ] || [ "$1" == "--physical" ] || [ "$1" == "-p" ]; then
    TARGET_MODE="physical"
    TARGET_NAME="iPad của Dũng"
    TARGET_ID="F8D467D2-FB63-55D0-ACDE-06AAFC90DFEB"
elif [ "$1" == "sim" ] || [ "$1" == "--simulator" ] || [ "$1" == "-s" ]; then
    TARGET_MODE="simulator"
    TARGET_NAME="iPad mini (A17 Pro) Simulator"
    TARGET_ID="CC8638E2-3C48-4E37-9ED2-D12B20313486"
elif [ "$1" == "ipa" ] || [ "$1" == "--ipa" ]; then
    TARGET_MODE="ipa"
elif [ -n "$1" ]; then
    TARGET_MODE="custom"
    TARGET_ID="$1"
    TARGET_NAME="$1"
fi

# If no target specified in arguments, show smart menu
if [ -z "$TARGET_MODE" ]; then
    echo "🔍 Danh sách thiết bị iPad khả dụng:"
    echo "  [1] 📱 iPad của Dũng (Thiết bị iPad thật ngoài - A17 Pro)"
    echo "  [2] 💻 iPad mini (A17 Pro) Simulator"
    echo "  [3] 💻 iPad Pro 13-inch (M5) Simulator"
    echo "  [4] 📦 Xuất file cài đặt FinderBooks.ipa (Để cài qua Xcode/TrollStore/AltStore)"
    echo ""
    read -p "👉 Chọn thiết bị bạn muốn build lên [Mặc định: 1]: " CHOICE
    CHOICE=${CHOICE:-1}

    case "$CHOICE" in
        1)
            TARGET_MODE="physical"
            TARGET_NAME="iPad của Dũng"
            TARGET_ID="F8D467D2-FB63-55D0-ACDE-06AAFC90DFEB"
            ;;
        2)
            TARGET_MODE="simulator"
            TARGET_NAME="iPad mini (A17 Pro) Simulator"
            TARGET_ID="CC8638E2-3C48-4E37-9ED2-D12B20313486"
            ;;
        3)
            TARGET_MODE="simulator"
            TARGET_NAME="iPad Pro 13-inch (M5) Simulator"
            TARGET_ID="291C638C-8737-4738-ADD1-4787C2C4238F"
            ;;
        4)
            TARGET_MODE="ipa"
            ;;
        *)
            TARGET_MODE="physical"
            TARGET_NAME="iPad của Dũng"
            TARGET_ID="F8D467D2-FB63-55D0-ACDE-06AAFC90DFEB"
            ;;
    esac
fi

mkdir -p "$OUTPUT_DIR"

# =========================================================
# BUILD FOR PHYSICAL IPAD (THIẾT BỊ THẬT) / IPA
# =========================================================
if [ "$TARGET_MODE" == "physical" ] || [ "$TARGET_MODE" == "ipa" ]; then
    echo "🔨 Đang biên dịch mã nguồn cho thiết bị iPad thật (SDK: iphoneos - arm64)..."
    
    xcodebuild -scheme FinderBooks \
      -destination "generic/platform=iOS" \
      -configuration Release \
      -derivedDataPath "$BUILD_DIR/DerivedData-Device" \
      build

    BINARY_PATH=$(find "$BUILD_DIR/DerivedData-Device/Build/Products/Release-iphoneos" -name "$EXEC_NAME" -type f -perm +111 | head -n 1)

    if [ -z "$BINARY_PATH" ]; then
        echo "❌ Không tìm thấy binary iphoneos sau khi build!"
        exit 1
    fi

    IPAD_APP_DIR="$OUTPUT_DIR/FinderBooks.app"
    rm -rf "$IPAD_APP_DIR"
    mkdir -p "$IPAD_APP_DIR"

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
        <string>_fb-sync._tcp</string>
        <string>_fb-sync._udp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Ứng dụng cần sử dụng mạng cục bộ để đồng bộ sách và nét vẽ Apple Pencil với máy Mac.</string>
</dict>
</plist>
EOF

    # Code signing
    echo "🔏 Đang ký số ứng dụng với chứng chỉ ($SIGN_IDENTITY)..."
    codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$IPAD_APP_DIR" || codesign --force --sign - --timestamp=none "$IPAD_APP_DIR"

    # Package .IPA file
    echo "📦 Đang đóng gói file cài đặt FinderBooks.ipa..."
    IPA_DIR="$BUILD_DIR/IPA_Payload"
    rm -rf "$IPA_DIR"
    mkdir -p "$IPA_DIR/Payload"
    cp -R "$IPAD_APP_DIR" "$IPA_DIR/Payload/"
    cd "$IPA_DIR"
    zip -q -r "../../$OUTPUT_DIR/FinderBooks.ipa" "Payload"
    cd ../..
    rm -rf "$IPA_DIR"

    echo "✅ Đã xuất file IPA tại: $OUTPUT_DIR/FinderBooks.ipa"

    # If physical device installation requested
    if [ "$TARGET_MODE" == "physical" ]; then
        echo "📲 Đang kiểm tra kết nối với $TARGET_NAME ($TARGET_ID)..."
        
        # Try installing via devicectl
        if xcrun devicectl device install app --device "$TARGET_ID" "$IPAD_APP_DIR" 2>/dev/null; then
            echo "🚀 Đã cài đặt thành công lên $TARGET_NAME!"
            xcrun devicectl device process launch --device "$TARGET_ID" "$BUNDLE_ID" 2>/dev/null || true
            echo "🎉 Ứng dụng đã sẵn sàng trên màn hình $TARGET_NAME!"
        else
            echo "⚠️ Không thể tự động đẩy qua mạng nếu thiết bị đang khóa màn hình hoặc chưa bật Developer Mode."
            echo "👉 Bạn có thể cài trực tiếp bằng các cách sau:"
            echo "   1. Mở Xcode ➔ Window ➔ Devices and Simulators ➔ Kéo thả file '$OUTPUT_DIR/FinderBooks.ipa' vào máy iPad."
            echo "   2. Hoặc cắm cáp USB và mở khóa màn hình iPad, sau đó chạy lại lệnh: ./build_ipad_app.sh physical"
        fi
    fi

# =========================================================
# BUILD FOR SIMULATOR
# =========================================================
else
    echo "🔨 Đang biên dịch mã nguồn cho iOS Simulator ($TARGET_NAME)..."
    
    xcodebuild -project FinderBooks.xcodeproj \
      -scheme FinderBooks \
      -destination "id=$TARGET_ID" \
      -configuration Debug \
      -derivedDataPath "$BUILD_DIR/DerivedData" \
      build

    APP_BUNDLE_PATH=$(find "$BUILD_DIR/DerivedData/Build/Products/Debug-iphonesimulator" -name "FinderBooks.app" -type d | head -n 1)

    if [ -z "$APP_BUNDLE_PATH" ]; then
        echo "❌ Không tìm thấy FinderBooks.app sau khi build!"
        exit 1
    fi

    echo "📲 Đang khởi động $TARGET_NAME..."
    xcrun simctl boot "$TARGET_ID" 2>/dev/null || true
    xcrun simctl bootstatus "$TARGET_ID" -b 2>/dev/null || true
    open -a Simulator

    echo "🚀 Đang cài đặt và mở ứng dụng trên $TARGET_NAME..."
    xcrun simctl uninstall "$TARGET_ID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$TARGET_ID" "$APP_BUNDLE_PATH"
    xcrun simctl launch "$TARGET_ID" "$BUNDLE_ID"

    echo "========================================================="
    echo "🎉 THÀNH CÔNG! Đã khởi chạy Finder Books lên $TARGET_NAME!"
    echo "========================================================="
fi
