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
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Clean Responsive Reader Toolbar
            readerToolbar
            
            Divider()
            
            // 2. Main Reader Canvas
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Optional Thumbnails Drawer
                    if showThumbnailSidebar {
                        thumbnailsDrawer
                            .frame(width: 140)
                            .transition(.move(edge: .leading))
                        
                        Divider()
                    }
                    
                    // PDF Canvas (Takes full remaining space)
                    PDFKitReaderView(
                        url: bookURL,
                        currentPageIndex: $currentPageIndex,
                        totalPages: $totalPages,
                        displayMode: $displayMode,
                        scaleFactor: $scaleFactor,
                        autoScales: $autoScales
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Responsive Reader Toolbar
    private var readerToolbar: some View {
        HStack(spacing: 10) {
            // Left Group: Back Button & Title
            HStack(spacing: 8) {
                Button {
                    onClose()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Thư Viện")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction) // Esc
                
                Text(bookURL.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 220, alignment: .leading)
            }
            
            Spacer()
            
            // Center Group: Compact Page Navigator
            HStack(spacing: 4) {
                Button {
                    if currentPageIndex > 0 {
                        currentPageIndex -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                }
                .disabled(currentPageIndex <= 0)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .buttonStyle(.plain)
                
                Text("\(currentPageIndex + 1) / \(totalPages)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .frame(minWidth: 60)
                
                Button {
                    if currentPageIndex < totalPages - 1 {
                        currentPageIndex += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .disabled(currentPageIndex >= totalPages - 1)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            
            Spacer()
            
            // Right Group: Controls
            HStack(spacing: 6) {
                // Layout Mode
                Picker("Chế độ xem", selection: $displayMode) {
                    Image(systemName: "rectangle.portrait.and.arrow.forward").tag(PDFDisplayMode.singlePageContinuous)
                    Image(systemName: "doc.text").tag(PDFDisplayMode.singlePage)
                    Image(systemName: "book.pages").tag(PDFDisplayMode.twoUpContinuous)
                }
                .pickerStyle(.segmented)
                .frame(width: 85)
                .controlSize(.small)
                
                // Zoom
                HStack(spacing: 2) {
                    Button {
                        autoScales = false
                        scaleFactor = max(0.4, scaleFactor - 0.2)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10))
                    }
                    .controlSize(.small)
                    
                    Button("Vừa") {
                        autoScales = true
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    
                    Button {
                        autoScales = false
                        scaleFactor = min(3.0, scaleFactor + 0.2)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                    }
                    .controlSize(.small)
                }
                
                // Toggle Thumbnails Drawer
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showThumbnailSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderedProminent)
                .tint(showThumbnailSidebar ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(showThumbnailSidebar ? .white : .primary)
                .controlSize(.small)
                .help("Ẩn/Hiện dải ảnh thu nhỏ")
                
                // Split Action
                Button {
                    onSplitBook(bookURL)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "scissors")
                        Text("Tách")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Mở sách này trong công cụ tách sách")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Thumbnails Drawer
    private var thumbnailsDrawer: some View {
        VStack(spacing: 0) {
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
                                            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                                        
                                        if let doc = PDFDocument(url: bookURL), let page = doc.page(at: pageIdx) {
                                            Image(platformImage: page.platformThumbnail(size: CGSize(width: 90, height: 120)))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        }
                                    }
                                    .frame(width: 80, height: 110)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(currentPageIndex == pageIdx ? Color.accentColor : Color.clear, lineWidth: 2)
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}
