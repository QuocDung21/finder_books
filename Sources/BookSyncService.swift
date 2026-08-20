import Foundation
import PDFKit
import AppKit

struct BookSyncService {
    private let aiClassifier = AIBookClassificationService()
    
    // MARK: - Scan Source Directory & Compare With Library
    func scanAndCompare(sourceDir: URL, existingBooks: [BookItem]) async -> [ScannedSyncItem] {
        return await Task.detached {
            var results: [ScannedSyncItem] = []
            let fileManager = FileManager.default
            
            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
            guard let enumerator = fileManager.enumerator(
                at: sourceDir,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            
            // Build index of existing books for fast lookup
            var existingNames: [String: BookItem] = [:]
            var existingSizes: [Int64: [BookItem]] = [:]
            
            for book in existingBooks {
                let normalizedName = book.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                existingNames[normalizedName] = book
                
                if let attrs = try? fileManager.attributesOfItem(atPath: book.url.path),
                   let size = attrs[.size] as? Int64 {
                    existingSizes[size, default: []].append(book)
                }
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                guard fileURL.pathExtension.lowercased() == "pdf" else { continue }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                    guard resourceValues.isRegularFile == true else { continue }
                    
                    let modDate = resourceValues.contentModificationDate ?? Date()
                    let sizeBytes = Int64(resourceValues.fileSize ?? 0)
                    let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
                    
                    var pages = 0
                    if let doc = PDFDocument(url: fileURL) {
                        pages = doc.pageCount
                    }
                    
                    let filename = fileURL.lastPathComponent
                    let normalizedName = filename.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    
                    // Duplicate Detection Logic
                    var syncStatus: BookSyncStatus = .newBook
                    var defaultAction: BookSyncAction = .moveToLibrary
                    
                    if let exactMatch = existingNames[normalizedName] {
                        syncStatus = .duplicate(existingPath: exactMatch.url.path, existingName: exactMatch.name)
                        defaultAction = .deleteFromSource
                    } else if let sameSizeBooks = existingSizes[sizeBytes], let firstSizeMatch = sameSizeBooks.first(where: { $0.pageCount == pages && pages > 0 }) {
                        syncStatus = .duplicate(existingPath: firstSizeMatch.url.path, existingName: firstSizeMatch.name)
                        defaultAction = .deleteFromSource
                    }
                    
                    let item = ScannedSyncItem(
                        id: fileURL.path,
                        sourceURL: fileURL,
                        name: filename,
                        baseName: baseName,
                        fileSizeMB: sizeMB,
                        pageCount: pages,
                        modifiedDate: modDate,
                        status: syncStatus,
                        action: defaultAction,
                        isSelected: true
                    )
                    results.append(item)
                } catch {
                    continue
                }
            }
            
            return results
        }.value
    }
    
    // MARK: - Execute Sync & Deduplication
    func executeSync(
        items: [ScannedSyncItem],
        targetLibraryDir: URL,
        autoClassifyWithAI: Bool,
        onProgress: @escaping (String) -> Void
    ) async -> SyncExecutionSummary {
        var summary = SyncExecutionSummary()
        let fileManager = FileManager.default
        
        for item in items where item.isSelected {
            guard fileManager.fileExists(atPath: item.sourceURL.path) else { continue }
            
            switch item.action {
            case .moveToLibrary:
                onProgress("Đang di chuyển: \(item.name)...")
                
                var destDir = targetLibraryDir
                if autoClassifyWithAI {
                    onProgress("AI phân loại: \(item.name)...")
                    let res = await aiClassifier.classifyBook(at: item.sourceURL)
                    destDir = targetLibraryDir.appendingPathComponent(res.category.rawValue, isDirectory: true)
                }
                
                do {
                    if !fileManager.fileExists(atPath: destDir.path) {
                        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
                    }
                    
                    let destURL = destDir.appendingPathComponent(item.name)
                    if destURL.path != item.sourceURL.path {
                        if fileManager.fileExists(atPath: destURL.path) {
                            try fileManager.removeItem(at: destURL)
                        }
                        try fileManager.moveItem(at: item.sourceURL, to: destURL)
                        summary.movedCount += 1
                    }
                } catch {
                    summary.errorCount += 1
                }
                
            case .deleteFromSource:
                onProgress("Xoá file trùng ở nguồn: \(item.name)...")
                do {
                    try fileManager.trashItem(at: item.sourceURL, resultingItemURL: nil)
                    summary.deletedCount += 1
                } catch {
                    summary.errorCount += 1
                }
                
            case .skip:
                summary.skippedCount += 1
            }
        }
        
        return summary
    }
}
