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

// MARK: - Local Wi-Fi IP Helper
func getLocalIPAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let flags = Int32(ptr.pointee.ifa_flags)
        var addr = ptr.pointee.ifa_addr.pointee
        if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
            if addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(&ptr.pointee.ifa_addr.pointee, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                    let name = String(cString: ptr.pointee.ifa_name)
                    if name == "en0" || name == "en1" || name.starts(with: "en") || name.starts(with: "wlan") {
                        address = String(cString: hostname)
                        break
                    }
                }
            }
        }
    }
    freeifaddrs(ifaddr)
    return address
}


