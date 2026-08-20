import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct BookSplitterView: View {
    @ObservedObject var vm: AppViewModel
    var isEmbeddedInModal: Bool = false
    var onDismiss: (() -> Void)? = nil
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header if modal
            if isEmbeddedInModal {
                HStack(spacing: 12) {
                    Image(systemName: "scissors.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Công Cụ Tách & Trích Xuất Sách PDF")
                            .font(.system(size: 15, weight: .bold))
                        Text(vm.fileName.isEmpty ? "Chọn sách hoặc kéo thả file để bắt đầu tách" : "Đang xử lý: \(vm.fileName)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let dismiss = onDismiss {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.platformControlBackground)
                
                Divider()
            }
            
            // Splitter Body
            #if os(macOS)
            HSplitView {
                splitterLeftPane
                splitterRightPane
            }
            #elseif os(iOS)
            HStack(spacing: 0) {
                splitterLeftPane
                Divider()
                splitterRightPane
            }
            #endif
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension.lowercased() == "pdf" {
                    Task { @MainActor in
                        vm.loadPDF(from: url)
                    }
                }
            }
            return true
        }
        .sheet(item: $vm.previewPart) { part in
            QuickPreviewSheet(vm: vm, part: part)
        }
    }
    
    // MARK: - Splitter Panes
    private var splitterLeftPane: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // 1. Document Hero / Drop Zone
                    documentHeroView
                    
                    // 2. Visual Segment Bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Tỉ lệ phân chia sách", systemImage: "chart.bar.xaxis")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if vm.totalPages > 0 {
                                Text("\(vm.calculatedParts.count) phần")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        VisualizerView(parts: vm.calculatedParts, totalPages: vm.totalPages) { selectedPart in
                            vm.previewPart = selectedPart
                        }
                    }
                    .padding(14)
                    .background(Color.platformControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    )
                    
                    // 3. Parts Table & Filenames
                    partsTableView
                }
                .padding(16)
            }
            
            Divider()
            
            // Bottom Status Bar
            bottomStatusBar
        }
        .frame(minWidth: 460, maxWidth: .infinity)
    }
    
    private var splitterRightPane: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Split Mode Config
                    splitModeConfigView
                    
                    // Destination Folder Config
                    destinationConfigView
                    
                    // Live Process & Console Logs
                    liveProcessView
                }
                .padding(16)
            }
            
            Divider()
            
            // Primary Action Button Footer
            sidebarFooterView
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
        .background(Color.platformWindowBackground)
    }
    
    // MARK: - Document Hero / Drop Zone
    private var documentHeroView: some View {
        Group {
            if let thumb = vm.thumbnailImage {
                HStack(spacing: 16) {
                    Image(platformImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 75, height: 95)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(vm.fileName)
                                .font(.system(size: 15, weight: .bold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button("Đổi file") {
                                vm.choosePDFFile()
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 8) {
                            NativeTag(icon: "book.pages", text: "\(vm.totalPages) trang", color: .accentColor)
                            NativeTag(icon: "internaldrive", text: String(format: "%.2f MB", vm.fileSizeMB), color: .secondary)
                        }
                        
                        Text(vm.selectedPDFURL?.path ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(14)
                .background(Color.platformControlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isDropTargeted ? 2 : 1)
                )
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 54, height: 54)
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Kéo & thả file PDF vào đây để tách")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Hoặc chọn sách từ thư viện hoặc máy tính")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        vm.choosePDFFile()
                    } label: {
                        Label("Chọn File PDF (⌘O)", systemImage: "folder.badge.plus")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.platformControlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                )
            }
        }
    }
    
    // MARK: - Parts Table & Filenames
    private var partsTableView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Danh Sách Các Phần Xuất Ra", systemImage: "list.bullet.rectangle.portrait")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if vm.splitMode == .byPages {
                    Button {
                        vm.addCustomRange()
                    } label: {
                        Label("Thêm", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderless)
                }
            }
            
            if vm.calculatedParts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Chưa có phần nào được tạo. Hãy nạp file PDF.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color.platformControlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(vm.calculatedParts.enumerated()), id: \.element.id) { index, part in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(part.color)
                                .frame(width: 10, height: 10)
                            
                            Text("P\(part.partNum)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(width: 24, alignment: .leading)
                            
                            if vm.splitMode == .byPages && index < vm.customRanges.count {
                                HStack(spacing: 4) {
                                    TextField("1", text: Binding(
                                        get: { vm.customRanges[index].startPageText },
                                        set: { vm.updateCustomRangeStart(index: index, val: $0) }
                                    ))
                                    .frame(width: 42)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    TextField("\(vm.totalPages)", text: Binding(
                                        get: { vm.customRanges[index].endPageText },
                                        set: { vm.updateCustomRangeEnd(index: index, val: $0) }
                                    ))
                                    .frame(width: 42)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                }
                                
                                Text("(\(part.pageCount) tr)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 48, alignment: .leading)
                            } else {
                                Text("Trang \(part.startPage) ➔ \(part.endPage)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("(\(part.pageCount) tr)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Quick View Button
                            Button {
                                vm.previewPart = part
                            } label: {
                                Label("Xem P\(part.partNum)", systemImage: "eye")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Xem nhanh trang đầu & cuối của Phần \(part.partNum)")
                            
                            // Filename
                            TextField("Tên file", text: Binding(
                                get: { part.filename },
                                set: { vm.updatePartFilename(index: index, val: $0) }
                            ))
                            .frame(minWidth: 120, maxWidth: 180)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            
                            if vm.splitMode == .byPages && vm.customRanges.count > 1 {
                                Button {
                                    vm.removeCustomRange(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.8))
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.borderless)
                                .help("Xoá phần này")
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.platformControlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.platformTextBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - Split Mode Inspector
    private var splitModeConfigView: some View {
        NativeInspectorSection(title: "Chế Độ Phân Chia", icon: "scissors") {
            VStack(spacing: 12) {
                Picker("Chế độ", selection: $vm.splitMode) {
                    Text("Chia Đều N Phần").tag(SplitMode.byParts)
                    Text("Mốc Trang Tùy Ý").tag(SplitMode.byPages)
                }
                .pickerStyle(.segmented)
                
                if vm.splitMode == .byParts {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Số phần chia đều:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            ForEach([2, 3, 4, 5], id: \.self) { n in
                                Button("\(n) Phần") {
                                    vm.partsCount = n
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(vm.partsCount == n ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(vm.partsCount == n ? .white : .primary)
                                .controlSize(.small)
                            }
                        }
                        
                        HStack {
                            Text("Hoặc tuỳ chỉnh:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Stepper("\(vm.partsCount) phần", value: $vm.partsCount, in: 2...30)
                                .controlSize(.small)
                        }
                        .padding(.top, 2)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button {
                            vm.addCustomRange()
                        } label: {
                            Label("Thêm Phần", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button {
                            vm.autoFillRanges()
                        } label: {
                            Label("Lấp Đầy", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    // MARK: - Destination Inspector
    private var destinationConfigView: some View {
        NativeInspectorSection(title: "Vị Trí Lưu File", icon: "folder") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(vm.outputFolderPath.isEmpty ? "Chưa chọn thư mục" : vm.outputFolderPath)
                        .font(.system(size: 11))
                        .foregroundColor(vm.outputFolderPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button("Chọn...") {
                        vm.chooseOutputFolder()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    
                    Button {
                        vm.createNewFolderPrompt()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .help("Tạo thư mục mới")
                }
                
                Divider()
                
                Toggle("Gom vào thư mục con:", isOn: $vm.createSubfolder)
                    .font(.system(size: 11, weight: .medium))
                
                if vm.createSubfolder {
                    TextField("Tên thư mục con", text: $vm.subfolderName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }
                
                Toggle("Hỏi xác nhận khi tạo thư mục", isOn: $vm.askBeforeCreateDir)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Live Process Inspector
    private var liveProcessView: some View {
        NativeInspectorSection(title: "Tiến Trình & Nhật Ký", icon: "terminal") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(vm.currentStepText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(Int(vm.progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
                
                ProgressView(value: vm.progress, total: 1.0)
                    .progressViewStyle(.linear)
                
                // Console Box
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(vm.logs) { entry in
                                Text(entry.formattedText)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color(red: 0.9, green: 0.92, blue: 0.95))
                                    .id(entry.id)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 80)
                    .background(Color(red: 0.08, green: 0.10, blue: 0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .onChange(of: vm.logs.count) { _ in
                        if let lastID = vm.logs.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    Button("Xoá nhật ký") {
                        vm.clearLogs()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Bottom Status Bar
    private var bottomStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(vm.statusColor)
                .frame(width: 8, height: 8)
            
            Text(vm.statusMessage)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.platformControlBackground)
    }
    
    // MARK: - Sidebar Footer
    private var sidebarFooterView: some View {
        VStack(spacing: 6) {
            Button {
                vm.startExport()
            } label: {
                HStack(spacing: 8) {
                    if vm.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(vm.isProcessing ? "Đang Xuất Sách..." : "Bắt Đầu Xuất Sách (⌘E)")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.green)
            .controlSize(.large)
            .keyboardShortcut("e", modifiers: .command)
            .disabled(vm.isProcessing || vm.calculatedParts.isEmpty)
        }
        .padding(14)
        .background(Color.platformControlBackground)
    }
}

// MARK: - Native Inspector Section Container
struct NativeInspectorSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
            
            content
        }
        .padding(12)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Native Tag View
struct NativeTag: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
