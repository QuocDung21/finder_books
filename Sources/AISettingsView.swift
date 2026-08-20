import SwiftUI

struct AISettingsView: View {
    @ObservedObject var settings = AISettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Cài Đặt & Quản Lý Model AI", systemImage: "cpu")
                    .font(.system(size: 15, weight: .bold))
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
            
            // Settings Form
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Section 1: AI Provider Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nhà Cung Cấp / Công Nghệ AI:")
                            .font(.system(size: 13, weight: .bold))
                        
                        Picker("Provider", selection: $settings.config.selectedProvider) {
                            ForEach(AIProviderType.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 320)
                        
                        Text(settings.config.selectedProvider.description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .background(Color.platformControlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    // Section 2: Provider Specific Configuration
                    providerSpecificConfig
                        .padding(14)
                        .background(Color.platformControlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    // Section 3: Scan Depth & Vision Options
                    behaviorSettingsSection
                        .padding(14)
                        .background(Color.platformControlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer with Test Connection Button
            HStack {
                if let status = settings.connectionStatusText {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(settings.isConnectionSuccess ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundColor(settings.isConnectionSuccess ? .primary : .red)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Button {
                    settings.testCurrentProviderConnection()
                } label: {
                    HStack(spacing: 5) {
                        if settings.isTestingConnection {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "network")
                        }
                        Text(settings.isTestingConnection ? "Đang Kiểm Tra..." : "Kiểm Tra Kết Nối")
                    }
                }
                .controlSize(.regular)
                .disabled(settings.isTestingConnection)
                
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
        #if os(macOS)
        .frame(minWidth: 580, idealWidth: 620, minHeight: 480)
        #endif
    }
    
    // MARK: - Provider Specific Configuration
    @ViewBuilder
    private var providerSpecificConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch settings.config.selectedProvider {
            case .appleNative:
                VStack(alignment: .leading, spacing: 6) {
                    Label("Apple On-Device Engine (Sẵn có)", systemImage: "apple.logo")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Sử dụng Apple NaturalLanguage + Apple Vision OCR tích hợp sẵn trong macOS. Không cần kết nối mạng hay tải thêm model ngoài.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
            case .ollama:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Cấu Hình Ollama (Local Server)", systemImage: "desktopcomputer")
                        .font(.system(size: 13, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ollama Server Endpoint:")
                            .font(.system(size: 11, weight: .medium))
                        TextField("http://localhost:11434", text: $settings.config.ollamaEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.system(size: 11, weight: .medium))
                        if !settings.ollamaAvailableModels.isEmpty {
                            Picker("Model", selection: $settings.config.ollamaModel) {
                                ForEach(settings.ollamaAvailableModels, id: \.self) { m in
                                    Text(m).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            TextField("llama3.2", text: $settings.config.ollamaModel)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
            case .openAI:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Cấu Hình OpenAI API", systemImage: "cloud.fill")
                        .font(.system(size: 13, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenAI API Key:")
                            .font(.system(size: 11, weight: .medium))
                        SecureField("sk-...", text: $settings.config.openAIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.system(size: 11, weight: .medium))
                        Picker("Model", selection: $settings.config.openAIModel) {
                            Text("gpt-4o-mini (Nhanh & Tiết Kiệm)").tag("gpt-4o-mini")
                            Text("gpt-4o (Thông Minh Nhất)").tag("gpt-4o")
                        }
                        .pickerStyle(.menu)
                    }
                }
                
            case .gemini:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Cấu Hình Google Gemini API", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gemini API Key:")
                            .font(.system(size: 11, weight: .medium))
                        SecureField("AIzaSy...", text: $settings.config.geminiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model:")
                            .font(.system(size: 11, weight: .medium))
                        Picker("Model", selection: $settings.config.geminiModel) {
                            Text("gemini-1.5-flash (Nhanh)").tag("gemini-1.5-flash")
                            Text("gemini-1.5-pro (Mạnh)").tag("gemini-1.5-pro")
                        }
                        .pickerStyle(.menu)
                    }
                }
                
            case .customOpenAI:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Custom OpenAI-compatible API", systemImage: "server.rack")
                        .font(.system(size: 13, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL:")
                            .font(.system(size: 11, weight: .medium))
                        TextField("https://api.groq.com/openai/v1", text: $settings.config.customEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key (nếu có):")
                            .font(.system(size: 11, weight: .medium))
                        SecureField("gsk_...", text: $settings.config.customKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Name:")
                            .font(.system(size: 11, weight: .medium))
                        TextField("llama-3.1-8b-instant", text: $settings.config.customModel)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }
    
    // MARK: - Behavior Settings
    private var behaviorSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tùy Chọn Phân Tích & Thị Giác:")
                .font(.system(size: 13, weight: .bold))
            
            Stepper("Số trang nội dung quét phân tích: \(settings.config.scanDepthPages) trang", value: $settings.config.scanDepthPages, in: 1...10)
                .font(.system(size: 12))
            
            Divider()
            
            Toggle("Bật Apple Vision OCR khi đọc tài liệu scan dạng ảnh", isOn: $settings.config.enableVisionOCR)
                .font(.system(size: 12))
            
            Toggle("Phân tích kích thước font & vị trí không gian trên trang bìa", isOn: $settings.config.enableVisualCoverAnalysis)
                .font(.system(size: 12))
        }
    }
}
