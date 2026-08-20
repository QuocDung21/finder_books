import SwiftUI

struct AITranslateLookupSheet: View {
    let queryText: String
    var contextSentence: String? = nil
    var bookTitle: String? = nil
    var onPinToSidebar: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 10) {
                Image(systemName: "character.book.closed.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15))
                
                Text("Từ Điển & Dịch Thuật Chuyên Sâu")
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                if let onPin = onPinToSidebar {
                    Button {
                        onPin()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                            Text("Ghim Cột Bên")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Ghim thành cột tra cứu bên cạnh sách")
                }
                
                Button("Đóng") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.small)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.platformControlBackground)
            
            Divider()
            
            // Main Content Area
            ScrollView(.vertical, showsIndicators: true) {
                AIDictionaryContentView(
                    queryText: queryText,
                    contextSentence: contextSentence,
                    bookTitle: bookTitle
                )
                .padding(18)
            }
            
            Divider()
            
            // Footer Action Bar
            HStack {
                Button("Sao Chép") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(queryText, forType: .string)
                    #elseif os(iOS)
                    UIPasteboard.general.string = queryText
                    #endif
                }
                .controlSize(.regular)
                
                Spacer()
                
                Button("Hoàn Tất") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.platformControlBackground)
        }
        #if os(macOS)
        .frame(minWidth: 580, idealWidth: 640, minHeight: 520, idealHeight: 600)
        #endif
    }
}
