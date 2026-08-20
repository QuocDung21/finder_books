import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import UserNotifications

@MainActor
final class FolderWatcherService: ObservableObject {
    @Published var isWatching: Bool = false
    @Published var watchedFolderURL: URL? = nil
    @Published var lastOrganizedBookName: String = ""
    @Published var lastOrganizedCategory: String = ""
    
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private let aiClassifier = AIBookClassificationService()
    
    var onBookOrganized: (() -> Void)?
    
    init() {
        requestNotificationPermission()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    // MARK: - Start Watching Folder
    func startWatching(folderURL: URL, libraryTargetDir: URL) {
        stopWatching()
        
        let path = folderURL.path
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let queue = DispatchQueue(label: "com.pdfsplitter.folderwatcher", qos: .utility)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib],
            queue: queue
        )
        
        source.setEventHandler { [weak self] in
            self?.handleFolderEvent(in: folderURL, targetDir: libraryTargetDir)
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        
        self.source = source
        source.resume()
        self.watchedFolderURL = folderURL
        self.isWatching = true
    }
    
    // MARK: - Stop Watching
    func stopWatching() {
        if let src = source {
            src.cancel()
            source = nil
        }
        isWatching = false
    }
    
    // MARK: - Process Folder Event
    private func handleFolderEvent(in folderURL: URL, targetDir: URL) {
        // Đợi 1.5 giây để file ném vào được ghi hoàn tất
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: .skipsHiddenFiles) else {
                return
            }
            
            let pdfFiles = files.filter { $0.pathExtension.lowercased() == "pdf" }
            for pdfFile in pdfFiles {
                Task {
                    await self.processAndOrganizeSingleFile(fileURL: pdfFile, baseLibraryDir: targetDir)
                }
            }
        }
    }
    
    // MARK: - Classify & Move Single File
    func processAndOrganizeSingleFile(fileURL: URL, baseLibraryDir: URL) async {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        
        let classification = await aiClassifier.classifyBook(at: fileURL)
        let category = classification.category
        
        // Thư mục đích theo thể loại
        let targetCategoryDir = baseLibraryDir.appendingPathComponent(category.rawValue, isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: targetCategoryDir.path) {
                try fileManager.createDirectory(at: targetCategoryDir, withIntermediateDirectories: true)
            }
            
            let destinationURL = targetCategoryDir.appendingPathComponent(fileURL.lastPathComponent)
            if destinationURL.path != fileURL.path {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: fileURL, to: destinationURL)
            }
            
            Task { @MainActor in
                self.lastOrganizedBookName = fileURL.lastPathComponent
                self.lastOrganizedCategory = category.rawValue
                self.sendNotification(bookName: fileURL.lastPathComponent, category: category.rawValue)
                self.onBookOrganized?()
            }
        } catch {
            print("Lỗi di chuyển sách tự động: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Notification
    private func sendNotification(bookName: String, category: String) {
        let content = UNMutableNotificationContent()
        content.title = "🤖 AI Đã Tự Động Phân Loại Sách"
        content.body = "Đã gom cuốn \"\(bookName)\" vào thể loại \"\(category)\""
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
