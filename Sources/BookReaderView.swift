import SwiftUI
import PDFKit

struct BookReaderView: View {
    let bookURL: URL
    var onClose: () -> Void
    var onSplitBook: (URL) -> Void

    @State private var currentPageIndex: Int = 0
    @State private var totalPages: Int = 1
    @State private var displayMode: PDFDisplayMode = .singlePage
    @State private var scaleFactor: CGFloat = 1.0
    @State private var autoScales: Bool = true
    @State private var showThumbnailSidebar: Bool = false
    
    // AI Dictionary & Translation State
    @State private var selectedText: String = ""
    @State private var showLookupSheet: Bool = false
    @State private var lookupQueryText: String = ""
    @State private var showNotebookSheet: Bool = false
    @State private var isDictionaryPinned: Bool = false
    
    // Live Wi-Fi Sync & Pen Drawing State
    @ObservedObject private var syncManager = LiveCompanionSyncManager.shared
    @State private var isPenModeActive: Bool = false
    @State private var activePenColor: Color = .red
    @State private var activePenWidth: CGFloat = 3.0
    @State private var isHighlighter: Bool = false
    @State private var showWiFiSyncSheet: Bool = false

    private let penColors: [(Color, String)] = [
        (.black, "Đen"),
        (.red, "Đỏ"),
        (.blue, "Xanh Dương"),
        (.green, "Xanh Lá"),
        (.yellow, "Dạ Quang")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 1. Clean Responsive Reader Toolbar
            readerToolbar

            Divider()

            // 2. Main Reader Canvas
            GeometryReader { geo in
                ZStack(alignment: .bottomTrailing) {
                    HStack(spacing: 0) {
                        // Left: Optional Thumbnails Drawer
                        if showThumbnailSidebar {
                            thumbnailsDrawer
                                .frame(width: 140)
                                .transition(.move(edge: .leading))

                            Divider()
                        }

                        // Center: PDF Canvas with Live Inking Overlay
                        ZStack {
                            PDFKitReaderView(
                                url: bookURL,
                                currentPageIndex: $currentPageIndex,
                                totalPages: $totalPages,
                                displayMode: $displayMode,
                                scaleFactor: $scaleFactor,
                                autoScales: $autoScales,
                                selectedText: $selectedText
                            )
                            
                            // Real-time Inking Layer (Mac ↔ iPad P2P)
                            LiveInkingCanvasView(
                                pageIndex: currentPageIndex,
                                isDrawingEnabled: isPenModeActive,
                                activeColor: isHighlighter ? .yellow : activePenColor,
                                activeLineWidth: isHighlighter ? 14.0 : activePenWidth,
                                isHighlighter: isHighlighter
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Right: Pinned AI Dictionary & Translation Side Panel
                        if isDictionaryPinned {
                            Divider()
                            
                            AIDictionarySidePanel(
                                queryText: $lookupQueryText,
                                bookTitle: bookURL.deletingPathExtension().lastPathComponent,
                                onUnpinToModal: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isDictionaryPinned = false
                                        showLookupSheet = true
                                    }
                                },
                                onClose: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isDictionaryPinned = false
                                    }
                                }
                            )
                            .transition(.move(edge: .trailing))
                        }
                    }
                    
                    // Floating Pen Tool Palette (When Pen Mode is Active)
                    if isPenModeActive {
                        penToolPalette
                            .padding(.bottom, 20)
                            .padding(.trailing, isDictionaryPinned ? 380 : 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Floating Quick Lookup Button when text is selected (only if side panel not pinned)
                    if !selectedText.isEmpty && !isDictionaryPinned && !isPenModeActive {
                        Button {
                            lookupQueryText = selectedText
                            showLookupSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "character.book.closed.fill")
                                Text("Tra Cứu & Dịch AI (⌘D)")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(20)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .background(Color.platformWindowBackground)
        .onAppear {
            syncManager.startSyncSession()
            syncManager.onRemotePageJump = { remotePage in
                if remotePage != self.currentPageIndex && remotePage >= 0 && remotePage < self.totalPages {
                    self.currentPageIndex = remotePage
                }
            }
        }
        .onChange(of: currentPageIndex) { newPage in
            syncManager.broadcastPageJump(pageIndex: newPage)
        }
        .onChange(of: selectedText) { newText in
            if isDictionaryPinned && !newText.isEmpty {
                lookupQueryText = newText
            }
        }
        .sheet(isPresented: $showLookupSheet) {
            AITranslateLookupSheet(
                queryText: lookupQueryText.isEmpty ? "Reading" : lookupQueryText,
                bookTitle: bookURL.deletingPathExtension().lastPathComponent,
                onPinToSidebar: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isDictionaryPinned = true
                    }
                }
            )
        }
        .sheet(isPresented: $showNotebookSheet) {
            VocabularyNotebookView()
        }
        .sheet(isPresented: $showWiFiSyncSheet) {
            WiFiSyncControlSheet()
        }
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
                    .frame(maxWidth: 160, alignment: .leading)
            }

            // Wi-Fi Live Sync Status Pill (P2P Mac ↔ iPad & IP Direct)
            Button {
                showWiFiSyncSheet = true
            } label: {
                HStack(spacing: 4) {
                    let isConnected = syncManager.isDirectTCPConnected || !syncManager.connectedPeers.isEmpty
                    Circle()
                        .fill(isConnected ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    
                    if let peer = syncManager.connectedPeers.first {
                        Text("\(peer.displayName)")
                            .font(.system(size: 10, weight: .semibold))
                    } else if syncManager.isDirectTCPConnected {
                        Text("Wi-Fi Direct")
                            .font(.system(size: 10, weight: .semibold))
                    } else {
                        Text("Wi-Fi Sync")
                            .font(.system(size: 10))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.platformControlBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Quản lý đồng bộ Wi-Fi & IP Direct giữa Mac và iPad")

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
            .background(Color.platformControlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Spacer()

            // Right Group: Controls
            HStack(spacing: 6) {
                // Live Pen Mode Toggle Button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPenModeActive.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isPenModeActive ? "pencil.tip.crop.circle.badge.plus" : "pencil.tip")
                        if isPenModeActive {
                            Text("Bút Vẽ")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isPenModeActive ? Color.orange : Color.secondary.opacity(0.18))
                .foregroundColor(isPenModeActive ? .white : .primary)
                .controlSize(.small)
                .help("Bật/Tắt chế độ vẽ Apple Pencil & ghi chú trực tiếp")
                .keyboardShortcut("p", modifiers: .command)

                // Pin / Dock AI Dictionary Side Panel
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isDictionaryPinned.toggle()
                        if isDictionaryPinned && lookupQueryText.isEmpty {
                            lookupQueryText = selectedText.isEmpty ? "Reading" : selectedText
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isDictionaryPinned ? "sidebar.right" : "character.book.closed")
                        if isDictionaryPinned {
                            Text("Ghim Dịch")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isDictionaryPinned ? Color.accentColor : Color.secondary.opacity(0.18))
                .foregroundColor(isDictionaryPinned ? .white : .primary)
                .controlSize(.small)
                .help("Ghim cột Tra cứu & Dịch AI kế bên sách (⌘D)")
                .keyboardShortcut("d", modifiers: .command)
                
                // Vocabulary Notebook
                Button {
                    showNotebookSheet = true
                } label: {
                    Image(systemName: "bookmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Mở Sổ Tay Từ Vựng")
                
                // Direct Send Book to Peer Button
                if syncManager.isConnected {
                    Button {
                        syncManager.sendBookFile(url: bookURL)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "paperplane.fill")
                            Text("Gửi Sang \(syncManager.connectedDeviceName)")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Gửi file PDF này sang \(syncManager.connectedDeviceName) (Wi-Fi/Dây)")
                }
                
                Divider()
                    .frame(height: 16)

                // Layout Mode
                Picker("", selection: $displayMode) {
                    Image(systemName: "rectangle.portrait.and.arrow.forward").tag(PDFDisplayMode.singlePageContinuous)
                    Image(systemName: "doc.text").tag(PDFDisplayMode.singlePage)
                    Image(systemName: "book.pages").tag(PDFDisplayMode.twoUpContinuous)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .help("Chế độ xem: Cuộn liên tục / Từng trang / Hai trang mở")

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
        .background(Color.platformControlBackground)
    }

    // MARK: - Floating Pen Tool Palette
    private var penToolPalette: some View {
        HStack(spacing: 12) {
            // Colors
            HStack(spacing: 6) {
                ForEach(penColors, id: \.1) { color, name in
                    Button {
                        isHighlighter = (name == "Dạ Quang")
                        if !isHighlighter {
                            activePenColor = color
                        }
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(
                                        (isHighlighter && name == "Dạ Quang") || (!isHighlighter && activePenColor == color)
                                            ? Color.primary
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Màu \(name)")
                }
            }
            
            Divider()
                .frame(height: 18)
            
            // Stroke Width
            HStack(spacing: 4) {
                Button { activePenWidth = 2.0; isHighlighter = false } label: {
                    Circle().fill(Color.primary).frame(width: 4, height: 4)
                }
                .buttonStyle(.plain)
                
                Button { activePenWidth = 4.0; isHighlighter = false } label: {
                    Circle().fill(Color.primary).frame(width: 8, height: 8)
                }
                .buttonStyle(.plain)
                
                Button { activePenWidth = 8.0; isHighlighter = false } label: {
                    Circle().fill(Color.primary).frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .frame(height: 18)
            
            // Clear Current Page Ink
            Button {
                syncManager.broadcastClearPage(pageIndex: currentPageIndex)
            } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Xoá toàn bộ nét vẽ trang hiện tại")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.platformControlBackground)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
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
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(currentPageIndex == pageIdx ? .accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .id(pageIdx)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: currentPageIndex) { newPage in
                    withAnimation {
                        proxy.scrollTo(newPage, anchor: .center)
                    }
                }
            }
        }
        .background(Color.platformControlBackground)
    }
}
