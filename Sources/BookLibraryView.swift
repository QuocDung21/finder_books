import SwiftUI
import PDFKit

struct BookLibraryView: View {
    @ObservedObject var vm: BookLibraryViewModel
    var onSelectBookToSplit: (URL) -> Void
    var onOpenSplitterDirectly: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Library Main Header
            libraryMainHeader
            
            Divider()
            
            // 2. Organization & AI Action Bar
            organizationActionBar
            
            // 3. AI Progress Banner (if active)
            if vm.isAIOrganizing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("🤖 \(vm.aiProgressText)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.12))
                Divider()
            }
            
            // 4. Content Area (Grid / List)
            if vm.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Đang quét thư mục sách...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            } else if vm.filteredBooks.isEmpty {
                emptyLibraryView
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(vm.groupedBooks) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                // Group Header
                                HStack(spacing: 8) {
                                    Text(group.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("•  \(group.totalPages) trang  •  \(String(format: "%.1f MB", group.totalSizeMB))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let fURL = group.folderURL {
                                        Button {
                                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: fURL.path)
                                        } label: {
                                            Label("Mở Thư Mục", systemImage: "folder")
                                        }
                                        .buttonStyle(.borderless)
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 4)
                                
                                // Group Content (Grid or List)
                                if vm.viewMode == .grid {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 185), spacing: 16)], spacing: 18) {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
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
    }
    
    // MARK: - Main Header
    private var libraryMainHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(vm.selectedSidebarItem.title)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("\(vm.filteredBooks.count) cuốn")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                }
                
                // Folder Breadcrumb Path
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text(vm.libraryRootURL?.path ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button("Đổi...") {
                        vm.chooseLibraryFolder()
                    }
                    .controlSize(.mini)
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
                }
            }
            
            Spacer()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Tìm sách, tác giả, thư mục...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .frame(width: 200)
            
            // Grouping Mode
            Picker("Gom nhóm", selection: $vm.groupMode) {
                ForEach(LibraryGroupMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            .controlSize(.small)
            
            // View Mode Toggle (Grid vs List)
            Picker("Xem", selection: $vm.viewMode) {
                ForEach(LibraryViewMode.allCases) { mode in
                    Image(systemName: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 68)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Organization Action Bar
    private var organizationActionBar: some View {
        HStack(spacing: 8) {
            // Quick Sync / Scan from Downloads
            Button {
                vm.promptScanAndSyncSourceFolder()
            } label: {
                HStack(spacing: 5) {
                    if vm.isSyncScanning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("Quét & Đồng Bộ (Downloads...)")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.blue)
            .controlSize(.small)
            .disabled(vm.isSyncScanning)
            .help("Quét sách từ thư mục Downloads hoặc thư mục khác, tự động so sánh với kho để chuyển sách mới và xoá file trùng")
            
            // AI Organize Button
            Button {
                if !vm.selectedBookIDs.isEmpty {
                    vm.classifyAndOrganizeSelectedBooks()
                } else {
                    vm.classifyAndOrganizeAllBooks()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                    Text(vm.selectedBookIDs.isEmpty ? "AI Phân Loại Tất Cả" : "AI Phân Loại (\(vm.selectedBookIDs.count))")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.purple)
            .controlSize(.small)
            .disabled(vm.isAIOrganizing || vm.books.isEmpty)
            .help("Dùng AI macOS đọc nội dung sách và tự động gom vào thư mục thể loại tương ứng")
            
            // Smart Inbox Auto-Watch Toggle
            Button {
                vm.toggleSmartInboxWatcher()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(vm.folderWatcher.isWatching ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text(vm.folderWatcher.isWatching ? "Hộp Thư Đang Bật" : "Bật Hộp Thư Tự Động")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.folderWatcher.isWatching ? Color.green : Color.secondary.opacity(0.2))
            .foregroundColor(vm.folderWatcher.isWatching ? .white : .primary)
            .controlSize(.small)
            .help("Khi bật: Chỉ cần thả bất kỳ file PDF nào vào thư mục 📥_Inbox_Gom_Sach, AI sẽ tự động phân loại và chuyển vào thư mục chuẩn")
            
            Button {
                vm.groupSelectedBooksPrompt()
            } label: {
                Label("Gom Thư Mục Mới", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(vm.selectedBookIDs.isEmpty)
            
            Divider().frame(height: 16)
            
            if vm.selectedBookIDs.count == vm.filteredBooks.count && !vm.filteredBooks.isEmpty {
                Button("Bỏ chọn") {
                    vm.deselectAll()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            } else {
                Button("Chọn tất cả") {
                    vm.selectAll()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
            
            if !vm.selectedBookIDs.isEmpty {
                Button {
                    vm.deleteSelectedBooksPrompt()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Chuyển sách đã chọn vào Thùng rác")
            }
            
            Spacer()
            
            Button {
                vm.refreshLibrary()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Quét lại thư mục")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
    }
    
    // MARK: - Book Grid Card
    private func bookGridCard(book: BookItem) -> some View {
        let isSelected = vm.selectedBookIDs.contains(book.id)
        let detectedCat = vm.bookCategories[book.id]
        
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Book Cover with Realistic Apple-style Shadow
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                    
                    if let thumb = vm.thumbnail(for: book) {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("PDF")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 180)
                
                // Selection Checkbox Badge
                Button {
                    vm.toggleSelection(for: book.id)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .accentColor : .white)
                        .background(isSelected ? Color.white : Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
            }
            
            // Book Details
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                // AI Category Pill Badge
                if let cat = detectedCat, cat != .general {
                    HStack(spacing: 3) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 9))
                        Text(cat.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
                }
                
                HStack {
                    Text("\(book.pageCount) trang")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Text(book.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            // Action Buttons
            HStack(spacing: 6) {
                Button {
                    onSelectBookToSplit(book.url)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "scissors")
                        Text("Tách Sách")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Button {
                    vm.revealInFinder(book: book)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Mở trong Finder")
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture(count: 2) {
            onSelectBookToSplit(book.url)
        }
        .contextMenu {
            Button("✂️ Tách Sách Này") {
                onSelectBookToSplit(book.url)
            }
            Button("📂 Hiện Trong Finder") {
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
        let detectedCat = vm.bookCategories[book.id]
        
        return HStack(spacing: 10) {
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
                
                HStack(spacing: 6) {
                    Text(book.folderName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let cat = detectedCat, cat != .general {
                        Text("• \(cat.rawValue)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
            }
            
            Spacer()
            
            Text("\(book.pageCount) trang")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 70, alignment: .trailing)
            
            Text(book.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            Button("Tách") {
                onSelectBookToSplit(book.url)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            
            Button {
                vm.revealInFinder(book: book)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Mở trong Finder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }
    
    // MARK: - Empty Library View
    private var emptyLibraryView: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            
            Text("Không tìm thấy sách PDF phù hợp")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Chọn thư mục khác hoặc dùng tính năng Quét & Đồng Bộ để nhập sách.")
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
