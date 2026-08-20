import Foundation
import PDFKit
import NaturalLanguage
import Vision

// MARK: - Book Category Definition
enum BookCategory: String, CaseIterable, Identifiable {
    case technology = "Công Nghệ & Lập Trình"
    case business = "Kinh Tế & Tài Chính"
    case literature = "Văn Học & Tiểu Thuyết"
    case selfHelp = "Kỹ Năng & Tâm Lý"
    case scienceHistory = "Khoa Học & Lịch Sử"
    case languageEducation = "Ngoại Ngữ & Giáo Trình"
    case artDesign = "Nghệ Thuật & Thiết Kế"
    case comicsManga = "Truyện Tranh & Manga"
    case general = "Tài Liệu Chung"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .technology: return "laptopcomputer"
        case .business: return "chart.line.uptrend.xyaxis"
        case .literature: return "book.closed"
        case .selfHelp: return "brain.head.profile"
        case .scienceHistory: return "atom"
        case .languageEducation: return "character.book.closed"
        case .artDesign: return "paintpalette"
        case .comicsManga: return "photo.on.rectangle.angled"
        case .general: return "folder"
        }
    }
    
    var folderName: String {
        switch self {
        case .technology: return "Cong_Nghe_Lap_Trinh"
        case .business: return "Kinh_Te_Tai_Chinh"
        case .literature: return "Van_Hoc_Tieu_Thuyet"
        case .selfHelp: return "Ky_Nang_Tam_Ly"
        case .scienceHistory: return "Khoa_Hoc_Lich_Su"
        case .languageEducation: return "Ngoai_Ngu_Giao_Trinh"
        case .artDesign: return "Nghe_Thuat_Thiet_Ke"
        case .comicsManga: return "Truyen_Tranh_Manga"
        case .general: return "Tai_Lieu_Khac"
        }
    }
    
    var keywords: [String] {
        switch self {
        case .technology:
            return [
                "swift", "python", "javascript", "java", "c++", "golang", "rust", "programming", "lập trình",
                "software", "phần mềm", "algorithm", "thuật toán", "database", "cơ sở dữ liệu", "sql",
                "ai", "artificial intelligence", "trí tuệ nhân tạo", "machine learning", "deep learning",
                "neural", "network", "mạng", "security", "an ninh mạng", "cloud", "devops", "docker",
                "kubernetes", "ios", "android", "frontend", "backend", "web", "html", "css", "api", "code",
                "architecture", "kiến trúc phần mềm", "developer", "kỹ thuật số", "computer", "máy tính"
            ]
        case .business:
            return [
                "kinh tế", "tài chính", "finance", "economics", "kinh doanh", "business", "marketing",
                "quản trị", "management", "đầu tư", "investment", "chứng khoán", "stock", "tiền tệ",
                "khởi nghiệp", "startup", "doanh nghiệp", "corporate", "kế toán", "accounting",
                "thương mại", "commerce", "lợi nhuận", "profit", "chiến lược", "strategy", "bán hàng",
                "sales", "lãnh đạo", "leadership", "tiền bạc", "money", "bất động sản", "real estate"
            ]
        case .literature:
            return [
                "tiểu thuyết", "novel", "truyện ngắn", "story", "thơ", "poetry", "văn học", "literature",
                "tác phẩm", "trinh thám", "detective", "giả tưởng", "fantasy", "khoa học viễn tưởng", "sci-fi",
                "lãng mạn", "romance", "kinh dị", "horror", "kịch", "drama", "hồi ký", "memoir", "cổ tích",
                "tập truyện", "nhà văn", "author", "chương", "tập"
            ]
        case .selfHelp:
            return [
                "kỹ năng", "tâm lý", "psychology", "phát triển bản thân", "self-help", "thói quen", "habit",
                "tư duy", "mindset", "thành công", "success", "giao tiếp", "communication", "đắc nhân tâm",
                "động lực", "motivation", "hạnh phúc", "happiness", "thiền", "mindfulness", "quản lý thời gian",
                "productivity", "cảm xúc", "emotion", "tự chữa lành", "sức khỏe tinh thần", "tập trung"
            ]
        case .scienceHistory:
            return [
                "khoa học", "science", "lịch sử", "history", "vật lý", "physics", "hóa học", "chemistry",
                "sinh học", "biology", "toán học", "mathematics", "thiên văn", "astronomy", "vũ trụ",
                "triết học", "philosophy", "địa lý", "geography", "y học", "medicine", "tiến hóa", "evolution",
                "chiến tranh", "thế chiến", "văn minh", "khảo cổ", "nguyên tử", "thuyết tương đối"
            ]
        case .languageEducation:
            return [
                "tiếng anh", "english", "ielts", "toeic", "toefl", "tiếng nhật", "japanese", "tiếng trung",
                "chinese", "ngữ pháp", "grammar", "từ vựng", "vocabulary", "ngoại ngữ", "language",
                "giáo trình", "textbook", "bài tập", "luyện thi", "đề thi", "phát âm", "pronunciation",
                "hán tự", "kanji", "đối thoại", "conversation", "học tập", "education"
            ]
        case .artDesign:
            return [
                "thiết kế", "design", "nghệ thuật", "art", "ui", "ux", "đồ họa", "graphic", "hội họa",
                "painting", "nhiếp ảnh", "photography", "kiến trúc", "architecture", "âm nhạc", "music",
                "màu sắc", "color", "typography", "bố cục", "layout", "phác thảo", "sketch", "drawing"
            ]
        case .comicsManga:
            return [
                "truyện tranh", "manga", "comic", "anime", "manhwa", "manhua", "chibi", "tập truyện tranh"
            ]
        case .general:
            return []
        }
    }
}

