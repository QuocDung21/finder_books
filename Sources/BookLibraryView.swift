import SwiftUI
import PDFKit

struct BookLibraryView: View {
    @ObservedObject var vm: BookLibraryViewModel
    var onSelectBookToRead: (URL) -> Void
    var onSelectBookToSplit: (URL) -> Void
    var onOpenSplitterDirectly: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area (Clean Single Canvas)
            if vm.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Đang quét thư viện...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            } else if vm.filteredBooks.isEmpty {
                emptyLibraryView
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Clean Header Banner (Large Title + Info)
                        headerBanner
                        
                        // Book Groups
                        ForEach(vm.groupedBooks) { group in
                            VStack(alignment: .leading, spacing: 14) {
                                // Subtle Section Header if more than 1 group
                                if vm.groupMode != .none && vm.groupedBooks.count > 1 {
                                    HStack(spacing: 8) {
                                        Text(group.title)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
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
                                    VStack(spacing: 4) {
                                        ForEach(group.books) { book in
                                            bookListRow(book: book)
                                        }
                                    }
                                    .padding(6)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .alert(isPresented: $vm.showAlert) {
            Alert(
                title: Text(vm.alertTitle),
                message: Text(vm.alertMessage),
                dismissButton: .default(Text("Đóng"))
            )
        }
        .sheet(isPresented: $vm.showSyncSheet) {
            if let srcURL = vm.syncSourceFolderURL, let libURL = vm.libraryRootURL {
                BookSyncSheet(
                    sourceFolderURL: srcURL,
                    libraryTargetURL: libURL,
                    items: vm.syncSheetItems,
                    onSyncCompleted: {
                        vm.refreshLibrary()
                    }
                )
            }
        }
        .sheet(item: $vm.bookToRename) { book in
            BookRenameSheet(book: book) { newTitle in
                vm.renameBookAction(book: book, newTitle: newTitle)
            }
        }
    }
    
    // MARK: - Clean Header Banner
    private var headerBanner: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(vm.selectedSidebarItem.title)
                        .font(.system(size: 24, weight: .bold))
                    
                    if vm.isAIOrganizing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(vm.aiProgressText)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
                
                HStack(spacing: 6) {
                    Text("\(vm.filteredBooks.count) cuốn sách")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let root = vm.libraryRootURL {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(root.path)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Button("Đổi...") {
                            vm.chooseLibraryFolder()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                    }
                }
            }
            
            Spacer()
            
            // Quick action pills
            if !vm.selectedBookIDs.isEmpty {
                HStack(spacing: 8) {
                    Text("Đã chọn \(vm.selectedBookIDs.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button("Bỏ chọn") {
                        vm.deselectAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Phân Loại") {
                        vm.classifyAndOrganizeSelectedBooks()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button {
                        vm.deleteSelectedBooksPrompt()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.bottom, 6)
    }
    
    // MARK: - Book Grid Card (Apple Books Style)
    private func bookGridCard(book: BookItem) -> some View {
        let isSelected = vm.selectedBookIDs.contains(book.id)
        
        return VStack(alignment: .leading, spacing: 8) {
            // Book Cover with Realistic macOS Drop Shadow
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    
                    if let thumb = vm.thumbnail(for: book) {
                        Image(nsImage: thumb)
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
                
                // Subtle Selection Dot
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
                .padding(6)
            }
            
            // Title & Info
            VStack(alignment: .leading, spacing: 3) {
                Text(book.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
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
            
            // Primary Action Buttons
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
            Button("Tách Sách Này...") {
                onSelectBookToSplit(book.url)
            }
            Divider()
            Button("Đổi Tên Sách...") {
                vm.bookToRename = book
            }
            Button("Hiện Trong Finder") {
                vm.revealInFinder(book: book)
            }
            Divider()
            Button(role: .destructive) {
                try? BookLibraryService().deleteBook(at: book.url)
                vm.refreshLibrary()
            } label: {
                Label("Chuyển vào Thùng Rác", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Book List Row
    private func bookListRow(book: BookItem) -> some View {
        let isSelected = vm.selectedBookIDs.contains(book.id)
        
        return HStack(spacing: 12) {
            Button {
                vm.toggleSelection(for: book.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            // Mini Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white)
                if let thumb = vm.thumbnail(for: book) {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            }
            .frame(width: 26, height: 34)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                
                Text(book.folderName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(book.pageCount) trang")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            
            Text(book.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            Button("Đọc") {
                onSelectBookToRead(book.url)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            
            Button("Tách") {
                onSelectBookToSplit(book.url)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(6)
        .contextMenu {
            Button("Đọc Sách") {
                onSelectBookToRead(book.url)
            }
            Button("Tách Sách Này...") {
                onSelectBookToSplit(book.url)
            }
            Divider()
            Button("Đổi Tên Sách...") {
                vm.bookToRename = book
            }
            Button("Hiện Trong Finder") {
                vm.revealInFinder(book: book)
            }
            Divider()
            Button(role: .destructive) {
                try? BookLibraryService().deleteBook(at: book.url)
                vm.refreshLibrary()
            } label: {
                Label("Chuyển vào Thùng Rác", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Empty Library View
    private var emptyLibraryView: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("Không có sách nào trong thư mục")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Chọn thư mục khác hoặc quét sách từ Downloads để bắt đầu.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                Button("Chọn Thư Mục Sách...") {
                    vm.chooseLibraryFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button("Quét Sách Từ Downloads...") {
                    vm.promptScanAndSyncSourceFolder()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
