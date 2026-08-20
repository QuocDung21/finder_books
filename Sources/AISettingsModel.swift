import Foundation

// MARK: - AI Provider Types
enum AIProviderType: String, CaseIterable, Identifiable, Codable {
    case appleNative = "Apple Native (On-Device)"
    case ollama = "Ollama (Local LLM)"
    case openAI = "OpenAI (ChatGPT)"
    case gemini = "Google Gemini"
    case customOpenAI = "Custom API (OpenAI-compatible)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .appleNative:
            return "Chạy trực tiếp trên máy qua Apple NaturalLanguage & Vision OCR. 100% Offline, siêu nhanh và bảo mật."
        case .ollama:
            return "Kết nối tới máy chủ Ollama cục bộ (Llama 3.2, Mistral, Qwen...). Miễn phí & Offline."
        case .openAI:
            return "Sử dụng API OpenAI (GPT-4o mini / GPT-4o) để phân tích ngữ cảnh thông minh nhất."
        case .gemini:
            return "Sử dụng Google Gemini 1.5 Flash API tốc độ cao, hỗ trợ tài liệu lớn."
        case .customOpenAI:
            return "Kết nối máy chủ tương thích OpenAI API (Groq, Together AI, vLLM, LM Studio...)."
        }
    }

    var icon: String {
        switch self {
        case .appleNative: return "apple.logo"
        case .ollama: return "desktopcomputer"
        case .openAI: return "cloud.fill"
        case .gemini: return "sparkles"
        case .customOpenAI: return "server.rack"
        }
    }
}

// MARK: - AI Settings Configuration Model
struct AISettingsConfig: Codable {
    var selectedProvider: AIProviderType = .appleNative

    // Ollama settings
    var ollamaEndpoint: String = "http://localhost:11434"
    var ollamaModel: String = "llama3.2"

    // Cloud API settings
    var openAIKey: String = ""
    var openAIModel: String = "gpt-4o-mini"

    var geminiKey: String = ""
    var geminiModel: String = "gemini-1.5-flash"

    var customEndpoint: String = "https://api.groq.com/openai/v1"
    var customKey: String = ""
    var customModel: String = "llama-3.1-8b-instant"

    // Behavior settings
    var scanDepthPages: Int = 3
    var enableVisionOCR: Bool = true
    var enableVisualCoverAnalysis: Bool = true

    // MARK: - UserDefaults Persistence
    private static let key = "FinderBooks_AISettingsConfig_v1"

    static func load() -> AISettingsConfig {
        if let data = UserDefaults.standard.data(forKey: key),
           let config = try? JSONDecoder().decode(AISettingsConfig.self, from: data) {
            return config
        }
        return AISettingsConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: AISettingsConfig.key)
        }
    }
}
