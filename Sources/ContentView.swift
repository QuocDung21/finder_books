import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
    @StateObject private var libraryVM = BookLibraryViewModel()
    @StateObject private var splitterVM = AppViewModel()
    
    @State private var readingBookURL: URL? = nil
    @State private var showSplitterModal: Bool = false
    
    var body: some View {
        Group {
            if let readingURL = readingBookURL {
                // Dedicated Clean Book Reader
                BookReaderView(
                    bookURL: readingURL,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            readingBookURL = nil
                        }
                    },
                    onSplitBook: { url in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            readingBookURL = nil
                            splitterVM.loadPDF(from: url)
                            showSplitterModal = true
                        }
                    }
                )
            } else {
                // Unified Modern NavigationSplitView
                NavigationSplitView {
                    LibrarySidebarView(vm: libraryVM) {
                        showSplitterModal = true
                    }
                } detail: {
                    BookLibraryView(
                        vm: libraryVM,
                        onSelectBookToRead: { bookURL in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                readingBookURL = bookURL
                            }
                        },
                        onSelectBookToSplit: { bookURL in
                            splitterVM.loadPDF(from: bookURL)
                            showSplitterModal = true
                        },
                        onOpenSplitterDirectly: {
                            showSplitterModal = true
                        }
                    )
                }
            }
        }
        .frame(minWidth: 860, minHeight: 600)
        .toolbar {
            if readingBookURL == nil {
                // 1. Search Bar
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        TextField("Tìm sách...", text: $libraryVM.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .frame(width: 140)
                        if !libraryVM.searchText.isEmpty {
                            Button {
                                libraryVM.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                }
                
                // 2. View Mode (Grid / List)
                ToolbarItem(placement: .automatic) {
                    Picker("Xem", selection: $libraryVM.viewMode) {
                        ForEach(LibraryViewMode.allCases) { mode in
                            Image(systemName: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 60)
                }
                
                // 3. Group Mode Menu
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Picker("Gom nhóm theo", selection: $libraryVM.groupMode) {
                            ForEach(LibraryGroupMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Label("Gom nhóm", systemImage: "rectangle.3.group")
                    }
                    .help("Gom nhóm sách theo Thể loại, Thư mục con, hoặc Bộ sách")
                }
                
                // 4. Action Menu (All background tools cleanly organized)
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button {
                            libraryVM.promptScanAndSyncSourceFolder()
                        } label: {
                            Label("Quét & Nhập Sách Từ Downloads...", systemImage: "arrow.triangle.2.circlepath")
                        }
                        
                        Button {
                            libraryVM.classifyAndOrganizeAllBooks()
                        } label: {
                            Label("Tự Động Phân Loại Toàn Bộ", systemImage: "tag")
                        }
                        
                        Button {
                            libraryVM.toggleSmartInboxWatcher()
                        } label: {
                            Label(libraryVM.folderWatcher.isWatching ? "Tắt Giám Sát Hộp Thư" : "Bật Giám Sát Hộp Thư Đến", systemImage: "tray.and.arrow.down")
                        }
                        
                        Button {
                            libraryVM.groupSelectedBooksPrompt()
                        } label: {
                            Label("Gom Vào Thư Mục Mới...", systemImage: "folder.badge.plus")
                        }
                        .disabled(libraryVM.selectedBookIDs.isEmpty)
                        
                        Divider()
                        
                        if let rootDir = libraryVM.libraryRootURL {
                            Button {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: rootDir.path)
                            } label: {
                                Label("Mở Trong Finder", systemImage: "folder")
                            }
                        }
                        
                        Button {
                            libraryVM.refreshLibrary()
                        } label: {
                            Label("Làm Mới Danh Sách", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Label("Thao tác", systemImage: "ellipsis.circle")
                    }
                }
                
                // 5. PDF Splitter Tool shortcut
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        splitterVM.choosePDFFile()
                        if splitterVM.selectedPDFURL != nil {
                            showSplitterModal = true
                        }
                    } label: {
                        Label("Tách Sách", systemImage: "scissors")
                    }
                    .help("Mở công cụ tách & trích xuất sách PDF (⌘T)")
                    .keyboardShortcut("t", modifiers: .command)
                }
            }
        }
        .sheet(isPresented: $showSplitterModal) {
            BookSplitterView(
                vm: splitterVM,
                isEmbeddedInModal: true,
                onDismiss: {
                    showSplitterModal = false
                    libraryVM.refreshLibrary()
                }
            )
            .frame(minWidth: 860, minHeight: 650)
        }
    }
}
