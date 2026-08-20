import SwiftUI
import PDFKit
import AppKit

@MainActor
class BookLibraryViewModel: ObservableObject {
    // MARK: - Library State
    @Published var libraryRootURL: URL? = nil
    @Published var books: [BookItem] = []
    @Published var selectedBookIDs: Set<String> = []
    @Published var isLoading: Bool = false
    
    // MARK: - Filter & Presentation
    @Published var searchText: String = ""
    @Published var viewMode: LibraryViewMode = .grid
    @Published var sortOption: LibrarySortOption = .name
    @Published var groupMode: LibraryGroupMode = .byFolder
    
    // MARK: - Thumbnail Cache
    private var thumbnailCache: [String: NSImage] = [:]
    
    // MARK: - Alerts & Dialogs
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    
    private let service = BookLibraryService()
    
    init() {
        // Default to ~/Documents or current working folder
        let defaultURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        libraryRootURL = defaultURL
        refreshLibrary()
    }
    
    // MARK: - Filtered & Sorted Books
    var filteredBooks: [BookItem] {
        var list = books
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.name.lowercased().contains(q) || $0.folderName.lowercased().contains(q) }
        }
        
        switch sortOption {
        case .name:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date:
            list.sort { $0.modifiedDate > $1.modifiedDate }
        case .size:
            list.sort { $0.fileSizeMB > $1.fileSizeMB }
        case .pages:
            list.sort { $0.pageCount > $1.pageCount }
        }
        
        return list
    }
    
    // MARK: - Grouped Books
    var groupedBooks: [BookGroup] {
        let items = filteredBooks
        
        switch groupMode {
        case .none:
            return [BookGroup(id: "all", title: "Tất Cả Sách (\(items.count))", folderURL: libraryRootURL, books: items)]
            
        case .byFolder:
            let dict = Dictionary(grouping: items) { $0.folderURL }
            return dict.map { (folderURL, groupBooks) in
                let title = folderURL.lastPathComponent
                return BookGroup(id: folderURL.path, title: "📁 \(title) (\(groupBooks.count) sách)", folderURL: folderURL, books: groupBooks)
            }.sorted { $0.title < $1.title }
            
        case .bySeries:
            let dict = Dictionary(grouping: items) { book -> String in
                // Extract common series prefix
                let base = book.baseName
                if let range = base.range(of: "_part\\d+", options: .regularExpression) {
                    return String(base[..<range.lowerBound])
                }
                if let range = base.range(of: "\\s+(Tập|Vol|Part|Quyển|Phần)\\s*\\d+", options: .regularExpression) {
                    return String(base[..<range.lowerBound])
                }
                return "Sách Khác"
            }
            return dict.map { (seriesName, groupBooks) in
                return BookGroup(id: seriesName, title: "📚 \(seriesName) (\(groupBooks.count) tập)", folderURL: nil, books: groupBooks)
            }.sorted { $0.title < $1.title }
        }
    }
    
    // MARK: - Thumbnail Loader
    func thumbnail(for book: BookItem) -> NSImage? {
        if let cached = thumbnailCache[book.id] {
            return cached
        }
        
        // Generate on demand
        if let doc = PDFDocument(url: book.url), let firstPage = doc.page(at: 0) {
            let thumb = firstPage.thumbnail(of: CGSize(width: 160, height: 210), for: .cropBox)
            thumbnailCache[book.id] = thumb
            return thumb
        }
        return nil
    }
    
    // MARK: - Actions
    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục chứa sách để quản lý"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            libraryRootURL = url
            refreshLibrary()
        }
    }
    
    func refreshLibrary() {
        guard let rootURL = libraryRootURL else { return }
        isLoading = true
        thumbnailCache.removeAll()
        selectedBookIDs.removeAll()
        
        Task {
            let scanned = await service.scanDirectory(at: rootURL, recursive: true)
            self.books = scanned
            self.isLoading = false
        }
    }
    
    func toggleSelection(for bookID: String) {
        if selectedBookIDs.contains(bookID) {
            selectedBookIDs.remove(bookID)
        } else {
            selectedBookIDs.insert(bookID)
        }
    }
    
    func selectAll() {
        selectedBookIDs = Set(filteredBooks.map { $0.id })
    }
    
    func deselectAll() {
        selectedBookIDs.removeAll()
    }
    
    // MARK: - Group Selected Books Prompt
    func groupSelectedBooksPrompt() {
        guard !selectedBookIDs.isEmpty else {
            showAlert(title: "Chưa chọn sách", message: "Vui lòng chọn ít nhất 1 cuốn sách để gom vào thư mục.")
            return
        }
        
        guard let root = libraryRootURL else { return }
        let selectedItems = books.filter { selectedBookIDs.contains($0.id) }
        
        let alert = NSAlert()
        alert.messageText = "Gom Sách Vào Thư Mục Mới"
        alert.informativeText = "Gom \(selectedItems.count) cuốn sách đã chọn vào một thư mục mới trong:\n\(root.path)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Gom Nhóm")
        alert.addButton(withTitle: "Huỷ")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        inputTextField.stringValue = "Bo_Sach_Moi"
        alert.accessoryView = inputTextField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let folderName = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !folderName.isEmpty {
                do {
                    _ = try service.groupBooksIntoNewFolder(books: selectedItems, targetFolderName: folderName, parentDir: root)
                    refreshLibrary()
                } catch {
                    showAlert(title: "Lỗi gom nhóm", message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Auto Group Split Parts
    func autoGroupSplitPartsAction() {
        guard let root = libraryRootURL else { return }
        do {
            let count = try service.autoGroupSplitParts(in: root)
            refreshLibrary()
            if count > 0 {
                showAlert(title: "Tự Động Gom Hoàn Tất", message: "Đã tự động gom \(count) file sách đã tách vào các thư mục tương ứng!")
            } else {
                showAlert(title: "Thông Báo", message: "Không tìm thấy các file phần sách tách rời cần gom trong thư mục gốc.")
            }
        } catch {
            showAlert(title: "Lỗi Gom Tự Động", message: error.localizedDescription)
        }
    }
    
    // MARK: - Reveal in Finder
    func revealInFinder(book: BookItem) {
        NSWorkspace.shared.selectFile(book.url.path, inFileViewerRootedAtPath: book.folderURL.path)
    }
    
    // MARK: - Move to Trash
    func deleteSelectedBooksPrompt() {
        guard !selectedBookIDs.isEmpty else { return }
        let selectedItems = books.filter { selectedBookIDs.contains($0.id) }
        
        let alert = NSAlert()
        alert.messageText = "Xoá Sách Đã Chọn"
        alert.informativeText = "Bạn có chắc chắn muốn chuyển \(selectedItems.count) cuốn sách đã chọn vào Thùng Rác (Trash) không?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Chuyển vào Thùng Rác")
        alert.addButton(withTitle: "Huỷ")
        
        if alert.runModal() == .alertFirstButtonReturn {
            for item in selectedItems {
                try? service.deleteBook(at: item.url)
            }
            refreshLibrary()
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
