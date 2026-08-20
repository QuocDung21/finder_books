import SwiftUI
import AppKit

// MARK: - Book Item Model
struct BookItem: Identifiable, Hashable {
    let id: String // File path
    let url: URL
    let name: String
    let baseName: String
    let fileSizeMB: Double
    let pageCount: Int
    let modifiedDate: Date
    let folderURL: URL
    let folderName: String
    var isSelected: Bool = false
    
    var formattedSize: String {
        String(format: "%.1f MB", fileSizeMB)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
}

// MARK: - Book Group Model
struct BookGroup: Identifiable {
    let id: String
    let title: String
    let folderURL: URL?
    var books: [BookItem]
    
    var totalSizeMB: Double {
        books.reduce(0) { $0 + $1.fileSizeMB }
    }
    
    var totalPages: Int {
        books.reduce(0) { $0 + $1.pageCount }
    }
}

// MARK: - View Mode & Sort Options
enum LibraryViewMode: String, CaseIterable, Identifiable {
    case grid = "Lưới Bìa"
    case table = "Danh Sách"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .table: return "list.bullet"
        }
    }
}

enum LibrarySortOption: String, CaseIterable, Identifiable {
    case name = "Tên Sách"
    case date = "Ngày Sửa Đổi"
    case size = "Dung Lượng"
    case pages = "Số Trang"
    
    var id: String { rawValue }
}

enum LibraryGroupMode: String, CaseIterable, Identifiable {
    case none = "Không Gom"
    case byCategory = "Theo Thể Loại"
    case byFolder = "Theo Thư Mục Con"
    case bySeries = "Theo Bộ Sách"
    
    var id: String { rawValue }
}
