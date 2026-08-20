import Foundation
import AVFoundation
import NaturalLanguage

// MARK: - Rich Dictionary Definition Models
struct WordDefinitionItem: Identifiable, Codable {
    var id: UUID = UUID()
    var englishDefinition: String
    var vietnameseTranslation: String
    var exampleSentence: String?
    var exampleTranslation: String?
    var synonyms: [String] = []
    var antonyms: [String] = []
}

struct WordPartOfSpeechSection: Identifiable, Codable {
    var id: UUID = UUID()
    var partOfSpeech: String // Tính từ / Adjective, Danh từ / Noun...
    var definitions: [WordDefinitionItem]
}

struct KeyWordBreakdown: Identifiable, Codable {
    var id: UUID = UUID()
    var word: String
    var partOfSpeech: String?
    var meaning: String
}

// MARK: - Dictionary Lookup Result Model
struct DictionaryLookupResult {
    var queryText: String
    var isSingleWord: Bool
    var phoneticUK: String?
    var phoneticUS: String?
    var primaryMeaning: String
    var contextExplanation: String?
    var wordFamily: [String] = []
    var sections: [WordPartOfSpeechSection] = []
    var keyWordBreakdown: [KeyWordBreakdown] = []
    var allSynonyms: [String] = []
    var allAntonyms: [String] = []
    var detectedLanguage: String = "Tiếng Anh"
    var providerUsed: String = "Từ Điển Chuyên Sâu"
}

