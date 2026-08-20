import Foundation
import PDFKit
import AppKit

struct BookLibraryService {
    
    // MARK: - Scan Directory for Books
    func scanDirectory(at rootURL: URL, recursive: Bool = true) async -> [BookItem] {
        return await Task.detached {
            var results: [BookItem] = []
            let fileManager = FileManager.default
            
            let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
            let options: FileManager.DirectoryEnumerationOptions = recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: keys,
                options: options
            ) else {
                return []
            }
            
            while let fileURL = enumerator.nextObject() as? URL {
                guard fileURL.pathExtension.lowercased() == "pdf" else { continue }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                    guard resourceValues.isRegularFile == true else { continue }
                    
                    let modDate = resourceValues.contentModificationDate ?? Date()
                    let sizeBytes = resourceValues.fileSize ?? 0
                    let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
                    
                    // Get page count using PDFDocument
                    var pages = 0
                    if let doc = PDFDocument(url: fileURL) {
                        pages = doc.pageCount
                    }
                    
                    let parentFolder = fileURL.deletingLastPathComponent()
                    let folderName = parentFolder.lastPathComponent
                    let filename = fileURL.lastPathComponent
                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    
                    let item = BookItem(
                        id: fileURL.path,
                        url: fileURL,
                        name: filename,
                        baseName: baseName,
                        fileSizeMB: sizeMB,
                        pageCount: pages,
                        modifiedDate: modDate,
                        folderURL: parentFolder,
                        folderName: folderName
                    )
                    results.append(item)
                } catch {
                    continue
                }
            }
            
            return results
        }.value
    }
    
    // MARK: - Move / Group Books Into New Folder
    func groupBooksIntoNewFolder(books: [BookItem], targetFolderName: String, parentDir: URL) throws -> URL {
        let fileManager = FileManager.default
        let newFolderURL = parentDir.appendingPathComponent(targetFolderName, isDirectory: true)
        
        if !fileManager.fileExists(atPath: newFolderURL.path) {
            try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
        }
        
        for book in books {
            let destURL = newFolderURL.appendingPathComponent(book.name)
            if destURL.path != book.url.path {
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                try fileManager.moveItem(at: book.url, to: destURL)
            }
        }
        
        return newFolderURL
    }
    
    // MARK: - Auto Group Split Parts
    func autoGroupSplitParts(in rootURL: URL) throws -> Int {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil) else {
            return 0
        }
        
        let pdfFiles = files.filter { $0.pathExtension.lowercased() == "pdf" }
        var groupedCount = 0
        
        for file in pdfFiles {
            let base = file.deletingPathExtension().lastPathComponent
            if let range = base.range(of: "_part\\d+", options: .regularExpression) {
                let seriesName = String(base[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !seriesName.isEmpty {
                    let folderURL = rootURL.appendingPathComponent("\(seriesName)_DaTach", isDirectory: true)
                    if !fileManager.fileExists(atPath: folderURL.path) {
                        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
                    }
                    let dest = folderURL.appendingPathComponent(file.lastPathComponent)
                    if dest.path != file.path {
                        if fileManager.fileExists(atPath: dest.path) {
                            try fileManager.removeItem(at: dest)
                        }
                        try fileManager.moveItem(at: file, to: dest)
                        groupedCount += 1
                    }
                }
            }
        }
        return groupedCount
    }
    
    // MARK: - Delete Book File
    func deleteBook(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
