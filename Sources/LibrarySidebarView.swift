import SwiftUI

struct LibrarySidebarView: View {
    @ObservedObject var vm: BookLibraryViewModel
    var onOpenSplitter: () -> Void
    var onOpenSettings: () -> Void
    
    @ObservedObject private var syncManager = LiveCompanionSyncManager.shared
    @State private var showWiFiSyncSheet: Bool = false
    
    var body: some View {
        List(selection: $vm.selectedSidebarItem) {
            // MARK: - Section 1: Thư Viện
            Section("Thư Viện") {
                NavigationLink(value: LibrarySidebarItem.allBooks) {
                    Label {
                        HStack {
                            Text("Tất Cả Sách")
                            Spacer()
                            Text("\(vm.books.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "books.vertical.fill")
                            .foregroundColor(.accentColor)
                    }
                }
                
                NavigationLink(value: LibrarySidebarItem.smartInbox) {
                    Label {
                        HStack {
                            Text("Hộp Thư Tự Động")
                            Spacer()
                            Circle()
                                .fill(vm.folderWatcher.isWatching ? Color.green : Color.secondary.opacity(0.4))
                                .frame(width: 7, height: 7)
                        }
                    } icon: {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                NavigationLink(value: LibrarySidebarItem.splitParts) {
                    Label {
                        HStack {
                            Text("Sách Đã Tách")
                            Spacer()
                            let splitCount = vm.books.filter { $0.baseName.range(of: "_part\\d+", options: .regularExpression) != nil }.count
                            if splitCount > 0 {
                                Text("\(splitCount)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "scissors.badge.ellipsis")
                            .foregroundColor(.purple)
                    }
                }
            }
            
            // MARK: - Section 2: Đồng Bộ Wi-Fi (Mac ↔ iPad)
            Section("Kết Nối Thiết Bị") {
                Button {
                    showWiFiSyncSheet = true
                } label: {
                    Label {
                        HStack {
                            Text("Đồng Bộ Wi-Fi (Mac/iPad)")
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            Spacer()
                            let isConn = syncManager.isDirectTCPConnected || !syncManager.connectedPeers.isEmpty
                            Circle()
                                .fill(isConn ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                        }
                    } icon: {
                        Image(systemName: "wifi")
                            .foregroundColor(syncManager.isDirectTCPConnected || !syncManager.connectedPeers.isEmpty ? .green : .accentColor)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // MARK: - Section 3: Thể Loại
            Section("Thể Loại") {
                ForEach(BookCategory.allCases.filter { $0 != .general }) { cat in
                    NavigationLink(value: LibrarySidebarItem.category(cat)) {
                        Label {
                            HStack {
                                Text(cat.rawValue)
                                    .font(.system(size: 12))
                                Spacer()
                                let count = countForCategory(cat)
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: cat.icon)
                                .foregroundColor(colorForCategory(cat))
                        }
                    }
                }
            }
            
            // MARK: - Section 4: Công Cụ
            Section("Công Cụ") {
                Button {
                    onOpenSplitter()
                } label: {
                    Label("Tách & Xuất Sách...", systemImage: "scissors")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Button {
                    vm.promptScanAndSyncSourceFolder()
                } label: {
                    Label("Quét & Đồng Bộ...", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Button {
                    onOpenSettings()
                } label: {
                    Label("Cài Đặt Model AI...", systemImage: "cpu")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        #if os(macOS)
        .frame(minWidth: 210, idealWidth: 230, maxWidth: 280)
        #endif
        .sheet(isPresented: $showWiFiSyncSheet) {
            WiFiSyncControlSheet()
        }
    }
    
    private func countForCategory(_ cat: BookCategory) -> Int {
        vm.books.filter { book in
            let folder = book.folderName
            if folder == cat.rawValue || folder == cat.folderName || folder.contains(cat.rawValue) {
                return true
            }
            return false
        }.count
    }
    
    private func colorForCategory(_ cat: BookCategory) -> Color {
        switch cat {
        case .technology: return .blue
        case .business: return .green
        case .literature: return .pink
        case .selfHelp: return .orange
        case .scienceHistory: return .purple
        case .languageEducation: return .indigo
        case .artDesign: return .teal
        case .comicsManga: return .red
        case .general: return .secondary
        }
    }
}
