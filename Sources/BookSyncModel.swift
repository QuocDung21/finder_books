import Foundation
import SwiftUI

// MARK: - Book Sync Comparison Status
enum BookSyncStatus: Equatable {
    case newBook
    case duplicate(existingPath: String, existingName: String)
    
    var title: String {
        switch self {
        case .newBook:
            return "Sách Mới (Chưa có)"
        case .duplicate:
            return "Đã Tồn Tại Trong Kho"
        }
    }
    
    var color: Color {
        switch self {
        case .newBook: return .green
        case .duplicate: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .newBook: return "plus.circle.fill"
        case .duplicate: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Action for Scanned Book
enum BookSyncAction: String, CaseIterable, Identifiable {
    case moveToLibrary = "Di Chuyển Về Kho"
    case deleteFromSource = "Xoá File Trùng Ở Nguồn"
    case skip = "Bỏ Qua"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .moveToLibrary: return "arrow.right.circle"
        case .deleteFromSource: return "trash"
        case .skip: return "forward"
        }
    }
}

// MARK: - Scanned Sync Item
struct ScannedSyncItem: Identifiable {
    let id: String // sourceURL.path
    let sourceURL: URL
    let name: String
    let baseName: String
    let fileSizeMB: Double
    let pageCount: Int
    let modifiedDate: Date
    var status: BookSyncStatus
    var action: BookSyncAction
    var isSelected: Bool = true
    
    var formattedSize: String {
        String(format: "%.1f MB", fileSizeMB)
    }
}

// MARK: - Sync Summary Result
struct SyncExecutionSummary {
    var movedCount: Int = 0
    var deletedCount: Int = 0
    var skippedCount: Int = 0
    var errorCount: Int = 0
}
