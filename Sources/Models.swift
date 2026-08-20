import SwiftUI

// MARK: - Split Modes
enum SplitMode: String, CaseIterable, Identifiable {
    case byParts = "by_parts"
    case byPages = "by_pages"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .byParts:
            return "⚡ Chế độ 1: Chia Đều Theo Số Phần (2 / 3 / 4 phần)"
        case .byPages:
            return "📑 Chế độ 2: Chia Theo Mốc Trang / Phạm Vi Tùy Ý"
        }
    }
}

// MARK: - Part Configuration / Calculation Model
struct PdfPartItem: Identifiable, Equatable {
    let id = UUID()
    var partNum: Int
    var startPage: Int
    var endPage: Int
    var filename: String
    var color: Color
    
    var pageCount: Int {
        max(0, endPage - startPage + 1)
    }
}

// MARK: - Custom Range Input Model (for UI editing)
struct CustomRangeInput: Identifiable {
    let id = UUID()
    var startPageText: String
    var endPageText: String
    var filename: String
}

// MARK: - Log Entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let icon: String
    let message: String
    
    var formattedText: String {
        "[\(timestamp)] \(icon) \(message)"
    }
}

// MARK: - Color Palette
struct AppColors {
    static let partColors: [Color] = [
        Color(red: 0.23, green: 0.51, blue: 0.96), // Blue
        Color(red: 0.55, green: 0.36, blue: 0.96), // Purple
        Color(red: 0.06, green: 0.73, blue: 0.51), // Emerald
        Color(red: 0.96, green: 0.62, blue: 0.07), // Amber
        Color(red: 0.93, green: 0.28, blue: 0.60), // Pink
        Color(red: 0.02, green: 0.71, blue: 0.83), // Cyan
        Color(red: 0.39, green: 0.40, blue: 0.95), // Indigo
        Color(red: 0.08, green: 0.72, blue: 0.65)  // Teal
    ]
    
    static func partColor(at index: Int) -> Color {
        partColors[index % partColors.count]
    }
}
