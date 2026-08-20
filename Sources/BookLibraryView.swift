import SwiftUI
import PDFKit

struct BookLibraryView: View {
    @StateObject private var vm = BookLibraryViewModel()
    var onSelectBookToSplit: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Library Toolbar
            libraryToolbar
            
            Divider()
            
            // 2. Organization Action Bar
            organizationActionBar
            
            Divider()
            
            // 3. Books Content (Grid / List)
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
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(vm.groupedBooks) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                // Group Header
                                HStack {
                                    Text(group.title)
                                        .font(.system(size: 13, weight: .bold))
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
                                
                                // Group Content
                                if vm.viewMode == .grid {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 170), spacing: 14)], spacing: 16) {
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
                    .padding(16)
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
    }
    
    // MARK: - Library Toolbar
    private var libraryToolbar: some View {
        HStack(spacing: 12) {
            // Folder Breadcrumb
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                
                Text(vm.libraryRootURL?.path ?? "Chưa chọn thư mục")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Button("Đổi...") {
                    vm.chooseLibraryFolder()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Tìm tên sách, thư mục...", text: $vm.searchText)
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
            .padding(.vertical, 4)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .frame(width: 180)
            
            // Grouping Mode
            Picker("Gom nhóm", selection: $vm.groupMode) {
                ForEach(LibraryGroupMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .controlSize(.small)
            
            // View Mode Toggle
            Picker("Xem", selection: $vm.viewMode) {
                ForEach(LibraryViewMode.allCases) { mode in
                    Image(systemName: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 68)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Organization Action Bar
    private var organizationActionBar: some View {
        HStack(spacing: 10) {
            Button {
                vm.groupSelectedBooksPrompt()
            } label: {
                Label("Gom Vào Thư Mục Mới (\(vm.selectedBookIDs.count))", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(vm.selectedBookIDs.isEmpty)
            .help("Tạo thư mục mới và di chuyển các cuốn sách đã chọn vào đó")
            
            Button {
                vm.autoGroupSplitPartsAction()
            } label: {
                Label("Tự Động Gom Phần Tách", systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Tự động nhận diện và gom các file part1, part2,... vào thư mục của sách")
            
            Divider().frame(height: 16)
            
            if vm.selectedBookIDs.count == vm.filteredBooks.count && !vm.filteredBooks.isEmpty {
                Button("Bỏ chọn tất cả") {
                    vm.deselectAll()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            } else {
                Button("Chọn tất cả (\(vm.filteredBooks.count))") {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
    }
    
    // MARK: - Book Grid Card
    private func bookGridCard(book: BookItem) -> some View {
        let isSelected = vm.selectedBookIDs.contains(book.id)
        
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Book Cover
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                    
                    if let thumb = vm.thumbnail(for: book) {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("PDF")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 170)
                
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
            VStack(alignment: .leading, spacing: 3) {
                Text(book.name)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("\(book.pageCount) trang")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Text(book.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            // Action Button: Split This Book
            Button {
                onSelectBookToSplit(book.url)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                    Text("Tách Sách Này")
                }
                .font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
            .frame(width: 24, height: 32)
            
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
            .buttonStyle(.borderedProminent)
            
            Button {
                vm.revealInFinder(book: book)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Mở trong Finder")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }
    
    // MARK: - Empty Library View
    private var emptyLibraryView: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("Không tìm thấy sách PDF trong thư mục này")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Vui lòng chọn thư mục chứa các file sách PDF của bạn.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Button("Chọn Thư Mục Chứa Sách") {
                vm.chooseLibraryFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
