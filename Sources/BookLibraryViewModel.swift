import SwiftUI
import PDFKit
import AppKit

// MARK: - Sidebar Item Navigation
enum LibrarySidebarItem: Hashable, Identifiable {
    case allBooks
    case smartInbox
    case splitParts
    case category(BookCategory)
    case splitterTool
    
    var id: String {
        switch self {
        case .allBooks: return "all"
        case .smartInbox: return "smartInbox"
        case .splitParts: return "splitParts"
        case .category(let cat): return "cat_\(cat.rawValue)"
        case .splitterTool: return "tool_splitter"
        }
    }
    
    var title: String {
        switch self {
        case .allBooks: return "Tất Cả Sách"
        case .smartInbox: return "Hộp Thư Tự Động"
        case .splitParts: return "Sách Đã Tách Phần"
        case .category(let cat): return cat.rawValue
        case .splitterTool: return "Công Cụ Tách Sách"
        }
    }
    
    var icon: String {
        switch self {
        case .allBooks: return "books.vertical.fill"
        case .smartInbox: return "tray.and.arrow.down.fill"
        case .splitParts: return "scissors.badge.ellipsis"
        case .category(let cat): return cat.icon
        case .splitterTool: return "scissors"
        }
    }
}

@MainActor
class BookLibraryViewModel: ObservableObject {
    // MARK: - Navigation & Sidebar State
    @Published var selectedSidebarItem: LibrarySidebarItem = .allBooks
    
    // MARK: - Library State
    @Published var libraryRootURL: URL? = nil
    @Published var books: [BookItem] = []
    @Published var selectedBookIDs: Set<String> = []
    @Published var isLoading: Bool = false
    
    // MARK: - Filter & Presentation
    @Published var searchText: String = ""
    @Published var viewMode: LibraryViewMode = .grid
    @Published var sortOption: LibrarySortOption = .name
    @Published var groupMode: LibraryGroupMode = .byCategory
    
    // MARK: - AI & Smart Watcher State
    @Published var isAIOrganizing: Bool = false
    @Published var aiProgressText: String = ""
    @Published var bookCategories: [String: BookCategory] = [:] // Book ID -> Detected Category
    
    // MARK: - Sync & Deduplication State
    @Published var isSyncScanning: Bool = false
    @Published var syncSheetItems: [ScannedSyncItem] = []
    @Published var syncSourceFolderURL: URL? = nil
    @Published var showSyncSheet: Bool = false
    
    let folderWatcher = FolderWatcherService()
    private let aiClassifier = AIBookClassificationService()
    private let syncService = BookSyncService()
    private let service = BookLibraryService()
    
    // MARK: - Thumbnail Cache
    private var thumbnailCache: [String: NSImage] = [:]
    
    // MARK: - Alerts & Dialogs
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    
    init() {
        let defaultURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        libraryRootURL = defaultURL
        
        folderWatcher.onBookOrganized = { [weak self] in
            self?.refreshLibrary()
        }
        
        refreshLibrary()
    }
    
    // MARK: - Filtered & Sorted Books
    var filteredBooks: [BookItem] {
        var list = books
        
        // 1. Filter by Sidebar Item
        switch selectedSidebarItem {
        case .allBooks:
            break
        case .smartInbox:
            list = list.filter { $0.folderName.contains("Inbox") || $0.folderName.contains("inbox") }
        case .splitParts:
            list = list.filter { $0.baseName.range(of: "_part\\d+", options: .regularExpression) != nil }
        case .category(let targetCat):
            list = list.filter { book in
                let folder = book.folderName
                if folder == targetCat.rawValue || folder == targetCat.folderName || folder.contains(targetCat.rawValue) {
                    return true
                }
                return bookCategories[book.id] == targetCat
            }
        case .splitterTool:
            break
        }
        
        // 2. Search Text
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            list = list.filter { $0.name.lowercased().contains(q) || $0.folderName.lowercased().contains(q) }
        }
        
        // 3. Sorting
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
            
        case .byCategory:
            let dict = Dictionary(grouping: items) { book -> BookCategory in
                // Check if folder is already a known category folder
                let folder = book.folderName
                for cat in BookCategory.allCases {
                    if folder == cat.rawValue || folder == cat.folderName || folder.contains(cat.rawValue) {
                        return cat
                    }
                }
                return bookCategories[book.id] ?? .general
            }
            return dict.map { (category, groupBooks) in
                BookGroup(
                    id: category.rawValue,
                    title: "\(category.rawValue) (\(groupBooks.count) cuốn)",
                    folderURL: groupBooks.first?.folderURL,
                    books: groupBooks
                )
            }.sorted { $0.title < $1.title }
            
        case .byFolder:
            let dict = Dictionary(grouping: items) { $0.folderURL }
            return dict.map { (folderURL, groupBooks) in
                let title = folderURL.lastPathComponent
                return BookGroup(id: folderURL.path, title: "📁 \(title) (\(groupBooks.count) sách)", folderURL: folderURL, books: groupBooks)
            }.sorted { $0.title < $1.title }
            
