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
