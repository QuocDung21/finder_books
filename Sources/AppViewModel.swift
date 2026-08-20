import SwiftUI
import PDFKit
import AppKit

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - File State
    @Published var selectedPDFURL: URL? = nil
    @Published var fileName: String = ""
    @Published var totalPages: Int = 0
    @Published var fileSizeMB: Double = 0.0
    @Published var thumbnailImage: PlatformImage? = nil
    private(set) var loadedPDFDocument: PDFDocument? = nil

    // Quick preview state
    @Published var previewPart: PdfPartItem? = nil

    // MARK: - Output Folder State
    @Published var outputFolderURL: URL? = nil
    @Published var outputFolderPath: String = ""
    @Published var createSubfolder: Bool = true
    @Published var subfolderName: String = "Sach_Da_Tach"
    @Published var askBeforeCreateDir: Bool = true

    // MARK: - Split Configuration
    @Published var splitMode: SplitMode = .byParts {
        didSet {
            withAnimation(.easeInOut(duration: 0.2)) {
                recalculateParts()
            }
        }
    }
    @Published var partsCount: Int = 2 {
        didSet {
            if splitMode == .byParts {
                withAnimation(.easeInOut(duration: 0.2)) {
                    recalculateParts()
                }
            }
        }
    }

    // For Custom Pages mode
    @Published var customRanges: [CustomRangeInput] = []

    // Final calculated parts
    @Published var calculatedParts: [PdfPartItem] = []

    // MARK: - Processing & Logs
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentStepText: String = "Đang chờ..."
    @Published var statusMessage: String = "Sẵn sàng"
    @Published var statusColor: Color = .secondary
    @Published var logs: [LogEntry] = []

    // MARK: - Alerts
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var alertConfirmAction: (() -> Void)? = nil
    @Published var alertShowCancel: Bool = false
    @Published var alertConfirmButtonTitle: String = "OK"

    private let splitService = PDFSplitService()

    init() {
        addLog(icon: "ℹ️", message: "Hệ thống sẵn sàng. Vui lòng chọn sách PDF để bắt đầu.")
    }

    // MARK: - Logging Helper
    func addLog(icon: String, message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let entry = LogEntry(timestamp: timestamp, icon: icon, message: message)
        logs.append(entry)
    }

    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Select & Load PDF
    func loadPDF(from url: URL) {
        guard let doc = PDFDocument(url: url) else {
            addLog(icon: "❌", message: "Không thể đọc file PDF: \(url.lastPathComponent)")
            showSimpleAlert(title: "Lỗi Đọc File", message: "Không thể mở hoặc phân tích file PDF đã chọn.")
            return
        }

        selectedPDFURL = url
        fileName = url.lastPathComponent
        totalPages = doc.pageCount
        loadedPDFDocument = doc

        // Generate PDF Thumbnail
        if let firstPage = doc.page(at: 0) {
            thumbnailImage = firstPage.platformThumbnail(size: CGSize(width: 140, height: 180))
        } else {
            thumbnailImage = nil
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            fileSizeMB = Double(size) / (1024.0 * 1024.0)
        } else {
            fileSizeMB = 0.0
        }

        let baseDir = url.deletingLastPathComponent()
        if outputFolderURL == nil {
            outputFolderURL = baseDir
            outputFolderPath = baseDir.path
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        subfolderName = "\(baseName)_DaTach"

        initDefaultCustomRanges()
        recalculateParts()

        statusMessage = "Đã nạp file PDF (\(totalPages) trang)"
        statusColor = .green
        addLog(icon: "📖", message: String(format: "Đã nạp file: %@ (%d trang, %.2f MB)", fileName, totalPages, fileSizeMB))
    }

    // MARK: - Quick Page Preview Helpers
    func getPageThumbnail(pageNumber: Int, size: CGSize = CGSize(width: 220, height: 290)) -> PlatformImage? {
        guard let doc = loadedPDFDocument, pageNumber >= 1, pageNumber <= doc.pageCount else { return nil }
        guard let page = doc.page(at: pageNumber - 1) else { return nil }
        return page.platformThumbnail(size: size)
    }

    func getPageSnippet(pageNumber: Int, maxLines: Int = 4) -> String {
        guard let doc = loadedPDFDocument, pageNumber >= 1, pageNumber <= doc.pageCount else { return "" }
        guard let page = doc.page(at: pageNumber - 1), let text = page.string else { return "Không có nội dung văn bản (Trang dạng hình ảnh/scan)" }
        let cleanLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if cleanLines.isEmpty {
            return "Không có văn bản trích xuất được"
        }
        return cleanLines.prefix(maxLines).joined(separator: " • ")
    }

    func choosePDFFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Chọn sách PDF cần tách"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            loadPDF(from: url)
        }
        #endif
    }

    func chooseOutputFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Chọn thư mục lưu file xuất"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            outputFolderURL = url
            outputFolderPath = url.path
            addLog(icon: "📂", message: "Đã chọn thư mục lưu: \(url.path)")
        }
        #endif
    }

    func revealInFinder() {
        #if os(macOS)
        if let outDir = outputFolderURL {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: outDir.path)
        }
        #endif
    }

    func createNewFolderPrompt() {
        guard let baseFolder = outputFolderURL ?? (selectedPDFURL?.deletingLastPathComponent()) else {
            showSimpleAlert(title: "Chưa Chọn Thư Mục", message: "Vui lòng chọn thư mục gốc trước khi tạo thư mục con mới.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Tạo Thư Mục Mới"
        alert.informativeText = "Nhập tên thư mục mới cần tạo trong:\n\(baseFolder.path)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tạo")
        alert.addButton(withTitle: "Huỷ")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        inputTextField.stringValue = "Thu_Muc_Moi"
        alert.accessoryView = inputTextField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                let newURL = baseFolder.appendingPathComponent(name, isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
                    outputFolderURL = newURL
                    outputFolderPath = newURL.path
                    addLog(icon: "📁", message: "Đã tạo thư mục mới: \(newURL.path)")
                } catch {
                    addLog(icon: "❌", message: "Lỗi tạo thư mục: \(error.localizedDescription)")
                    showSimpleAlert(title: "Lỗi Tạo Thư Mục", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Calculations
    func initDefaultCustomRanges() {
        guard totalPages > 0 else {
            customRanges = []
            return
        }
        let baseName = selectedPDFURL?.deletingPathExtension().lastPathComponent ?? "phan"
        let mid = (totalPages + 1) / 2

        customRanges = [
            CustomRangeInput(
                startPageText: "1",
                endPageText: "\(mid)",
                filename: "\(baseName)_part1.pdf"
            ),
            CustomRangeInput(
                startPageText: "\(mid + 1)",
                endPageText: "\(totalPages)",
                filename: "\(baseName)_part2.pdf"
            )
        ]
    }

    func addCustomRange() {
        guard totalPages > 0 else { return }
        let baseName = selectedPDFURL?.deletingPathExtension().lastPathComponent ?? "phan"
        var nextStart = 1
        if let last = customRanges.last, let lastEnd = Int(last.endPageText) {
            nextStart = min(totalPages, lastEnd + 1)
        }
        let nextIndex = customRanges.count + 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            customRanges.append(
                CustomRangeInput(
                    startPageText: "\(nextStart)",
                    endPageText: "\(totalPages)",
                    filename: "\(baseName)_part\(nextIndex).pdf"
                )
            )
            recalculateParts()
        }
    }

    func removeCustomRange(at index: Int) {
        guard customRanges.count > 1, index < customRanges.count else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            customRanges.remove(at: index)
            recalculateParts()
        }
    }

    func autoFillRanges() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            initDefaultCustomRanges()
            recalculateParts()
        }
    }

    func recalculateParts() {
        guard totalPages > 0 else {
            calculatedParts = []
            return
        }

        let baseName = selectedPDFURL?.deletingPathExtension().lastPathComponent ?? "phan"
        var result: [PdfPartItem] = []

        if splitMode == .byParts {
            let k = max(2, partsCount)
            let baseCount = totalPages / k
            let remainder = totalPages % k
            var currentPage = 1

            for i in 0..<k {
                let partNum = i + 1
                let count = baseCount + (i < remainder ? 1 : 0)
                let startP = currentPage
                let endP = currentPage + count - 1
                currentPage = endP + 1
                let color = AppColors.partColor(at: i)
                let fn = "\(baseName)_part\(partNum).pdf"

                result.append(
                    PdfPartItem(
                        partNum: partNum,
                        startPage: startP,
                        endPage: endP,
                        filename: fn,
                        color: color
                    )
                )
            }
        } else {
            for (i, item) in customRanges.enumerated() {
                let partNum = i + 1
                let startP = max(1, min(totalPages, Int(item.startPageText) ?? 1))
                let endP = max(startP, min(totalPages, Int(item.endPageText) ?? totalPages))
                let color = AppColors.partColor(at: i)
                let fn = item.filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "\(baseName)_part\(partNum).pdf"
                    : item.filename

                result.append(
                    PdfPartItem(
                        partNum: partNum,
                        startPage: startP,
                        endPage: endP,
                        filename: fn,
                        color: color
                    )
                )
            }
        }

        calculatedParts = result
    }

    func updateCustomRangeStart(index: Int, val: String) {
        guard index < customRanges.count else { return }
        customRanges[index].startPageText = val
        recalculateParts()
    }

    func updateCustomRangeEnd(index: Int, val: String) {
        guard index < customRanges.count else { return }
        customRanges[index].endPageText = val
        recalculateParts()
    }

    func updatePartFilename(index: Int, val: String) {
        if index < calculatedParts.count {
            calculatedParts[index].filename = val
        }
        if index < customRanges.count {
            customRanges[index].filename = val
        }
    }

    // MARK: - Export Process
    func startExport() {
        guard !isProcessing else { return }

        guard let sourceURL = selectedPDFURL, FileManager.default.fileExists(atPath: sourceURL.path) else {
            showSimpleAlert(title: "Thiếu dữ liệu", message: "Vui lòng chọn file sách PDF nguồn!")
            return
        }

        guard let baseOutDir = outputFolderURL else {
            showSimpleAlert(title: "Thiếu dữ liệu", message: "Vui lòng chọn thư mục lưu kết quả!")
            return
        }

        guard !calculatedParts.isEmpty else {
            showSimpleAlert(title: "Thiếu dữ liệu", message: "Chưa có thông tin phân chia sách hợp lệ!")
            return
        }

        var targetDir = baseOutDir
        if createSubfolder {
            let cleanSub = subfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanSub.isEmpty {
                targetDir = baseOutDir.appendingPathComponent(cleanSub, isDirectory: true)
            }
        }

        // Kiểm tra thư mục đích đã tồn tại chưa
        if !FileManager.default.fileExists(atPath: targetDir.path) && askBeforeCreateDir {
            showConfirmAlert(
                title: "Xác Nhận Tạo Thư Mục",
                message: "📁 Thư mục lưu kết quả chưa tồn tại:\n\n👉 \"\(targetDir.path)\"\n\nBạn có muốn tạo mới thư mục này không?",
                confirmTitle: "Tạo & Tiếp Tục"
            ) { [weak self] in
                self?.performExport(sourceURL: sourceURL, targetDir: targetDir)
            }
        } else {
            performExport(sourceURL: sourceURL, targetDir: targetDir)
        }
    }

    private func performExport(sourceURL: URL, targetDir: URL) {
        var tasks: [PDFSplitService.ExportTask] = []
        for p in calculatedParts {
            var fn = p.filename.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fn.lowercased().hasSuffix(".pdf") {
                fn += ".pdf"
            }
            let outURL = targetDir.appendingPathComponent(fn)
            tasks.append(
                PDFSplitService.ExportTask(
                    partNum: p.partNum,
                    startPage: p.startPage,
                    endPage: p.endPage,
                    count: p.pageCount,
                    outputURL: outURL,
                    filename: fn
                )
            )
        }

        isProcessing = true
        progress = 0.0
        currentStepText = "Khởi động..."
        let modeDesc = splitMode == .byParts ? "chia \(tasks.count) phần" : "cắt \(tasks.count) khoảng trang"
        statusMessage = "Đang \(modeDesc)..."
        statusColor = .accentColor
        addLog(icon: "🚀", message: "Bắt đầu quy trình xuất sách (\(modeDesc))...")

        Task {
            do {
                try await splitService.executeSplit(
                    sourceURL: sourceURL,
                    tasks: tasks,
                    onProgress: { [weak self] pct, step in
                        Task { @MainActor [weak self] in
                            self?.progress = pct
                            self?.currentStepText = step
                        }
                    },
                    onLog: { [weak self] icon, msg in
                        Task { @MainActor [weak self] in
                            self?.addLog(icon: icon, message: msg)
                        }
                    }
                )

                isProcessing = false
                statusMessage = "Đã xuất \(tasks.count) phần thành công!"
                statusColor = .green

                // Play native system success sound
                NSSound(named: "Glass")?.play()

                showSuccessExportAlert(tasks: tasks, targetDir: targetDir)
            } catch {
                isProcessing = false
                progress = 0.0
                currentStepText = "Lỗi xảy ra"
                statusMessage = "Lỗi khi xuất sách"
                statusColor = .red
                addLog(icon: "❌", message: "Lỗi: \(error.localizedDescription)")
                showSimpleAlert(title: "Lỗi Xuất Sách", message: "Không thể xuất file PDF:\n\(error.localizedDescription)")
            }
        }
    }

    private func showSuccessExportAlert(tasks: [PDFSplitService.ExportTask], targetDir: URL) {
        let details = tasks.map { "🔹 Phần \($0.partNum): \($0.filename) (Trang \($0.startPage) ➔ \($0.endPage), \($0.count) trang)" }.joined(separator: "\n")
        let msg = "🎉 Xuất sách hoàn tất thành \(tasks.count) file:\n\n\(details)\n\n📁 Lưu tại: \(targetDir.path)\n\nBạn có muốn mở ngay thư mục chứa các file vừa xuất?"

        showConfirmAlert(
            title: "Xuất Sách Thành Công",
            message: msg,
            confirmTitle: "Mở Thư Mục"
        ) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: targetDir.path)
        }
    }

    // MARK: - Alert Helpers
    private func showSimpleAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        alertShowCancel = false
        alertConfirmButtonTitle = "Đóng"
        alertConfirmAction = nil
        showAlert = true
    }

    private func showConfirmAlert(title: String, message: String, confirmTitle: String = "Đồng ý", onConfirm: @escaping () -> Void) {
        alertTitle = title
        alertMessage = message
        alertShowCancel = true
        alertConfirmButtonTitle = confirmTitle
        alertConfirmAction = onConfirm
        showAlert = true
    }
}
