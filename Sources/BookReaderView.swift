import SwiftUI
import PDFKit

struct BookReaderView: View {
    let bookURL: URL
    var onClose: () -> Void
    var onSplitBook: (URL) -> Void
    
    @State private var currentPageIndex: Int = 0
    @State private var totalPages: Int = 1
    @State private var displayMode: PDFDisplayMode = .singlePageContinuous
    @State private var scaleFactor: CGFloat = 1.0
    @State private var autoScales: Bool = true
    @State private var showThumbnailSidebar: Bool = false
    @State private var showOutlinePopover: Bool = false
    @State private var outlineItems: [PDFOutlineItem] = []
    
    struct PDFOutlineItem: Identifiable {
        let id = UUID()
        let title: String
        let pageIndex: Int
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Reader Toolbar
            readerToolbar
            
            Divider()
            
            // 2. Main Reader Canvas
            HSplitView {
                // Optional Thumbnails Drawer
                if showThumbnailSidebar {
                    thumbnailsDrawer
                        .frame(minWidth: 140, idealWidth: 160, maxWidth: 200)
                }
                
                // PDF Viewer
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    
                    PDFKitReaderView(
                        url: bookURL,
                        currentPageIndex: $currentPageIndex,
                        totalPages: $totalPages,
                        displayMode: $displayMode,
                        scaleFactor: $scaleFactor,
                        autoScales: $autoScales
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            loadOutline()
        }
    }
    
    // MARK: - Reader Toolbar
    private var readerToolbar: some View {
        HStack(spacing: 12) {
            // Back Button
            Button {
                onClose()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Thư Viện")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .keyboardShortcut(.cancelAction) // Esc
            
            Divider().frame(height: 18)
            
            // Book Title
            VStack(alignment: .leading, spacing: 2) {
                Text(bookURL.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text("Trang \(currentPageIndex + 1) / \(totalPages)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 240, alignment: .leading)
            
            Spacer()
            
            // Page Navigator Controls
            HStack(spacing: 6) {
                Button {
                    if currentPageIndex > 0 {
                        currentPageIndex -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPageIndex <= 0)
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                // Jump to page text
                Text("\(currentPageIndex + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .frame(minWidth: 28)
                
                Text("/")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                Text("\(totalPages)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 28)
                
                Button {
                    if currentPageIndex < totalPages - 1 {
                        currentPageIndex += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPageIndex >= totalPages - 1)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            
            Divider().frame(height: 18)
            
            // Display Mode Picker
            Picker("Chế độ xem", selection: $displayMode) {
                Label("Cuộn Liên Tục", systemImage: "rectangle.portrait.and.arrow.forward").tag(PDFDisplayMode.singlePageContinuous)
                Label("Từng Trang", systemImage: "doc.text").tag(PDFDisplayMode.singlePage)
                Label("Hai Trang Mở (Sách)", systemImage: "book.pages").tag(PDFDisplayMode.twoUpContinuous)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            .controlSize(.small)
            
            // Zoom Controls
            HStack(spacing: 4) {
                Button {
                    autoScales = false
                    scaleFactor = max(0.4, scaleFactor - 0.2)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .controlSize(.small)
                
                Button("Vừa Màn Hình") {
                    autoScales = true
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                
                Button {
                    autoScales = false
                    scaleFactor = min(3.0, scaleFactor + 0.2)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .controlSize(.small)
            }
            
            Divider().frame(height: 18)
            
            // Toggle Thumbnails Drawer
            Button {
                showThumbnailSidebar.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.borderedProminent)
            .tint(showThumbnailSidebar ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundColor(showThumbnailSidebar ? .white : .primary)
            .controlSize(.small)
            .help("Ẩn/Hiện dải ảnh thu nhỏ các trang")
            
            // Split This Book Shortcut
            Button {
                onSplitBook(bookURL)
            } label: {
                Label("Tách Sách", systemImage: "scissors")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.purple)
            .controlSize(.small)
            .help("Mở sách này trong công cụ Tách Sách")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Thumbnails Drawer
    private var thumbnailsDrawer: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Trang (\(totalPages))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 10) {
                        ForEach(0..<totalPages, id: \.self) { pageIdx in
                            Button {
                                currentPageIndex = pageIdx
                            } label: {
                                VStack(spacing: 3) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
                                        
                                        if let doc = PDFDocument(url: bookURL), let page = doc.page(at: pageIdx) {
                                            Image(nsImage: page.thumbnail(of: CGSize(width: 100, height: 130), for: .cropBox))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        }
                                    }
                                    .frame(width: 90, height: 120)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(currentPageIndex == pageIdx ? Color.accentColor : Color.clear, lineWidth: 2.5)
                                    )
                                    
                                    Text("\(pageIdx + 1)")
                                        .font(.system(size: 10, weight: currentPageIndex == pageIdx ? .bold : .regular))
                                        .foregroundColor(currentPageIndex == pageIdx ? .accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .id(pageIdx)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: currentPageIndex) { newIdx in
                    withAnimation {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
    
    // MARK: - Load Outline
    private func loadOutline() {
        guard let doc = PDFDocument(url: bookURL), let rootOutline = doc.outlineRoot else { return }
        var items: [PDFOutlineItem] = []
        for i in 0..<rootOutline.numberOfChildren {
            if let child = rootOutline.child(at: i), let title = child.label, let dest = child.destination, let page = dest.page {
                let pageIndex = doc.index(for: page)
                items.append(PDFOutlineItem(title: title, pageIndex: pageIndex))
            }
        }
        self.outlineItems = items
    }
}
