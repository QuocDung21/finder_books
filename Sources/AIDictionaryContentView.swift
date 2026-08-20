import SwiftUI

struct AIDictionaryContentView: View {
    let queryText: String
    var contextSentence: String? = nil
    var bookTitle: String? = nil
    
    @State private var currentQuery: String = ""
    @State private var result: DictionaryLookupResult? = nil
    @State private var isLoading: Bool = true
    @State private var isSaved: Bool = false
    
    @ObservedObject private var notebook = VocabularyNotebookManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Word Header & Pronunciation Card
            headerCard
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Đang phân tích cấu trúc từ điển & nghĩa chuyên sâu...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
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
        .onAppear {
            currentQuery = queryText
            isSaved = notebook.isWordSaved(queryText)
            performLookup(for: queryText)
        }
        .onChange(of: queryText) { newText in
            guard !newText.isEmpty && newText != currentQuery else { return }
            currentQuery = newText
            isSaved = notebook.isWordSaved(newText)
            performLookup(for: newText)
        }
    }
    
    // MARK: - 1. Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(currentQuery)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                // Pronunciation Audio Button
                Button {
                    AIDictionaryService.shared.speak(text: currentQuery)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11))
                        Text("Phát âm")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Bookmark Toggle
                Button {
                    toggleSaveToNotebook()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isSaved ? .orange : .secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help(isSaved ? "Bỏ lưu khỏi Sổ Từ" : "Lưu vào Sổ Từ Vựng")
                
                if let phonetic = result?.phoneticUK, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(5)
                }
            }
            
            if let res = result {
                Text(res.primaryMeaning)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(14)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - 2. Part of Speech Section Card
    private func partOfSpeechSectionCard(section: WordPartOfSpeechSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Part of Speech Badge
            HStack {
                Text(section.partOfSpeech.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(section.definitions.count) định nghĩa")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Definitions List
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(section.definitions.enumerated()), id: \.offset) { index, def in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 5) {
                            Text("\(index + 1).")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                // English Definition
                                Text(def.englishDefinition)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                // Vietnamese Translation
                                Text("👉 \(def.vietnameseTranslation)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        // Example Sentence
                        if let example = def.exampleSentence, !example.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\"\(example)\"")
                                    .font(.system(size: 11, weight: .medium, design: .serif))
                                    .foregroundColor(.secondary)
                                
                                if let exVi = def.exampleTranslation, !exVi.isEmpty {
                                    Text("= \(exVi)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary.opacity(0.85))
                                }
                            }
                            .padding(.leading, 14)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - 3. Context Sentence Card
    private func contextSentenceCard(ctx: String, explanation: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Ngữ Cảnh Trong Cuốn Sách:", systemImage: "text.quote")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)
            
            Text("\"\(ctx)\"")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            
            if let exp = explanation, !exp.isEmpty {
                Text("💡 \(exp)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - 4. Sentence Translation Card
    private func sentenceTranslationCard(res: DictionaryLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Bản Dịch Tiếng Việt:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text(res.primaryMeaning)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.06))
                    .cornerRadius(6)
            }
            
            if !res.keyWordBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Từ vựng then chốt trong câu:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 5) {
                        ForEach(res.keyWordBreakdown) { kw in
                            Button {
                                currentQuery = kw.word
                                performLookup(for: kw.word)
                            } label: {
                                HStack {
                                    Text(kw.word)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.accentColor)
                                    Spacer()
                                    Text(kw.meaning)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.platformTextBackground)
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - 5. Synonyms & Antonyms Card
    private func synonymsCard(synonyms: [String], antonyms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Từ đồng nghĩa (Synonyms):")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 5) {
                        ForEach(synonyms, id: \.self) { syn in
                            Button {
                                currentQuery = syn
                                performLookup(for: syn)
                            } label: {
                                Text(syn)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.platformTextBackground)
                                    .cornerRadius(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            if !antonyms.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Từ trái nghĩa (Antonyms):")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 5) {
                        ForEach(antonyms, id: \.self) { ant in
                            Button {
                                currentQuery = ant
                                performLookup(for: ant)
                            } label: {
                                Text(ant)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.red.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.06))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.platformControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
