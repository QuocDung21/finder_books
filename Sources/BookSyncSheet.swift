import SwiftUI
import PDFKit

struct BookSyncSheet: View {
    let sourceFolderURL: URL
    let libraryTargetURL: URL
    @State var items: [ScannedSyncItem]
    var onSyncCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var filterMode: SyncFilterTab = .all
    @State private var autoClassifyWithAI: Bool = true
    @State private var isExecuting: Bool = false
    @State private var progressText: String = ""
    @State private var showResultAlert: Bool = false
    @State private var resultMessage: String = ""
    
    private let syncService = BookSyncService()
    
    enum SyncFilterTab: String, CaseIterable, Identifiable {
        case all = "Tất Cả"
        case newOnly = "Sách Mới"
        case duplicatesOnly = "Sách Trùng"
        
        var id: String { rawValue }
    }
    
    var filteredItems: [ScannedSyncItem] {
        switch filterMode {
        case .all:
            return items
        case .newOnly:
            return items.filter { $0.status == .newBook }
        case .duplicatesOnly:
            return items.filter {
                if case .duplicate = $0.status { return true }
                return false
            }
        }
    }
    
    var newBooksCount: Int {
        items.filter { $0.status == .newBook }.count
    }
    
    var duplicateBooksCount: Int {
        items.filter {
            if case .duplicate = $0.status { return true }
            return false
        }.count
    }
    
    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Filter & Batch Control Bar
            controlBarView
            
            Divider()
            
            // List of Scanned Books
            itemsListView
            
            Divider()
            
            // Footer
            footerView
        }
        .frame(minWidth: 800, minHeight: 560)
        .alert(isPresented: $showResultAlert) {
            Alert(
                title: Text("Hoàn Tất Đồng Bộ"),
                message: Text(resultMessage),
                dismissButton: .default(Text("Đóng")) {
                    onSyncCompleted()
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Quét & So Sánh Sách Từ Thư Mục Nguồn")
                    .font(.system(size: 16, weight: .bold))
                
                HStack(spacing: 6) {
                    Text("Nguồn:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(sourceFolderURL.path)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text("➔  Kho Đích:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(libraryTargetURL.lastPathComponent)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            
            Spacer()
            
            // Summary Badges
            HStack(spacing: 8) {
                BadgeTag(icon: "plus.circle.fill", text: "\(newBooksCount) Mới", color: .green)
                BadgeTag(icon: "exclamationmark.triangle.fill", text: "\(duplicateBooksCount) Trùng", color: .orange)
                BadgeTag(icon: "doc.text.fill", text: "\(items.count) Tổng", color: .secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.platformControlBackground)
    }
    
    // MARK: - Control Bar
    private var controlBarView: some View {
        HStack(spacing: 12) {
            Picker("Lọc", selection: $filterMode) {
                Text("Tất Cả (\(items.count))").tag(SyncFilterTab.all)
                Text("Sách Mới (\(newBooksCount))").tag(SyncFilterTab.newOnly)
                Text("Sách Trùng (\(duplicateBooksCount))").tag(SyncFilterTab.duplicatesOnly)
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            
            Divider().frame(height: 18)
            
            // Quick Batch Presets
            Button("Chọn Sách Mới -> Di Chuyển") {
                setBatchAction(for: .newOnly, action: .moveToLibrary)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Chọn Sách Trùng -> Xoá") {
                setBatchAction(for: .duplicatesOnly, action: .deleteFromSource)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
            
            Toggle("Tự động phân loại thể loại", isOn: $autoClassifyWithAI)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.platformControlBackground.opacity(0.6))
    }
    
    // MARK: - Items List
    private var itemsListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 6) {
                ForEach(filteredItems.indices, id: \.self) { idx in
                    let item = filteredItems[idx]
                    let globalIndex = items.firstIndex(where: { $0.id == item.id }) ?? 0
                    
                    HStack(spacing: 10) {
                        // Checkbox
                        Toggle("", isOn: $items[globalIndex].isSelected)
                            .labelsHidden()
                            .controlSize(.small)
                        
                        // Status Badge
                        HStack(spacing: 4) {
                            Image(systemName: item.status.icon)
                                .font(.system(size: 10))
                            Text(item.status.title)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(item.status.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(item.status.color.opacity(0.12))
                        .cornerRadius(4)
                        .frame(width: 135, alignment: .leading)
                        
                        // Book Details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                Text("\(item.pageCount) trang  •  \(item.formattedSize)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                if case .duplicate(let existingPath, let existingName) = item.status {
                                    Text("Trùng với: \(existingName)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                        .help("Đường dẫn file trùng: \(existingPath)")
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Action Picker for this item
                        Picker("Hành động", selection: $items[globalIndex].action) {
                            ForEach(BookSyncAction.allCases) { act in
                                Label(act.rawValue, systemImage: act.icon).tag(act)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 170)
                        .controlSize(.small)
                        .disabled(!items[globalIndex].isSelected)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(items[globalIndex].isSelected ? Color.platformControlBackground : Color.clear)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
                    )
                }
            }
            .padding(16)
        }
        .background(Color.platformWindowBackground)
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            if isExecuting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(progressText)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
            } else {
                Text("Đã chọn \(selectedCount)/\(items.count) cuốn sách để xử lý")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Huỷ Bỏ") {
                dismiss()
            }
            .disabled(isExecuting)
            
            Button {
                startSyncExecution()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text("Thực Hiện Đồng Bộ (\(selectedCount))")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .controlSize(.regular)
            .disabled(selectedCount == 0 || isExecuting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.platformControlBackground)
    }
    
    // MARK: - Helpers
    private func setBatchAction(for tab: SyncFilterTab, action: BookSyncAction) {
        for idx in items.indices {
            let item = items[idx]
            if tab == .newOnly && item.status == .newBook {
                items[idx].isSelected = true
                items[idx].action = action
            } else if tab == .duplicatesOnly {
                if case .duplicate = item.status {
                    items[idx].isSelected = true
                    items[idx].action = action
                }
            }
        }
    }
    
    private func startSyncExecution() {
        isExecuting = true
        progressText = "Bắt đầu xử lý..."
        
        Task {
            let summary = await syncService.executeSync(
                items: items,
                targetLibraryDir: libraryTargetURL,
                autoClassifyWithAI: autoClassifyWithAI,
                onProgress: { msg in
                    Task { @MainActor in
                        self.progressText = msg
                    }
                }
            )
            
            self.isExecuting = false
            self.resultMessage = """
            Đã di chuyển về kho: \(summary.movedCount) cuốn sách
            Đã xoá ở nguồn (trùng lặp): \(summary.deletedCount) file
            Đã bỏ qua: \(summary.skippedCount) file
            """
            self.showResultAlert = true
        }
    }
}

// MARK: - Badge Tag
struct BadgeTag: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }
}