// MARK: - Classification Result
struct AIClassificationResult {
    let category: BookCategory
    let confidence: Double
    let detectedLanguage: String
    let excerptSnippet: String
    let reason: String
}

// MARK: - Native AI Book Classification Service
final class AIBookClassificationService {
    
    // MARK: - Classify Single PDF
    func classifyBook(at fileURL: URL) async -> AIClassificationResult {
        guard let doc = PDFDocument(url: fileURL) else {
            return AIClassificationResult(
                category: .general,
                confidence: 0.0,
                detectedLanguage: "unknown",
                excerptSnippet: "",
                reason: "Không thể mở file PDF"
            )
        }
        
        // 1. Trích xuất text từ Metadata + Tên File + 3 trang đầu
        var extractedText = ""
        
        // File name & Metadata
        let fileNameWithoutExt = fileURL.deletingPathExtension().lastPathComponent
        extractedText += "Tiêu đề: \(fileNameWithoutExt)\n"
        
        if let attrs = doc.documentAttributes {
            if let title = attrs[PDFDocumentAttribute.titleAttribute] as? String {
                extractedText += "Title: \(title)\n"
            }
            if let subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String {
                extractedText += "Subject: \(subject)\n"
            }
            if let keywords = attrs[PDFDocumentAttribute.keywordsAttribute] as? String {
                extractedText += "Keywords: \(keywords)\n"
            }
        }
        
        // Đọc 3 trang đầu
        let maxPagesToScan = min(3, doc.pageCount)
        var hasTextLayer = false
        
        for i in 0..<maxPagesToScan {
            if let page = doc.page(at: i), let pageString = page.string, !pageString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedText += "Trang \(i + 1):\n\(pageString)\n"
                hasTextLayer = true
            }
        }
        
        // Fallback OCR nếu file PDF scan (không có text)
        if !hasTextLayer && doc.pageCount > 0 {
            if let firstPage = doc.page(at: 0) {
                let ocrText = await performOCR(on: firstPage)
                if !ocrText.isEmpty {
                    extractedText += "OCR Bìa:\n\(ocrText)\n"
                }
            }
        }
        
        // 2. Nhận diện ngôn ngữ
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(extractedText)
        let dominantLang = recognizer.dominantLanguage?.rawValue ?? "vi"
        
        // 3. Phân loại theo Apple NaturalLanguage + Keyword Semantic Scoring
        let normalizedText = extractedText.lowercased()
        var categoryScores: [BookCategory: Double] = [:]
        
        for category in BookCategory.allCases where category != .general {
            var score = 0.0
            
            // Keyword matching với trọng số
            for keyword in category.keywords {
                let kwLower = keyword.lowercased()
                if fileNameWithoutExt.lowercased().contains(kwLower) {
                    score += 5.0 // Tên file khớp trọng số cao nhất
                }
                if normalizedText.contains(kwLower) {
                    score += 1.5
                }
            }
            
            categoryScores[category] = score
        }
        
        // Tìm thể loại điểm cao nhất
        let bestMatch = categoryScores.max(by: { $0.value < $1.value })
        let topScore = bestMatch?.value ?? 0.0
        let topCategory = (topScore > 1.0) ? (bestMatch?.key ?? .general) : .general
        
        let confidence = min(0.99, max(0.4, topScore / 10.0))
        
