"""
Chương trình Tách & Xuất Sách PDF với giao diện người dùng (UI)
"""
from pypdf import PdfReader, PdfWriter
from app import PdfSplitterApp


def split_pdf_in_half(input_path, output_part1="part_1.pdf", output_part2="part_2.pdf"):
    """
    Hàm CLI / Script tách PDF làm đôi
    """
    reader = PdfReader(input_path)
    total_pages = len(reader.pages)

    # Tính điểm chia (nếu số trang lẻ, phần 1 sẽ nhiều hơn 1 trang)
    mid_point = (total_pages + 1) // 2

    # Ghi phần 1
    writer1 = PdfWriter()
    for page in reader.pages[:mid_point]:
        writer1.add_page(page)
    with open(output_part1, "wb") as f:
        writer1.write(f)

    # Ghi phần 2
    writer2 = PdfWriter()
    for page in reader.pages[mid_point:]:
        writer2.add_page(page)
    with open(output_part2, "wb") as f:
        writer2.write(f)

    print(f"Đã tách thành công:")
    print(f"- {output_part1}: trang 1 đến {mid_point} ({mid_point} trang)")
    print(
        f"- {output_part2}: trang {mid_point + 1} đến {total_pages} ({total_pages - mid_point} trang)"
    )


if __name__ == "__main__":
    # Khởi chạy giao diện người dùng
    app = PdfSplitterApp()
    app.mainloop()
