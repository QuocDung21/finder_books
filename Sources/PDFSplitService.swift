import Foundation
import PDFKit

enum PDFSplitError: LocalizedError {
    case cannotLoadDocument(String)
    case invalidPageRange(String)
    case cannotWriteFile(String)
    case createDirectoryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cannotLoadDocument(let path):
            return "Không thể mở file PDF nguồn: \(path)"
        case .invalidPageRange(let details):
            return "Khoảng trang không hợp lệ: \(details)"
        case .cannotWriteFile(let path):
            return "Không thể ghi file ra đĩa: \(path)"
        case .createDirectoryFailed(let path):
            return "Không thể tạo thư mục: \(path)"
        }
    }
}

actor PDFSplitService {
    
    struct ExportTask {
        let partNum: Int
        let startPage: Int
        let endPage: Int
        let count: Int
        let outputURL: URL
        let filename: String
    }
    
    func executeSplit(
        sourceURL: URL,
        tasks: [ExportTask],
        onProgress: @escaping @Sendable (Double, String) -> Void,
        onLog: @escaping @Sendable (String, String) -> Void
    ) async throws {
        guard let sourceDoc = PDFDocument(url: sourceURL) else {
            throw PDFSplitError.cannotLoadDocument(sourceURL.path)
        }
        
        let totalPagesInDoc = sourceDoc.pageCount
        let totalPagesToExport = tasks.reduce(0) { $0 + $1.count }
        var pagesWrittenSoFar = 0
        let startTime = Date()
        
        for task in tasks {
            onLog("⏳", "Đang trích xuất Phần \(task.partNum)/\(tasks.count): trang \(task.startPage) -> \(task.endPage) (\(task.count) trang)...")
            
            // Đảm bảo thư mục cha tồn tại
            let parentDir = task.outputURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
            
            let partDoc = PDFDocument()
            
            // PDFKit dùng 0-based index
            for pageIndex in (task.startPage - 1)...(task.endPage - 1) {
                if pageIndex >= 0 && pageIndex < totalPagesInDoc, let page = sourceDoc.page(at: pageIndex) {
                    partDoc.insert(page, at: partDoc.pageCount)
                }
                
                pagesWrittenSoFar += 1
                let progressPercent = min(0.98, Double(pagesWrittenSoFar) / Double(max(1, totalPagesToExport)))
                let stepDesc = "Ghi Phần \(task.partNum): trang \(pageIndex + 1)/\(task.endPage)"
                onProgress(progressPercent, stepDesc)
            }
            
            let writeSuccess = partDoc.write(to: task.outputURL)
            if !writeSuccess {
                throw PDFSplitError.cannotWriteFile(task.outputURL.path)
            }
            
            onLog("✅", "Đã ghi xong Phần \(task.partNum): \(task.filename)")
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        onProgress(1.0, "Hoàn tất 100%")
        onLog("🎉", String(format: "Đã xuất thành công %d file trong %.2f giây!", tasks.count, elapsed))
    }
}
