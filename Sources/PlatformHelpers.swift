import SwiftUI
import Foundation
import PDFKit

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
public typealias PlatformViewControllerRepresentable = NSViewControllerRepresentable
public typealias PlatformViewRepresentable = NSViewRepresentable

extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}

extension Color {
    static let platformWindowBackground = Color(nsColor: .windowBackgroundColor)
    static let platformControlBackground = Color(nsColor: .controlBackgroundColor)
    static let platformTextBackground = Color(nsColor: .textBackgroundColor)
}

#elseif os(iOS)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
public typealias PlatformViewControllerRepresentable = UIViewControllerRepresentable
public typealias PlatformViewRepresentable = UIViewRepresentable

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}

extension Color {
    static let platformWindowBackground = Color(uiColor: .systemGroupedBackground)
    static let platformControlBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let platformTextBackground = Color(uiColor: .tertiarySystemGroupedBackground)
}
#endif

// MARK: - Cross-Platform PDFPage Thumbnail Helper
extension PDFPage {
    func platformThumbnail(size: CGSize) -> PlatformImage {
        #if os(macOS)
        return self.thumbnail(of: size, for: .cropBox)
        #elseif os(iOS)
        return self.thumbnail(of: size, for: .cropBox)
        #endif
    }
}

// MARK: - Cross-Platform CGImage Helper
extension PlatformImage {
    var platformCGImage: CGImage? {
        #if os(macOS)
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #elseif os(iOS)
        return self.cgImage
        #endif
    }
}

// MARK: - Flow Layout for Tags & Pills
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

