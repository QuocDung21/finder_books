import Foundation
import SwiftUI

// MARK: - Live Ink Stroke Point
struct InkPoint: Codable, Equatable {
    var x: CGFloat // Normalized [0.0, 1.0] across page width
    var y: CGFloat // Normalized [0.0, 1.0] across page height
    var pressure: CGFloat = 1.0
    
    init(x: CGFloat, y: CGFloat, pressure: CGFloat = 1.0) {
        self.x = x
        self.y = y
        self.pressure = pressure
    }
}

// MARK: - Live Ink Stroke Model
struct LiveInkStroke: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var pageIndex: Int
    var points: [InkPoint]
    var colorHex: String // e.g. "#FF3B30"
    var lineWidth: CGFloat
    var opacity: CGFloat = 1.0
    var isHighlighter: Bool = false
    var timestamp: Date = Date()
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Live Drawing Sync Packet
enum LiveSyncAction: String, Codable {
    case addStroke = "add_stroke"
    case clearPage = "clear_page"
    case jumpToPage = "jump_to_page"
    case syncAllStrokes = "sync_all"
}

struct LiveDrawingPayload: Codable {
    var action: LiveSyncAction
    var stroke: LiveInkStroke?
    var pageIndex: Int?
    var allStrokes: [LiveInkStroke]?
    var senderName: String
}

// MARK: - Hex Color Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        #if os(macOS)
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(components.redComponent * 255.0)
        let g = Int(components.greenComponent * 255.0)
        let b = Int(components.blueComponent * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
        #elseif os(iOS)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #endif
    }
}
