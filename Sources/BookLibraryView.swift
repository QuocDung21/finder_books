import SwiftUI
import PDFKit

struct BookLibraryView: View {
    @ObservedObject var vm: BookLibraryViewModel
    var onSelectBookToRead: (URL) -> Void
    var onSelectBookToSplit: (URL) -> Void
    
    @ObservedObject private var syncManager = LiveCompanionSyncManager.shared
    @State private var showWiFiSyncSheet: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main Content
            Group {
                if vm.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Đang quét thư viện...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.platformWindowBackground)
                } else if vm.filteredBooks.isEmpty {
                    emptyLibraryView
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 24) {
                            // Clean Header Banner (Large Title + Info)
                            headerBanner
                            
                            // Book Groups
                            ForEach(vm.groupedBooks, id: \.id) { group in
                                VStack(alignment: .leading, spacing: 14) {
                                    // Subtle Section Header if more than 1 group
                                    if vm.groupMode != .none && vm.groupedBooks.count > 1 {
                                        HStack(spacing: 8) {
                                            Text(group.title)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            #if os(macOS)
                                            if let fURL = group.folderURL {
                                                Button {
                                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: fURL.path)
                                                } label: {
                                                    Image(systemName: "folder")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                                .buttonStyle(.plain)
                                                .help("Mở thư mục này trong Finder")
                                            }
                                            #endif
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                    
                                    // Responsive Book Grid or List
                                    if vm.viewMode == .grid {
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 195), spacing: 20)], spacing: 22) {
                                            ForEach(group.books) { book in
                                                bookGridCard(book: book)
                                            }
                                        }
                                    } else {
                                        LazyVStack(spacing: 8) {
                                            ForEach(group.books) { book in
                                                bookListRow(book: book)
                                            }
                                        }
                                    }
                                }
                                .padding(6)
                                .background(Color.platformControlBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .padding(24)
                    }
                    .background(Color.platformWindowBackground)
                }
            }
            
            // Top Floating Transfer Progress Notification Pill
            if let transfer = syncManager.activeTransfer {
                HStack(spacing: 10) {
                    Image(systemName: transfer.isReceiving ? "arrow.down.circle.fill" : "paperplane.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transfer.statusText)
                            .font(.system(size: 12, weight: .bold))
                        Text(transfer.filename)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if transfer.progress > 0 && transfer.progress < 1.0 {
                        Text("\(Int(transfer.progress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.platformControlBackground)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
                .padding(.horizontal, 30)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            syncManager.onBookReceived = { _ in
                vm.refreshLibrary()
            }
        }
        .alert(isPresented: $vm.showAlert) {
            Alert(
                title: Text(vm.alertTitle),
                message: Text(vm.alertMessage),
                dismissButton: .default(Text("Đóng"))
            )
        }
        .sheet(item: $vm.bookToRename) { book in
            BookRenameSheet(book: book) { newTitle in
                vm.renameBookAction(book: book, newTitle: newTitle)
            }
        }
        .sheet(isPresented: $showWiFiSyncSheet) {
            WiFiSyncControlSheet()
        }
    }
    
    // MARK: - Clean Header Banner
    private var headerBanner: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text((vm.selectedSidebarItem ?? .allBooks).title)
                        .font(.system(size: 24, weight: .bold))
                    
                    if vm.isAIOrganizing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(vm.aiProgressText)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text("\(vm.filteredBooks.count) cuốn sách")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    if let root = vm.libraryRootURL {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(root.path)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            
            Spacer()
            
            // Wi-Fi Sync Status Button
            Button {
                showWiFiSyncSheet = true
            } label: {
                HStack(spacing: 5) {
                    let isConn = syncManager.isDirectTCPConnected || !syncManager.connectedPeers.isEmpty
                    Circle()
                        .fill(isConn ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Image(systemName: "wifi")
                        .font(.system(size: 11))
                    if isConn {
                        Text(syncManager.connectedPeers.first?.displayName ?? "Đã kết nối")
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Text("Đồng Bộ Wi-Fi")
                            .font(.system(size: 11))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.platformControlBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // Batch Actions when multiple items are selected
            if !vm.selectedBookIDs.isEmpty {
                HStack(spacing: 8) {
                    Text("Đã chọn: \(vm.selectedBookIDs.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                    
                    if syncManager.isConnected {
                        Button {
                            for id in vm.selectedBookIDs {
                                if let book = vm.books.first(where: { $0.id == id }) {
                                    syncManager.sendBookFile(url: book.url)
                                }
                            }
                        } label: {
                            Label("Gửi Sang \(syncManager.connectedDeviceName)", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    Button("Gom Thư Mục Mới") {
                        vm.groupSelectedBooksPrompt()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Xoá") {
                        vm.deleteSelectedBooksPrompt()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.bottom, 6)
    }
    
    // MARK: - Book Grid Card
    private func bookGridCard(book: BookItem) -> some View {
        let isSelected = vm.selectedBookIDs.contains(book.id)
        
        return VStack(alignment: .leading, spacing: 8) {
            bookCardCover(book: book, isSelected: isSelected)
            bookCardMeta(book: book)
            bookCardButtons(book: book)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture(count: 2) {
            onSelectBookToRead(book.url)
        }
        .contextMenu {
            Button("Đọc Sách") {
                onSelectBookToRead(book.url)
            }
            
            if syncManager.isConnected {
                Button {
                    syncManager.sendBookFile(url: book.url)
                } label: {
                    Label("Gửi Sang \(syncManager.connectedDeviceName) (Wi-Fi/Dây)", systemImage: "paperplane.fill")
                }
            }
            
            Button("Tách Sách Này...") {
                onSelectBookToSplit(book.url)
            }
            Divider()
            Button("Đổi Tên Sách...") {
                vm.bookToRename = book
            }
            #if os(macOS)
            Button("Hiện Trong Finder") {
                vm.revealInFinder(book: book)
            }
            #endif
            Divider()
            Button("Chuyển Vào Thùng Rác", role: .destructive) {
                vm.deleteBookAction(book: book)
            }
        }
    }
    
    private func bookCardCover(book: BookItem, isSelected: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                
                if let thumb = vm.thumbnail(for: book) {
                    Image(platformImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("PDF")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .frame(height: 190)
            
            Button {
                vm.toggleSelection(for: book.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .white.opacity(0.8))
                    .background(isSelected ? Color.white : Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
    
    private func bookCardMeta(book: BookItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(height: 32, alignment: .topLeading)
            
            HStack {
                Text("\(book.pageCount) tr")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text(book.formattedSize)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    private func bookCardButtons(book: BookItem) -> some View {
        HStack(spacing: 6) {
            Button {
                onSelectBookToRead(book.url)
            } label: {
                Text("Đọc Sách")
                    .font(.system(size: 10, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            
            Button {
                onSelectBookToSplit(book.url)
            } label: {
                Text("Tách")
                    .font(.system(size: 10))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.top, 2)
    }
    
    // MARK: - Book List Row
    private func bookListRow(book: BookItem) -> some View {
        let isSelected = vm.selectedBookIDs.contains(book.id)
        
        return HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in vm.toggleSelection(for: book.id) }
            ))
            .labelsHidden()
            .controlSize(.small)
            
            // Mini Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 1)
                
                if let thumb = vm.thumbnail(for: book) {
                    Image(platformImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .frame(width: 32, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.name)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                
                Text("\(book.folderName)  •  \(book.pageCount) trang  •  \(book.formattedSize)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let peer = syncManager.connectedPeers.first {
                Button {
                    syncManager.sendBookFile(url: book.url)
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Gửi sang \(peer.displayName)")
            }
            
            Button("Đọc Sách") {
                onSelectBookToRead(book.url)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button("Tách") {
                onSelectBookToSplit(book.url)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture(count: 2) {
            onSelectBookToRead(book.url)
        }
    }
    
    // MARK: - Empty State View
    private var emptyLibraryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("Thư Viện Đang Trống")
                    .font(.system(size: 16, weight: .bold))
                Text("Chưa tìm thấy sách nào trong thư mục đang chọn.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 10) {
                Button("Chọn Thư Mục Khác...") {
                    vm.chooseLibraryFolder()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Button("Quét & Đồng Bộ (Downloads...)") {
                    vm.promptScanAndSyncSourceFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformWindowBackground)
    }
}
