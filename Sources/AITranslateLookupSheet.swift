import SwiftUI

struct AITranslateLookupSheet: View {
    let queryText: String
    var contextSentence: String? = nil
    var bookTitle: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var result: DictionaryLookupResult? = nil
    @State private var isLoading: Bool = true
    @State private var isSaved: Bool = false
    
    @ObservedObject private var notebook = VocabularyNotebookManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 15))
                    
                    Text("Tra Cứu & Dịch Thuật AI")
                        .font(.system(size: 15, weight: .bold))
                }
                
                if let res = result {
                    Text("• \(res.providerUsed)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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
            
            // Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Query Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text(queryText)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button {
                                AIDictionaryService.shared.speak(text: queryText)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)
                                    .padding(6)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Phát âm từ/câu (Text to Speech)")
                        }
                        
                        if let phonetic = result?.phonetic, !phonetic.isEmpty {
                            Text(phonetic)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.platformControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    // Result Box
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.regular)
                            Text("AI đang tra từ điển & phân tích ngữ cảnh...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else if let res = result {
                        VStack(alignment: .leading, spacing: 14) {
                            // Part of Speech & Meaning
                            VStack(alignment: .leading, spacing: 6) {
                                if let pos = res.partOfSpeech, !pos.isEmpty {
                                    Text(pos.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor)
                                        .cornerRadius(4)
                                }
                                
                                Text(res.primaryMeaning)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            // Contextual Meaning (If available)
                            if let ctxMeaning = res.contextualMeaning, !ctxMeaning.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Nghĩa Theo Ngữ Cảnh Sách:", systemImage: "text.quote")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    Text(ctxMeaning)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                        .padding(10)
                                        .background(Color.accentColor.opacity(0.06))
                                        .cornerRadius(6)
                                }
                            }
                            
                            // Synonyms
                            if !res.synonyms.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Từ đồng nghĩa:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    FlowLayout(spacing: 6) {
                                        ForEach(res.synonyms, id: \.self) { syn in
                                            Text(syn)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.platformControlBackground)
                                                .cornerRadius(4)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                                )
                                        }
                                    }
                                }
                            }
                            
                            // Examples
                            if !res.examples.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Ví dụ minh hoạ:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(res.examples, id: \.self) { ex in
                                            Text("• \(ex)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.platformControlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button {
                    toggleSaveToNotebook()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isSaved ? .orange : .primary)
                        Text(isSaved ? "Đã Lưu Sổ Từ" : "Lưu Vào Sổ Từ Vựng")
                    }
                }
                .controlSize(.regular)
                .disabled(isLoading || result == nil)
                
                Spacer()
                
                Button("Sao Chép") {
                    if let res = result {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(queryText)\n\(res.primaryMeaning)", forType: .string)
                        #elseif os(iOS)
                        UIPasteboard.general.string = "\(queryText)\n\(res.primaryMeaning)"
                        #endif
                    }
                }
                .controlSize(.regular)
                
                Button("Hoàn Tất") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.platformControlBackground)
        }
        .frame(minWidth: 540, idealWidth: 580, minHeight: 460)
        .onAppear {
            isSaved = notebook.isWordSaved(queryText)
            performLookup()
        }
    }
    
    private func performLookup() {
        isLoading = true
        Task {
            let res = await AIDictionaryService.shared.lookupOrTranslate(text: queryText, contextSentence: contextSentence)
            self.result = res
            self.isLoading = false
        }
    }
    
    private func toggleSaveToNotebook() {
        guard let res = result else { return }
        if isSaved {
            if let existing = notebook.items.first(where: { $0.word.caseInsensitiveCompare(queryText) == .orderedSame }) {
                notebook.delete(item: existing)
                isSaved = false
            }
        } else {
            notebook.saveWord(
                word: queryText,
                phonetic: res.phonetic,
                partOfSpeech: res.partOfSpeech,
                meaning: res.primaryMeaning,
                context: contextSentence,
                bookTitle: bookTitle
            )
            isSaved = true
        }
    }
}

// MARK: - Simple Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
