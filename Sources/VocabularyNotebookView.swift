import SwiftUI

struct VocabularyNotebookView: View {
    @ObservedObject var notebook = VocabularyNotebookManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var selectedItem: VocabularyItem? = nil
    
    var filteredItems: [VocabularyItem] {
        if searchText.isEmpty {
            return notebook.items
        }
        return notebook.items.filter {
            $0.word.localizedCaseInsensitiveContains(searchText) ||
            $0.vietnameseMeaning.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 15))
                    Text("Sổ Tay Từ Vựng (\(notebook.items.count) từ)")
                        .font(.system(size: 15, weight: .bold))
                }
                
                Spacer()
                
                Button("Đóng") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.platformControlBackground)
            
            Divider()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Tìm từ vựng hoặc nghĩa...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.platformTextBackground)
            .cornerRadius(6)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            Divider()
            
            // List of words
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(searchText.isEmpty ? "Chưa có từ vựng nào được lưu." : "Không tìm thấy từ phù hợp.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Khi đọc sách, chọn từ/câu và bấm Tra Cứu AI để lưu vào đây.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List {
                    ForEach(filteredItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(item.word)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        if let pos = item.partOfSpeech {
                                            Text(pos)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.secondary.opacity(0.12))
                                                .cornerRadius(3)
                                        }
                                        
                                        if let phonetic = item.phonetic {
                                            Text(phonetic)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Text(item.vietnameseMeaning)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary.opacity(0.9))
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Button {
                                        AIDictionaryService.shared.speak(text: item.word)
                                    } label: {
                                        Image(systemName: "speaker.wave.2")
                                            .font(.system(size: 12))
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        notebook.delete(item: item)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            if let ctx = item.contextSentence, !ctx.isEmpty {
                                Text("Ngữ cảnh: \"\(ctx)\"")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }
                            
                            HStack {
                                if let book = item.bookTitle {
                                    Text("Từ sách: \(book)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                Spacer()
                                Text(item.formattedDate)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 540, minHeight: 460)
    }
}