        let snippet = String(extractedText.prefix(250)).replacingOccurrences(of: "\n", with: " ")
        let reason = topCategory != .general
            ? "Nhận diện từ khóa và ngữ cảnh phù hợp thể loại \(topCategory.rawValue) (Điểm: \(String(format: "%.1f", topScore)))"
            : "Chưa đủ dữ liệu đặc trưng, gom vào Tài Liệu Khác"
        
        return AIClassificationResult(
            category: topCategory,
            confidence: confidence,
            detectedLanguage: dominantLang,
            excerptSnippet: snippet,
            reason: reason
        )
    }
    
    // MARK: - Fallback Apple Vision OCR
    private func performOCR(on page: PDFPage) async -> String {
        return await Task.detached {
            let thumb = page.thumbnail(of: CGSize(width: 800, height: 1000), for: .cropBox)
            guard let cgImage = thumb.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return ""
            }
            
            var recognizedStrings: [String] = []
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let results = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                for obs in results {
                    if let topCandidate = obs.topCandidates(1).first {
                        recognizedStrings.append(topCandidate.string)
                    }
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["vi-VN", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            
            return recognizedStrings.joined(separator: " ")
        }.value
    }
    
    // MARK: - AI Smart Title Suggestions
    func extractTitleSuggestions(for pdfURL: URL) async -> [String] {
        return await Task.detached {
            var suggestions: [String] = []
            guard let doc = PDFDocument(url: pdfURL) else { return [] }
            
            // 1. Metadata Extraction
            let metaTitle = (doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let metaAuthor = (doc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let title = metaTitle, title.count > 2 && title.count < 100 && !title.lowercased().contains("untitled") {
                let cleanMeta = self.cleanTitleString(title)
                if !cleanMeta.isEmpty {
                    suggestions.append(cleanMeta)
                    if let author = metaAuthor, author.count > 2 && author.count < 60 {
                        suggestions.append("\(cleanMeta) - \(self.cleanTitleString(author))")
                    }
                }
            }
            
            // 2. Cleaned Current Filename
            let currentBase = pdfURL.deletingPathExtension().lastPathComponent
            let cleanedBase = self.cleanFilename(currentBase)
            if !cleanedBase.isEmpty && !suggestions.contains(where: { $0.caseInsensitiveCompare(cleanedBase) == .orderedSame }) {
                suggestions.append(cleanedBase)
            }
            
            // 3. Extract text from Page 1 (Cover / Title Page)
            var coverLines: [String] = []
            if let page1 = doc.page(at: 0) {
                var p1Text = page1.string ?? ""
                if p1Text.trimmingCharacters(in: .whitespacesAndNewlines).count < 30 {
                    // Fallback to OCR on first page
                    let ocrResult = await self.performOCR(on: page1)
                    p1Text = ocrResult
                }
                
                let rawLines = p1Text.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.count >= 3 && $0.count <= 80 }
                
                for line in rawLines {
                    let lower = line.lowercased()
                    // Filter out copyright, date, page number lines
                    if lower.contains("copyright") || lower.contains("all rights") || lower.contains("isbn") || lower.contains("published") || lower.contains("trang ") || lower.contains("edition") {
                        continue
                    }
                    coverLines.append(self.cleanTitleString(line))
                    if coverLines.count >= 3 { break }
                }
            }
            
            for line in coverLines {
                if !suggestions.contains(where: { $0.caseInsensitiveCompare(line) == .orderedSame }) {
                    suggestions.append(line)
                }
            }
            
            // Deduplicate and filter out empty / too short
            let result = suggestions.filter { $0.count >= 3 }
            return Array(result.prefix(4))
        }.value
    }
    
    private func cleanFilename(_ filename: String) -> String {
        var str = filename
        // Remove common web tags
        let noisePatterns = [
            "\\[z-lib\\.org\\]", "\\[z-library\\]", "\\(PDFDrive\\)", "\\(z-lib\\.org\\)",
            "\\(PDFDrive\\.com\\)", "_part\\d+", "v\\d+\\.\\d+", "\\.pdf$", "^\\d+[\\s_.-]+"
        ]
        for pattern in noisePatterns {
            str = str.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        str = str.replacingOccurrences(of: "_", with: " ")
        str = str.replacingOccurrences(of: "  ", with: " ")
        return cleanTitleString(str)
    }
    
    private func cleanTitleString(_ title: String) -> String {
        var clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-_~*#[](){}"))
        clean = clean.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return clean
    }
}
