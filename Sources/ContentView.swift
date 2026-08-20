import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
    @StateObject private var libraryVM = BookLibraryViewModel()
    @StateObject private var splitterVM = AppViewModel()
    
    @State private var showSplitterModal: Bool = false
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Sidebar Navigation
            LibrarySidebarView(vm: libraryVM) {
                showSplitterModal = true
            }
        } detail: {
            // MARK: - Main Book Library Workspace (Core Feature)
            BookLibraryView(
                vm: libraryVM,
                onSelectBookToSplit: { bookURL in
                    splitterVM.loadPDF(from: bookURL)
                    showSplitterModal = true
                },
                onOpenSplitterDirectly: {
                    showSplitterModal = true
                }
            )
        }
        .frame(minWidth: 920, minHeight: 650)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 15))
                    Text("Finder Books")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    libraryVM.promptScanAndSyncSourceFolder()
                } label: {
                    Label("Quét Downloads", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("Quét sách từ thư mục Downloads để đồng bộ vào kho sách")
                
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
                
                if let rootDir = libraryVM.libraryRootURL {
                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: rootDir.path)
                    } label: {
                        Label("Mở Thư Mục", systemImage: "folder")
                    }
                    .help("Mở thư mục kho sách trong Finder (⇧⌘O)")
                    .keyboardShortcut("o", modifiers: [.command, .shift])
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
