import SwiftUI
import PDFKit

struct QuickPreviewSheet: View {
    @ObservedObject var vm: AppViewModel
    let part: PdfPartItem
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPage: Int
    @State private var viewMode: PreviewMode = .startAndEnd
    
    enum PreviewMode: String, CaseIterable, Identifiable {
        case startAndEnd = "Trang Đầu & Cuối"
        case allPages = "Duyệt Từng Trang"
        
        var id: String { rawValue }
    }
    
    init(vm: AppViewModel, part: PdfPartItem) {
        self.vm = vm
        self.part = part
        _selectedPage = State(initialValue: part.startPage)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(part.color)
                        .frame(width: 12, height: 12)
                    
                    Text("Phần \(part.partNum)")
                        .font(.system(size: 15, weight: .bold))
                }
                
                Text("•  Trang \(part.startPage) ➔ \(part.endPage) (\(part.pageCount) trang)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("Chế độ xem", selection: $viewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.platformControlBackground)
            
            Divider()
            
            // Content
            ScrollView(.vertical, showsIndicators: true) {
                if viewMode == .startAndEnd {
                    startAndEndView
                } else {
                    singlePageBrowserView
                }
            }
            .padding(20)
            
            Divider()
            
            // Footer
            HStack {
                Text("Tên file xuất: \(part.filename)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Đóng (Esc)") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.platformControlBackground)
        }
        .frame(minWidth: 700, minHeight: 520)
    }
    
    // MARK: - Dual View (Start & End Pages)
    private var startAndEndView: some View {
        HStack(alignment: .top, spacing: 20) {
            // Start Page Card
            pageCardView(
                title: "Trang Bắt Đầu (Trang \(part.startPage))",
                pageNumber: part.startPage,
                badgeColor: .green
            )
            
            // End Page Card
            pageCardView(
                title: "Trang Kết Thúc (Trang \(part.endPage))",
                pageNumber: part.endPage,
                badgeColor: .orange
            )
        }
    }
    
    // MARK: - Single Page Browser
    private var singlePageBrowserView: some View {
        VStack(spacing: 16) {
            // Page Navigator Controls
            HStack(spacing: 12) {
                Button {
                    if selectedPage > part.startPage {
                        selectedPage -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(selectedPage <= part.startPage)
                
                Text("Trang \(selectedPage) / \(part.endPage)")
                    .font(.system(size: 13, weight: .bold))
                
                Button {
                    if selectedPage < part.endPage {
                        selectedPage += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(selectedPage >= part.endPage)
                
                if part.pageCount > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(selectedPage) },
                            set: { selectedPage = Int($0) }
                        ),
                        in: Double(part.startPage)...Double(part.endPage),
                        step: 1
                    )
                    .frame(width: 200)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.platformControlBackground)
            .cornerRadius(8)
            
            // Single Page Content Card
            pageCardView(
                title: "Nội dung Trang \(selectedPage)",
                pageNumber: selectedPage,
                badgeColor: .accentColor,
                isFullWidth: true
            )
        }
    }
    
    // MARK: - Page Card
    private func pageCardView(title: String, pageNumber: Int, badgeColor: Color, isFullWidth: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Trang \(pageNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.12))
                    .cornerRadius(4)
            }
            
            // Rendered Page Thumbnail
            if let thumb = vm.getPageThumbnail(pageNumber: pageNumber, size: CGSize(width: isFullWidth ? 300 : 240, height: isFullWidth ? 380 : 310)) {
                HStack {
                    Spacer()
                    Image(platformImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: isFullWidth ? 340 : 280)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                    Spacer()
                }
                .padding(.vertical, 6)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Không có hình ảnh trang")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    Spacer()
                }
            }
            
            // Text Excerpt / Snippet
            VStack(alignment: .leading, spacing: 4) {
                Text("Trích đoạn nội dung văn bản:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(vm.getPageSnippet(pageNumber: pageNumber))
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.platformTextBackground)
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
