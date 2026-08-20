import Foundation
import SwiftUI

@MainActor
class AISettingsManager: ObservableObject {
    static let shared = AISettingsManager()
    
    @Published var config: AISettingsConfig {
        didSet {
            config.save()
        }
    }
    
    @Published var isTestingConnection: Bool = false
    @Published var connectionStatusText: String? = nil
    @Published var isConnectionSuccess: Bool = false
    @Published var ollamaAvailableModels: [String] = ["llama3.2", "mistral", "gemma2", "qwen2.5"]
    
    init() {
        self.config = AISettingsConfig.load()
    }
    
    // MARK: - Test Provider Connection
    func testCurrentProviderConnection() {
        isTestingConnection = true
        connectionStatusText = "Đang kiểm tra kết nối..."
        isConnectionSuccess = false
        
        Task {
            switch config.selectedProvider {
            case .appleNative:
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.isTestingConnection = false
                self.isConnectionSuccess = true
                self.connectionStatusText = "Sẵn sàng (Apple On-Device Engine hoạt động tốt)"
                
            case .ollama:
                let success = await testOllamaConnection()
                self.isTestingConnection = false
                self.isConnectionSuccess = success
                if success {
                    self.connectionStatusText = "Kết nối Ollama thành công! (Tìm thấy \(self.ollamaAvailableModels.count) models)"
                } else {
                    self.connectionStatusText = "Không thể kết nối đến \(config.ollamaEndpoint). Hãy đảm bảo Ollama đang chạy."
                }
                
            case .openAI:
                let success = await testOpenAIConnection()
                self.isTestingConnection = false
                self.isConnectionSuccess = success
                if success {
                    self.connectionStatusText = "API Key OpenAI hợp lệ!"
                } else {
                    self.connectionStatusText = "Lỗi kết nối OpenAI: API Key không đúng hoặc hết hạn mức."
                }
                
            case .gemini:
                let success = await testGeminiConnection()
                self.isTestingConnection = false
                self.isConnectionSuccess = success
                if success {
                    self.connectionStatusText = "Google Gemini API Key hợp lệ!"
                } else {
                    self.connectionStatusText = "Lỗi kết nối Gemini: API Key không hợp lệ."
                }
                
            case .customOpenAI:
                let success = await testCustomEndpointConnection()
                self.isTestingConnection = false
                self.isConnectionSuccess = success
                if success {
                    self.connectionStatusText = "Kết nối Custom API Endpoint thành công!"
                } else {
                    self.connectionStatusText = "Không thể kết nối tới Custom Endpoint."
                }
            }
        }
    }
    
    // MARK: - Ollama API
    private func testOllamaConnection() async -> Bool {
        guard let url = URL(string: "\(config.ollamaEndpoint)/api/tags") else { return false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else { return false }
            
            struct OllamaTagsResponse: Codable {
                struct ModelItem: Codable {
                    let name: String
                }
                let models: [ModelItem]?
            }
            
            if let decoded = try? JSONDecoder().decode(OllamaTagsResponse.self, from: data),
               let models = decoded.models, !models.isEmpty {
                self.ollamaAvailableModels = models.map { $0.name }
                if !self.ollamaAvailableModels.contains(config.ollamaModel) {
                    self.config.ollamaModel = self.ollamaAvailableModels.first ?? "llama3.2"
                }
            }
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - OpenAI API Test
    private func testOpenAIConnection() async -> Bool {
        guard !config.openAIKey.isEmpty, let url = URL(string: "https://api.openai.com/v1/models") else { return false }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(config.openAIKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Gemini API Test
    private func testGeminiConnection() async -> Bool {
        guard !config.geminiKey.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(config.geminiKey)") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Custom Endpoint Test
    private func testCustomEndpointConnection() async -> Bool {
        guard let url = URL(string: "\(config.customEndpoint)/models") else { return false }
        var req = URLRequest(url: url)
        if !config.customKey.isEmpty {
            req.setValue("Bearer \(config.customKey)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 8
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
