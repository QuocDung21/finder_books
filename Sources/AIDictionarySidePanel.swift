import SwiftUI

struct AIDictionarySidePanel: View {
    @Binding var queryText: String
    var contextSentence: String? = nil
    var bookTitle: String? = nil
    var onUnpinToModal: () -> Void
    var onClose: () -> Void
    
    @State private var searchInput: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 13))
                    
                    Text("Tra Cứu & Dịch AI")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                // Unpin / Open Modal Button
                Button {
                    onUnpinToModal()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Mở dạng cửa sổ nổi")
                
                // Close Panel Button
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Đóng cột tra cứu (Esc)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.platformControlBackground)
            
            Divider()
            
            // Search / Input bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                TextField("Nhập từ hoặc bôi đen chữ trong sách...", text: $searchInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        let clean = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty {
                            queryText = clean
                        }
                    }
                
                if !searchInput.isEmpty {
                    Button {
                        searchInput = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.platformTextBackground)
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Content
            ScrollView(.vertical, showsIndicators: true) {
                if queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("Bôi đen bất kỳ từ hoặc câu nào trong sách để tra cứu tự động.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                } else {
                    AIDictionaryContentView(
                        queryText: queryText,
                        contextSentence: contextSentence,
                        bookTitle: bookTitle
                    )
                    .padding(12)
                }
            }
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 450)
        .background(Color.platformWindowBackground)
        .onChange(of: queryText) { newQuery in
            if !newQuery.isEmpty && newQuery != searchInput {
                searchInput = newQuery
            }
        }
    }
}
