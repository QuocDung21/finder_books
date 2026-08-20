import Foundation
import AVFoundation
import NaturalLanguage

// MARK: - Dictionary Lookup Result Model
struct DictionaryLookupResult {
    var queryText: String
    var isSingleWord: Bool
    var phonetic: String?
    var partOfSpeech: String?
    var primaryMeaning: String
    var contextualMeaning: String?
    var detailedDefinitions: [String] = []
    var examples: [String] = []
    var synonyms: [String] = []
    var detectedLanguage: String = "Tiếng Anh"
    var providerUsed: String = "Apple Native"
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
        
        // Fallback to Apple Native Engine & Smart Free Translation
        return await lookupViaAppleNativeAndFreeEngine(text: cleanText, context: contextSentence, isSingleWord: isSingleWord)
    }
    
    // MARK: - Apple Native & Free Fallback Engine
    private func lookupViaAppleNativeAndFreeEngine(text: String, context: String?, isSingleWord: Bool) async -> DictionaryLookupResult {
        // Free Google Translate API endpoint for fast fallback
        let translated = await fetchFreeTranslation(for: text)
        
        var partOfSpeech: String? = nil
        if isSingleWord {
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = text
            if let tag = tagger.tag(at: text.startIndex, unit: .word, scheme: .lexicalClass).0 {
                partOfSpeech = vietnamesePartOfSpeech(for: tag.rawValue)
            }
        }
        
        return DictionaryLookupResult(
            queryText: text,
            isSingleWord: isSingleWord,
            phonetic: isSingleWord ? nil : nil,
            partOfSpeech: partOfSpeech,
            primaryMeaning: translated,
            contextualMeaning: context != nil ? "Nghĩa trong ngữ cảnh: \(translated)" : nil,
            detailedDefinitions: [translated],
            examples: [],
            synonyms: [],
            detectedLanguage: "Tiếng Anh",
            providerUsed: "Apple Native Engine"
        )
    }
    
    // MARK: - OpenAI Lookup
    private func lookupViaOpenAI(text: String, context: String?, config: AISettingsConfig, isSingleWord: Bool) async -> DictionaryLookupResult? {
        guard !config.openAIKey.isEmpty, let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }
        
        let prompt = makePrompt(text: text, context: context, isSingleWord: isSingleWord)
        let body: [String: Any] = [
            "model": config.openAIModel,
            "messages": [
                ["role": "system", "content": "Bạn là chuyên gia từ điển và dịch thuật sách tiếng Anh/Việt. Hãy trả về kết quả định dạng JSON chính xác."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
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
                ["role": "system", "content": "Bạn là chuyên gia từ điển và dịch thuật sách tiếng Anh/Việt. Hãy trả về kết quả định dạng JSON chính xác."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
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
            var p = """
            Phân tích từ/cụm từ: "\(text)"
            """
            if let ctx = context, !ctx.isEmpty {
                p += "\nTrong câu ngữ cảnh: \"\(ctx)\""
            }
            p += """
            \nTrả về định dạng JSON:
            {
              "phonetic": "/phiên âm IPA/",
              "partOfSpeech": "Danh từ / Động từ / Tính từ / Cụm từ",
              "primaryMeaning": "Nghĩa tiếng Việt chuẩn nhất",
              "contextualMeaning": "Giải thích nghĩa phù hợp với ngữ cảnh câu",
              "detailedDefinitions": ["Nghĩa 1", "Nghĩa 2"],
              "examples": ["Ví dụ tiếng Anh - Dịch tiếng Việt"],
              "synonyms": ["từ đồng nghĩa 1", "từ đồng nghĩa 2"]
            }
            """
            return p
        } else {
            return """
            Dịch và giải thích đoạn văn bản sau từ sách:
            "\(text)"
            
            Trả về định dạng JSON:
            {
              "primaryMeaning": "Bản dịch tiếng Việt văn phong trau chuốt, tự nhiên",
              "contextualMeaning": "Giải thích ngắn gọn ý nghĩa cốt lõi hoặc thuật ngữ chuyên ngành",
              "detailedDefinitions": [],
              "examples": [],
              "synonyms": []
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
        
        // Clean markdown code blocks ```json ... ```
        var cleanJSON = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "^```[a-z]*\\n", with: "", options: .regularExpression)
            cleanJSON = cleanJSON.replacingOccurrences(of: "\\n```$", with: "", options: .regularExpression)
        }
        guard let innerData = cleanJSON.data(using: .utf8) else { return nil }
        return parseDirectJSON(data: innerData, queryText: queryText, isSingleWord: isSingleWord, provider: provider)
    }
    
    private func parseDirectJSON(data: Data, queryText: String, isSingleWord: Bool, provider: String) -> DictionaryLookupResult? {
        struct DictJSON: Codable {
            let phonetic: String?
            let partOfSpeech: String?
            let primaryMeaning: String?
            let contextualMeaning: String?
            let detailedDefinitions: [String]?
            let examples: [String]?
            let synonyms: [String]?
        }
        
        guard let d = try? JSONDecoder().decode(DictJSON.self, from: data),
              let meaning = d.primaryMeaning, !meaning.isEmpty else {
            return nil
        }
        
        return DictionaryLookupResult(
            queryText: queryText,
            isSingleWord: isSingleWord,
            phonetic: d.phonetic,
            partOfSpeech: d.partOfSpeech,
            primaryMeaning: meaning,
            contextualMeaning: d.contextualMeaning,
            detailedDefinitions: d.detailedDefinitions ?? [],
            examples: d.examples ?? [],
            synonyms: d.synonyms ?? [],
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
        case "noun": return "Danh từ"
        case "verb": return "Động từ"
        case "adjective": return "Tính từ"
        case "adverb": return "Trạng từ"
        case "pronoun": return "Đại từ"
        case "preposition": return "Giới từ"
        case "conjunction": return "Liên từ"
        default: return tag
        }
    }
}
