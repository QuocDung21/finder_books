import SwiftUI

struct AITranslateLookupSheet: View {
    let queryText: String
    var contextSentence: String? = nil
    var bookTitle: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentQuery: String = ""
    @State private var result: DictionaryLookupResult? = nil
    @State private var isLoading: Bool = true
    @State private var isSaved: Bool = false
    
    @ObservedObject private var notebook = VocabularyNotebookManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 10) {
                Image(systemName: "character.book.closed.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15))
                
                Text("Từ Điển & Dịch Thuật Chuyên Sâu")
                    .font(.system(size: 14, weight: .bold))
                
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
                .controlSize(.small)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.platformControlBackground)
            
            Divider()
            
            // Main Content Area
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Word Header & Pronunciation Card
                    headerCard
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.regular)
                            Text("Đang phân tích cấu trúc từ điển & nghĩa chuyên sâu...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 35)
                    } else if let res = result {
                        // 2. Context Sentence Card (If available)
                        if let ctx = contextSentence, !ctx.isEmpty {
                            contextSentenceCard(ctx: ctx, explanation: res.contextExplanation)
                        }
                        
                        // 3. Detailed Part of Speech & Definitions (Word Mode)
                        if res.isSingleWord && !res.sections.isEmpty {
                            ForEach(res.sections) { section in
                                partOfSpeechSectionCard(section: section)
                            }
                        } else if !res.isSingleWord {
                            // Sentence / Paragraph Translation Mode
                            sentenceTranslationCard(res: res)
                        }
                        
                        // 4. Synonyms & Antonyms
                        if !res.allSynonyms.isEmpty || !res.allAntonyms.isEmpty {
                            synonymsCard(synonyms: res.allSynonyms, antonyms: res.allAntonyms)
                        }
                    }
                }
                .padding(18)
            }
            
            Divider()
            
            // Footer Action Bar
            footerActionBar
        }
        .frame(minWidth: 580, idealWidth: 640, minHeight: 520, idealHeight: 600)
        .onAppear {
            currentQuery = queryText
            isSaved = notebook.isWordSaved(queryText)
            performLookup(for: queryText)
        }
    }
    
    // MARK: - 1. Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(currentQuery)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                // Pronunciation Audio Button
                Button {
                    AIDictionaryService.shared.speak(text: currentQuery)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12))
                        Text("Phát âm")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if let phonetic = result?.phoneticUK, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            if let res = result {
                Text(res.primaryMeaning)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(16)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - 2. Part of Speech Section Card
    private func partOfSpeechSectionCard(section: WordPartOfSpeechSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Part of Speech Badge
            HStack {
                Text(section.partOfSpeech.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor)
                    .cornerRadius(5)
                
                Spacer()
                
                Text("\(section.definitions.count) định nghĩa")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Definitions List
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(section.definitions.enumerated()), id: \.offset) { index, def in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // English Definition
                                Text(def.englishDefinition)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                // Vietnamese Translation
                                Text("👉 \(def.vietnameseTranslation)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        // Example Sentence
                        if let example = def.exampleSentence, !example.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\"\(example)\"")
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundColor(.secondary)
                                
                                if let exVi = def.exampleTranslation, !exVi.isEmpty {
                                    Text("= \(exVi)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary.opacity(0.85))
                                }
                            }
                            .padding(.leading, 18)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - 3. Context Sentence Card
    private func contextSentenceCard(ctx: String, explanation: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ngữ Cảnh Trong Cuốn Sách:", systemImage: "text.quote")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.orange)
            
            Text("\"\(ctx)\"")
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundColor(.primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            
            if let exp = explanation, !exp.isEmpty {
                Text("💡 \(exp)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - 4. Sentence Translation Card
    private func sentenceTranslationCard(res: DictionaryLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bản Dịch Tiếng Việt:")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(res.primaryMeaning)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.06))
                    .cornerRadius(8)
            }
            
            if !res.keyWordBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Từ vựng then chốt trong câu:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        ForEach(res.keyWordBreakdown) { kw in
                            Button {
                                currentQuery = kw.word
                                performLookup(for: kw.word)
                            } label: {
                                HStack {
                                    Text(kw.word)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.accentColor)
                                    Spacer()
                                    Text(kw.meaning)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.platformTextBackground)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - 5. Synonyms & Antonyms Card
    private func synonymsCard(synonyms: [String], antonyms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Từ đồng nghĩa (Synonyms):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(synonyms, id: \.self) { syn in
                            Button {
                                currentQuery = syn
                                performLookup(for: syn)
                            } label: {
                                Text(syn)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.platformTextBackground)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            if !antonyms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Từ trái nghĩa (Antonyms):")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(antonyms, id: \.self) { ant in
                            Button {
                                currentQuery = ant
                                performLookup(for: ant)
                            } label: {
                                Text(ant)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.06))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - 6. Footer Action Bar
    private var footerActionBar: some View {
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
                    NSPasteboard.general.setString("\(currentQuery)\n\(res.primaryMeaning)", forType: .string)
                    #elseif os(iOS)
                    UIPasteboard.general.string = "\(currentQuery)\n\(res.primaryMeaning)"
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
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.platformControlBackground)
    }
    
    private func performLookup(for text: String) {
        isLoading = true
        Task {
            let res = await AIDictionaryService.shared.lookupOrTranslate(text: text, contextSentence: contextSentence)
            self.result = res
            self.isLoading = false
            self.isSaved = notebook.isWordSaved(text)
        }
    }
    
    private func toggleSaveToNotebook() {
        guard let res = result else { return }
        if isSaved {
            if let existing = notebook.items.first(where: { $0.word.caseInsensitiveCompare(currentQuery) == .orderedSame }) {
                notebook.delete(item: existing)
                isSaved = false
            }
        } else {
            notebook.saveWord(
                word: currentQuery,
                phonetic: res.phoneticUK,
                partOfSpeech: res.sections.first?.partOfSpeech,
                meaning: res.primaryMeaning,
                context: contextSentence,
                bookTitle: bookTitle
            )
            isSaved = true
        }
    }
}

// MARK: - Flow Layout for Tags
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

