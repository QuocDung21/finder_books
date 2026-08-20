# 📚 Finder Books — Sách PDF Pro (Native macOS Swift App)

Ứng dụng quản lý, gom nhóm thư viện sách phong cách macOS Finder và công cụ trích xuất, phân tách PDF tốc độ cao viết bằng **SwiftUI** thuần kết hợp **Apple PDFKit**.

---

## ✨ Tính Năng Nổi Bật

### 1. 📚 Quản Lý Thư Viện Sách & Gom Nhóm Kiểu Finder
- **Quét & Quản Lý Toàn Diện**: Quét toàn bộ sách PDF trong thư mục được chỉ định, hiển thị ảnh bìa sắc nét, số trang, dung lượng MB.
- **2 Chế Độ Xem**:
  - **Lưới Bìa (Grid View)**: Xem bìa sách 3D chân thực, trực quan.
  - **Danh Sách (List View)**: Bảng chi tiết kiểu macOS Finder.
- **Gom Nhóm Sách Gọn Gàng**:
  - **Gom Vào Thư Mục Mới (New Folder with Selection)**: Gom nhanh nhiều cuốn sách được chọn vào thư mục riêng.
  - **Tự Động Gom Phần Tách**: Quét và gom các file sách đã tách (`_part1.pdf`, `_part2.pdf`,...) về thư mục gốc tương ứng.
  - **Gom Theo Bộ Sách (Series/Prefix)** hoặc theo Thư Mục Con.
- **Tìm Kiếm & Bộ Lọc Nhanh**: Tìm theo tên sách hoặc thư mục; sắp xếp theo tên, dung lượng, số trang, ngày sửa đổi.
- **1-Click Split**: Double-click hoặc bấm "Tách Sách Này" để nạp ngay cuốn sách vào trình tách.

### 2. ✂️ Tách & Xuất Sách PDF Chuyên Nghiệp
- **Kéo & Thả (Drag & Drop)**: Thả trực tiếp file PDF vào ứng dụng.
- **2 Chế Độ Phân Chia**:
  - *Chia Đều $N$ Phần*: Chia đều sách thành 2, 3, 4, ... $N$ phần với các nút preset và stepper.
  - *Mốc Trang Tùy Ý*: Cắt theo khoảng trang tùy ý, tự động lấp đầy, thêm/xoá từng phần.
- **Thanh Trực Quan Tỷ Lệ (Segment Visualizer Bar)**: Hiển thị phân đoạn màu sắc kèm số trang và %.
- **Trình Xem Nhanh (Quick Look / Preview)**:
  - Xem song song **Trang Đầu & Trang Cuối** của từng phần để kiểm tra chính xác mốc chia.
  - Trích xuất tiêu đề / trích đoạn văn bản đầu trang.
  - Chế độ duyệt từng trang với thanh trượt Slider.
- **Tiến Trình Xử Lý & Console Logs**: Theo dõi tiến độ thời gian thực với thanh progress và terminal console nền tối.
- **Âm Thanh Thông Báo**: Chuông thông báo macOS Glass khi hoàn tất xuất sách và mở nhanh thư mục kết quả trong Finder.

---

## 🚀 Cài Đặt & Khởi Chạy

### Yêu Cầu Hệ Thống:
- macOS 13.0 (Ventura) trở lên
- Hỗ trợ cả Apple Silicon (M1/M2/M3/M4) và Intel Mac

### Biên dịch & Đóng gói:
```bash
./build_swift_app.sh
```

### Mở ứng dụng:
```bash
open PdfSplitter.app
```

---

## 🛠 Công Nghệ Sử Dụng
- **Ngôn ngữ**: Swift 6 / SwiftUI
- **Framework xử lý PDF**: Apple PDFKit (`PDFDocument`, `PDFPage`)
- **Quản lý gói**: Swift Package Manager (SPM)
