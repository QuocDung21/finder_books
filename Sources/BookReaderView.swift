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
    
    // AI Dictionary & Translation State
    @State private var selectedText: String = ""
    @State private var showLookupSheet: Bool = false
    @State private var lookupQueryText: String = ""
    @State private var showNotebookSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 1. Clean Responsive Reader Toolbar
            readerToolbar

            Divider()

            // 2. Main Reader Canvas
            GeometryReader { geo in
                ZStack(alignment: .bottomTrailing) {
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
                            autoScales: $autoScales,
                            selectedText: $selectedText
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Floating Quick Lookup Button when text is selected
                    if !selectedText.isEmpty {
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
        .sheet(isPresented: $showLookupSheet) {
            AITranslateLookupSheet(
                queryText: lookupQueryText,
                bookTitle: bookURL.deletingPathExtension().lastPathComponent
            )
        }
        .sheet(isPresented: $showNotebookSheet) {
            VocabularyNotebookView()
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
                    .frame(maxWidth: 200, alignment: .leading)
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
            .background(Color.platformControlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Spacer()

            // Right Group: Controls
            HStack(spacing: 6) {
                // AI Lookup & Translate Shortcut
                Button {
                    lookupQueryText = selectedText.isEmpty ? "Reading" : selectedText
                    showLookupSheet = true
                } label: {
                    Image(systemName: "character.book.closed")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut("d", modifiers: .command)
                .help("Dịch và Tra từ điển AI (⌘D)")
                
                // Vocabulary Notebook
                Button {
                    showNotebookSheet = true
                } label: {
                    Image(systemName: "bookmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Mở Sổ Tay Từ Vựng")
                
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
