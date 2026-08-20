import Foundation

// MARK: - Vocabulary Item Model
struct VocabularyItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var word: String
    var phonetic: String?
    var partOfSpeech: String?
    var vietnameseMeaning: String
    var contextSentence: String?
    var bookTitle: String?
    var dateAdded: Date = Date()
    var isMastered: Bool = false
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: dateAdded)
    }
}

// MARK: - Vocabulary Manager (UserDefaults Persistence)
@MainActor
class VocabularyNotebookManager: ObservableObject {
    static let shared = VocabularyNotebookManager()
    
    @Published var items: [VocabularyItem] = [] {
        didSet {
            save()
        }
    }
    
    private let storageKey = "FinderBooks_VocabularyNotebook_v1"
    
    init() {
        load()
    }
    
    func saveWord(word: String, phonetic: String?, partOfSpeech: String?, meaning: String, context: String?, bookTitle: String?) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else { return }
        
        if let index = items.firstIndex(where: { $0.word.caseInsensitiveCompare(cleanWord) == .orderedSame }) {
            items[index].vietnameseMeaning = meaning
            items[index].phonetic = phonetic ?? items[index].phonetic
            items[index].contextSentence = context ?? items[index].contextSentence
            items[index].dateAdded = Date()
        } else {
            let newItem = VocabularyItem(
                word: cleanWord,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                vietnameseMeaning: meaning,
                contextSentence: context,
                bookTitle: bookTitle
            )
            items.insert(newItem, at: 0)
        }
    }
    
    func delete(item: VocabularyItem) {
        items.removeAll { $0.id == item.id }
    }
    
    func isWordSaved(_ word: String) -> Bool {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.contains(where: { $0.word.caseInsensitiveCompare(clean) == .orderedSame })
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([VocabularyItem].self, from: data) {
            self.items = list
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