// MARK: - AI Dictionary & Translation Service
class AIDictionaryService {
    static let shared = AIDictionaryService()
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // MARK: - Speak Text (Text-to-Speech)
    func speak(text: String, languageCode: String = "en-US") {
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Main Lookup & Translation Method
    func lookupOrTranslate(text: String, contextSentence: String? = nil) async -> DictionaryLookupResult {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleanText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let isSingleWord = words.count <= 3
        
        let settings = await AISettingsManager.shared.config
        
        // If LLM provider is configured, query LLM for deepest contextual analysis
        switch settings.selectedProvider {
        case .openAI:
            if let result = await lookupViaOpenAI(text: cleanText, context: contextSentence, config: settings, isSingleWord: isSingleWord) {
                return result
            }
        case .gemini:
            if let result = await lookupViaGemini(text: cleanText, context: contextSentence, config: settings, isSingleWord: isSingleWord) {
                return result
            }
        case .ollama:
            if let result = await lookupViaOllama(text: cleanText, context: contextSentence, config: settings, isSingleWord: isSingleWord) {
                return result
            }
        case .customOpenAI:
            if let result = await lookupViaCustomOpenAI(text: cleanText, context: contextSentence, config: settings, isSingleWord: isSingleWord) {
                return result
            }
        case .appleNative:
            break
        }
        
        // Deep Dictionary API + Free Translation Engine
        return await lookupViaDeepDictionaryEngine(text: cleanText, context: contextSentence, isSingleWord: isSingleWord)
    }
    
    // MARK: - Deep Dictionary & Context Translation Engine
    private func lookupViaDeepDictionaryEngine(text: String, context: String?, isSingleWord: Bool) async -> DictionaryLookupResult {
        if isSingleWord {
            let singleWordClean = text.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
            
            // Try fetching from Official Dictionary API (Oxford/Webster dataset)
            if let dictData = await fetchFreeDictionaryAPI(word: singleWordClean) {
                return dictData
            }
        }
        
        // Sentence / Paragraph Translation Mode
        let translation = await fetchFreeTranslation(for: text)
        
        // Break down individual words for sentences
        var breakdowns: [KeyWordBreakdown] = []
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
            .prefix(5)
        
        for w in words {
            let trans = await fetchFreeTranslation(for: w)
            if trans.lowercased() != w.lowercased() {
                breakdowns.append(KeyWordBreakdown(word: w, partOfSpeech: nil, meaning: trans))
            }
        }
        
        return DictionaryLookupResult(
            queryText: text,
            isSingleWord: false,
            phoneticUK: nil,
            phoneticUS: nil,
            primaryMeaning: translation,
            contextExplanation: context != nil ? "Ngữ cảnh trích đoạn từ sách: \"\(context!)\"" : nil,
            wordFamily: [],
            sections: [],
            keyWordBreakdown: breakdowns,
            allSynonyms: [],
            allAntonyms: [],
            detectedLanguage: "Tiếng Anh",
            providerUsed: "Dịch Thuật Chuyên Sâu"
        )
    }
    
    // MARK: - Fetch from Free Dictionary API with Auto-Vietnamese Translation
    private func fetchFreeDictionaryAPI(word: String) async -> DictionaryLookupResult? {
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            
            struct RawDictionaryEntry: Codable {
                struct RawPhonetic: Codable {
                    let text: String?
                }
                struct RawMeaning: Codable {
                    let partOfSpeech: String?
                    struct RawDef: Codable {
                        let definition: String?
                        let example: String?
                        let synonyms: [String]?
                        let antonyms: [String]?
                    }
                    let definitions: [RawDef]?
                    let synonyms: [String]?
                    let antonyms: [String]?
                }
                let word: String?
                let phonetic: String?
                let phonetics: [RawPhonetic]?
                let meanings: [RawMeaning]?
            }
            
            guard let entries = try? JSONDecoder().decode([RawDictionaryEntry].self, from: data),
                  let firstEntry = entries.first else {
                return nil
            }
            
            var ipa = firstEntry.phonetic
            if ipa == nil, let rawPhonetics = firstEntry.phonetics {
                ipa = rawPhonetics.compactMap { $0.text }.first(where: { !$0.isEmpty })
            }
            
            // Primary meaning in Vietnamese
            let vietnamesePrimary = await fetchFreeTranslation(for: word)
            
            var sections: [WordPartOfSpeechSection] = []
            var allSyns: [String] = []
            var allAnts: [String] = []
            
            if let meanings = firstEntry.meanings {
                for m in meanings.prefix(3) {
                    let posName = vietnamesePartOfSpeech(for: m.partOfSpeech ?? "noun")
                    var defItems: [WordDefinitionItem] = []
                    
                    if let defs = m.definitions {
                        for d in defs.prefix(3) {
                            let enDef = d.definition ?? ""
                            guard !enDef.isEmpty else { continue }
                            
                            let viDef = await fetchFreeTranslation(for: enDef)
                            var viEx: String? = nil
                            if let ex = d.example, !ex.isEmpty {
                                viEx = await fetchFreeTranslation(for: ex)
                            }
                            
                            defItems.append(WordDefinitionItem(
                                englishDefinition: enDef,
                                vietnameseTranslation: viDef,
                                exampleSentence: d.example,
                                exampleTranslation: viEx,
                                synonyms: d.synonyms ?? [],
                                antonyms: d.antonyms ?? []
                            ))
                        }
                    }
                    
                    if let syns = m.synonyms { allSyns.append(contentsOf: syns) }
                    if let ants = m.antonyms { allAnts.append(contentsOf: ants) }
                    
                    if !defItems.isEmpty {
                        sections.append(WordPartOfSpeechSection(partOfSpeech: posName, definitions: defItems))
                    }
                }
            }
            
            allSyns = Array(Set(allSyns)).filter { $0.count > 1 }.prefix(8).map { $0 }
            allAnts = Array(Set(allAnts)).filter { $0.count > 1 }.prefix(6).map { $0 }
            
            return DictionaryLookupResult(
                queryText: word,
                isSingleWord: true,
                phoneticUK: ipa,
                phoneticUS: ipa,
                primaryMeaning: vietnamesePrimary,
                contextExplanation: nil,
                wordFamily: [],
                sections: sections,
                keyWordBreakdown: [],
                allSynonyms: allSyns,
                allAntonyms: allAnts,
                detectedLanguage: "Tiếng Anh",
                providerUsed: "Từ Điển Chuẩn Quốc Tế & AI"
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - OpenAI Lookup
    private func lookupViaOpenAI(text: String, context: String?, config: AISettingsConfig, isSingleWord: Bool) async -> DictionaryLookupResult? {
        guard !config.openAIKey.isEmpty, let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }
        
        let prompt = makePrompt(text: text, context: context, isSingleWord: isSingleWord)
        let body: [String: Any] = [
            "model": config.openAIModel,
            "messages": [
                ["role": "system", "content": "Bạn là chuyên gia từ điển Oxford và dịch thuật sách tiếng Anh/Việt. Trả về JSON theo đúng cấu trúc yêu cầu."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.2
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.openAIKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = jsonData
        req.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parseLLMJSONResponse(data: data, queryText: text, isSingleWord: isSingleWord, provider: "OpenAI (\(config.openAIModel))")
        } catch {
            return nil
        }
    }
    
    // MARK: - Gemini Lookup
    private func lookupViaGemini(text: String, context: String?, config: AISettingsConfig, isSingleWord: Bool) async -> DictionaryLookupResult? {
        guard !config.geminiKey.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(config.geminiModel):generateContent?key=\(config.geminiKey)") else { return nil }
        
        let prompt = makePrompt(text: text, context: context, isSingleWord: isSingleWord) + "\nTrả lời bằng JSON thuần tuý."
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData
        req.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parseGeminiResponse(data: data, queryText: text, isSingleWord: isSingleWord, provider: "Gemini (\(config.geminiModel))")
        } catch {
            return nil
        }
    }
    
    // MARK: - Ollama Lookup
    private func lookupViaOllama(text: String, context: String?, config: AISettingsConfig, isSingleWord: Bool) async -> DictionaryLookupResult? {
        guard let url = URL(string: "\(config.ollamaEndpoint)/api/generate") else { return nil }
        
        let prompt = makePrompt(text: text, context: context, isSingleWord: isSingleWord) + "\nOutput JSON strictly."
        let body: [String: Any] = [
            "model": config.ollamaModel,
            "prompt": prompt,
            "stream": false,
            "format": "json"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonData
        req.timeoutInterval = 12
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            
            struct OllamaResponse: Codable {
                let response: String?
            }
            if let decoded = try? JSONDecoder().decode(OllamaResponse.self, from: data),
               let jsonStr = decoded.response,
               let innerData = jsonStr.data(using: .utf8) {
                return parseDirectJSON(data: innerData, queryText: text, isSingleWord: isSingleWord, provider: "Ollama (\(config.ollamaModel))")
            }
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: - Custom OpenAI Lookup
    private func lookupViaCustomOpenAI(text: String, context: String?, config: AISettingsConfig, isSingleWord: Bool) async -> DictionaryLookupResult? {
        guard let url = URL(string: "\(config.customEndpoint)/chat/completions") else { return nil }
        
        let prompt = makePrompt(text: text, context: context, isSingleWord: isSingleWord)
        let body: [String: Any] = [
            "model": config.customModel,
            "messages": [
                ["role": "system", "content": "Bạn là chuyên gia từ điển Oxford và dịch thuật sách tiếng Anh/Việt. Trả về JSON theo đúng cấu trúc yêu cầu."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.2
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.customKey.isEmpty {
            req.setValue("Bearer \(config.customKey)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = jsonData
        req.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return parseLLMJSONResponse(data: data, queryText: text, isSingleWord: isSingleWord, provider: "Custom AI (\(config.customModel))")
        } catch {
            return nil
        }
    }
    
    // MARK: - Prompt Builder
    private func makePrompt(text: String, context: String?, isSingleWord: Bool) -> String {
        if isSingleWord {
            return """
            Phân tích chuyên sâu từ/cụm từ: "\(text)"
            Ngữ cảnh trích đoạn câu trong sách: "\(context ?? "")"
            
            Trả về JSON chuẩn xác theo mẫu:
            {
              "phoneticUK": "/phiên âm IPA/",
              "primaryMeaning": "Nghĩa tiếng Việt ngắn gọn & phổ biến nhất",
              "contextExplanation": "Giải thích nghĩa của từ trong câu ngữ cảnh trên",
              "sections": [
                {
                  "partOfSpeech": "Tính từ (Adjective)",
                  "definitions": [
                    {
                      "englishDefinition": "Definition in English",
                      "vietnameseTranslation": "Dịch nghĩa tiếng Việt đầy đủ",
                      "exampleSentence": "Example sentence in English",
                      "exampleTranslation": "Dịch ví dụ sang tiếng Việt",
                      "synonyms": ["synonym1", "synonym2"]
                    }
                  ]
                }
              ],
              "allSynonyms": ["syn1", "syn2", "syn3"],
              "allAntonyms": ["ant1", "ant2"],
              "wordFamily": ["word1 (noun)", "word2 (verb)"]
            }
            """
        } else {
            return """
            Dịch thuật & phân tích câu sau từ sách:
            "\(text)"
            
            Trả về JSON:
            {
              "primaryMeaning": "Bản dịch tiếng Việt trau chuốt, tự nhiên, chuẩn ngữ cảnh",
              "contextExplanation": "Giải thích ngữ pháp, hàm ý hoặc thuật ngữ chuyên ngành",
              "keyWordBreakdown": [
                {
                  "word": "keyword",
                  "partOfSpeech": "noun",
                  "meaning": "nghĩa tiếng Việt"
                }
              ]
            }
            """
        }
    }
    
    // MARK: - JSON Response Parsers
    private func parseLLMJSONResponse(data: Data, queryText: String, isSingleWord: Bool, provider: String) -> DictionaryLookupResult? {
        struct ChatCompletionResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]?
        }
        
        guard let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
              let content = decoded.choices?.first?.message.content,
              let innerData = content.data(using: .utf8) else {
            return nil
        }
        return parseDirectJSON(data: innerData, queryText: queryText, isSingleWord: isSingleWord, provider: provider)
    }
    
    private func parseGeminiResponse(data: Data, queryText: String, isSingleWord: Bool, provider: String) -> DictionaryLookupResult? {
        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String
                    }
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }
        
        guard let decoded = try? JSONDecoder().decode(GeminiResponse.self, from: data),
              let text = decoded.candidates?.first?.content?.parts?.first?.text else {
            return nil
        }
        
        var cleanJSON = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "^```[a-z]*\\n", with: "", options: .regularExpression)
            cleanJSON = cleanJSON.replacingOccurrences(of: "\\n```$", with: "", options: .regularExpression)
        }
        guard let innerData = cleanJSON.data(using: .utf8) else { return nil }
        return parseDirectJSON(data: innerData, queryText: queryText, isSingleWord: isSingleWord, provider: provider)
    }
    
    private func parseDirectJSON(data: Data, queryText: String, isSingleWord: Bool, provider: String) -> DictionaryLookupResult? {
        struct RawLLMDict: Codable {
            let phoneticUK: String?
            let primaryMeaning: String?
            let contextExplanation: String?
            let wordFamily: [String]?
            let allSynonyms: [String]?
            let allAntonyms: [String]?
            let sections: [WordPartOfSpeechSection]?
            let keyWordBreakdown: [KeyWordBreakdown]?
        }
        
        guard let d = try? JSONDecoder().decode(RawLLMDict.self, from: data),
              let meaning = d.primaryMeaning, !meaning.isEmpty else {
            return nil
        }
        
        return DictionaryLookupResult(
            queryText: queryText,
            isSingleWord: isSingleWord,
            phoneticUK: d.phoneticUK,
            phoneticUS: d.phoneticUK,
            primaryMeaning: meaning,
            contextExplanation: d.contextExplanation,
            wordFamily: d.wordFamily ?? [],
            sections: d.sections ?? [],
            keyWordBreakdown: d.keyWordBreakdown ?? [],
            allSynonyms: d.allSynonyms ?? [],
            allAntonyms: d.allAntonyms ?? [],
            detectedLanguage: "Tiếng Anh",
            providerUsed: provider
        )
    }
    
    // MARK: - Free Google Translate Endpoint Helper
    private func fetchFreeTranslation(for text: String) async -> String {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=vi&dt=t&q=\(encoded)") else {
            return text
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
               let sentences = json.first as? [Any] {
                var translatedText = ""
                for s in sentences {
                    if let sArr = s as? [Any], let piece = sArr.first as? String {
                        translatedText += piece
                    }
                }
                if !translatedText.isEmpty {
                    return translatedText
                }
            }
        } catch {}
        return text
    }
    
    private func vietnamesePartOfSpeech(for tag: String) -> String {
        switch tag.lowercased() {
        case "noun": return "Danh từ (Noun)"
        case "verb": return "Động từ (Verb)"
        case "adjective", "adj": return "Tính từ (Adjective)"
        case "adverb", "adv": return "Trạng từ (Adverb)"
        case "pronoun": return "Đại từ (Pronoun)"
        case "preposition": return "Giới từ (Preposition)"
        case "conjunction": return "Liên từ (Conjunction)"
        case "interjection": return "Thán từ (Interjection)"
        default: return tag.capitalized
        }
    }
}