        case .bySeries:
            let dict = Dictionary(grouping: items) { book -> String in
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
        
        if let doc = PDFDocument(url: book.url), let firstPage = doc.page(at: 0) {
            let thumb = firstPage.thumbnail(of: CGSize(width: 160, height: 210), for: .cropBox)
            thumbnailCache[book.id] = thumb
            return thumb
        }
        return nil
    }
    
    // MARK: - Library Navigation
    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục chứa sách để quản lý"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            libraryRootURL = url
            refreshLibrary()
            
            // Re-bind folder watcher if active
            if folderWatcher.isWatching {
                setupSmartInboxFolder()
            }
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
            
            // Background classify metadata for display
            self.preClassifyBooksInMemory(scanned)
        }
    }
    
    private func preClassifyBooksInMemory(_ items: [BookItem]) {
        Task.detached { [weak self] in
            guard let self = self else { return }
            for book in items {
                let res = await self.aiClassifier.classifyBook(at: book.url)
                Task { @MainActor in
                    self.bookCategories[book.id] = res.category
                }
            }
        }
    }
    
    // MARK: - Smart Inbox Watcher Setup
    func setupSmartInboxFolder() {
        guard let root = libraryRootURL else { return }
        let inboxURL = root.appendingPathComponent("📥_Inbox_Gom_Sach", isDirectory: true)
        if !FileManager.default.fileExists(atPath: inboxURL.path) {
            try? FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        }
        folderWatcher.startWatching(folderURL: inboxURL, libraryTargetDir: root)
        showAlert(
            title: "🤖 Đã Bật Hộp Thư Gom Sách Tự Động",
            message: "Thư mục Hộp Thư Đến đã được tạo tại:\n👉 \"\(inboxURL.path)\"\n\nBất cứ khi nào bạn ném file PDF vào thư mục này, AI sẽ tự động phân loại và gom vào thư mục thể loại tương ứng!"
        )
    }
    
    func toggleSmartInboxWatcher() {
        if folderWatcher.isWatching {
            folderWatcher.stopWatching()
            showAlert(title: "Đã Tắt Giám Sát", message: "Đã tắt tính năng tự động phân loại khi ném file vào thư mục.")
        } else {
            setupSmartInboxFolder()
        }
    }
    
    // MARK: - AI Batch Classification & Auto Move
    func classifyAndOrganizeSelectedBooks() {
        guard !selectedBookIDs.isEmpty else {
            showAlert(title: "Chưa chọn sách", message: "Vui lòng chọn ít nhất một cuốn sách để AI phân loại.")
            return
        }
        
        let targetItems = books.filter { selectedBookIDs.contains($0.id) }
        performAIBatchOrganize(items: targetItems)
    }
    
    func classifyAndOrganizeAllBooks() {
        guard !books.isEmpty else { return }
        performAIBatchOrganize(items: books)
    }
    
    private func performAIBatchOrganize(items: [BookItem]) {
        guard let root = libraryRootURL else { return }
        isAIOrganizing = true
        aiProgressText = "Khởi động AI..."
        
        Task {
            var organizedCount = 0
            for (idx, book) in items.enumerated() {
                self.aiProgressText = "Đang phân tích (\(idx + 1)/\(items.count)): \(book.name)"
                
                let res = await self.aiClassifier.classifyBook(at: book.url)
                let targetCategoryDir = root.appendingPathComponent(res.category.rawValue, isDirectory: true)
                
                do {
                    if !FileManager.default.fileExists(atPath: targetCategoryDir.path) {
                        try FileManager.default.createDirectory(at: targetCategoryDir, withIntermediateDirectories: true)
                    }
                    
                    let destURL = targetCategoryDir.appendingPathComponent(book.name)
                    if destURL.path != book.url.path {
                        if FileManager.default.fileExists(atPath: destURL.path) {
                            try FileManager.default.removeItem(at: destURL)
                        }
                        try FileManager.default.moveItem(at: book.url, to: destURL)
                        organizedCount += 1
                    }
                } catch {
                    print("Lỗi di chuyển: \(error.localizedDescription)")
                }
            }
            
            self.isAIOrganizing = false
            self.refreshLibrary()
            self.showAlert(
                title: "🎉 AI Phân Loại Hoàn Tất",
                message: "Đã tự động phân loại và gom \(organizedCount) cuốn sách vào các thư mục thể loại tương ứng!"
            )
        }
    }
    
    // MARK: - Selection Actions
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
    
    // MARK: - Scan & Sync Source Folder Prompt
    func promptScanAndSyncSourceFolder() {
        guard libraryRootURL != nil else {
            showAlert(title: "Chưa chọn kho sách", message: "Vui lòng chọn thư mục kho sách đích trước.")
            return
        }
        
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục nguồn cần quét sách (ví dụ: Downloads)"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let sourceURL = panel.url {
            syncSourceFolderURL = sourceURL
            isSyncScanning = true
            
            Task {
                let scannedItems = await syncService.scanAndCompare(sourceDir: sourceURL, existingBooks: self.books)
                self.syncSheetItems = scannedItems
                self.isSyncScanning = false
                
                if scannedItems.isEmpty {
                    self.showAlert(
                        title: "Không Có Sách PDF",
                        message: "Không tìm thấy file sách PDF nào trong thư mục:\n\(sourceURL.path)"
                    )
                } else {
                    self.showSyncSheet = true
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
