#!/bin/bash
set -e

APP_NAME="PdfSplitter.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Bắt đầu đóng gói $APP_NAME độc lập hoàn toàn..."

# 1. Tạo cấu trúc thư mục .app
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 2. Copy file mã nguồn & tài nguyên vào Resources
cp main.py "$RESOURCES_DIR/"
cp app.py "$RESOURCES_DIR/"

if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$RESOURCES_DIR/"
fi

# 3. Copy thư viện pypdf vào Resources để app tự chứa 100% dependencies
VENV_SITE_PACKAGES=$(find .venv/lib -name "site-packages" 2>/dev/null | head -n 1)
if [ -d "$VENV_SITE_PACKAGES/pypdf" ]; then
    echo "📦 Nhúng thư viện pypdf vào trong App Bundle..."
    cp -r "$VENV_SITE_PACKAGES/pypdf" "$RESOURCES_DIR/"
fi

# 4. Tạo file Info.plist chuẩn macOS
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
    <string>com.pdfsplitter.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>PdfSplitter</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 5. Tạo script khởi chạy thực thi (Launcher) hoạt động ở mọi nơi (/Applications, Desktop, etc.)
cat << 'EOF' > "$MACOS_DIR/PdfSplitter"
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
RESOURCES_DIR="$( cd "$DIR/../Resources" >/dev/null 2>&1 && pwd )"

export PYTHONPATH="$RESOURCES_DIR:$PYTHONPATH"

# Tìm Python tương thích có sẵn trên máy
PYTHON_EXEC=""

# 1. Thử Python trong venv gốc (nếu còn nằm trong thư mục dev)
DEV_VENV="/Users/dungnguyenquoc/Dev/Pdf/.venv/bin/python"
if [ -x "$DEV_VENV" ]; then
    PYTHON_EXEC="$DEV_VENV"
# 2. Thử Homebrew Python
elif [ -x "/opt/homebrew/bin/python3" ]; then
    PYTHON_EXEC="/opt/homebrew/bin/python3"
# 3. Thử /usr/local/bin/python3
elif [ -x "/usr/local/bin/python3" ]; then
    PYTHON_EXEC="/usr/local/bin/python3"
# 4. Thử lệnh python3 trong PATH
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_EXEC="$(command -v python3)"
# 5. Thử /usr/bin/python3
elif [ -x "/usr/bin/python3" ]; then
    PYTHON_EXEC="/usr/bin/python3"
fi

if [ -z "$PYTHON_EXEC" ]; then
    osascript -e 'display alert "Lỗi khởi chạy Sách PDF Pro" message "Không tìm thấy Python 3 trên hệ thống macOS."'
    exit 1
fi

cd "$RESOURCES_DIR"
exec "$PYTHON_EXEC" "$RESOURCES_DIR/main.py"
EOF

chmod +x "$MACOS_DIR/PdfSplitter"

echo "✅ Đã đóng gói thành công: $APP_NAME (Tự chứa thư viện pypdf & chạy được trong /Applications)"
