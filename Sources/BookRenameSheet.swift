import SwiftUI
import PDFKit

struct BookRenameSheet: View {
    let book: BookItem
    var onRenameConfirmed: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle: String = ""
    @State private var suggestions: [String] = []
    @State private var isLoadingSuggestions: Bool = true

    private let classifier = AIBookClassificationService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Đổi Tên Sách")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Huỷ") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.platformControlBackground)

            Divider()

            // Body
            HStack(alignment: .top, spacing: 20) {
                // Book Cover
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)

                    if let doc = PDFDocument(url: book.url), let page = doc.page(at: 0) {
                        Image(platformImage: page.platformThumbnail(size: CGSize(width: 120, height: 160)))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 100, height: 140)

                // Form & Suggestions
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tên hiện tại:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(book.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(2)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tên sách mới:")
                            .font(.system(size: 12, weight: .bold))

                        TextField("Nhập tên sách mới...", text: $newTitle)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.regular)
                    }

                    // AI Suggestions Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            Text("Gợi ý từ nội dung & bìa sách:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)

                            if isLoadingSuggestions {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }

                        if !suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button {
                                        newTitle = suggestion
                                    } label: {
                                        HStack {
                                            Text(suggestion)
                                                .font(.system(size: 11))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "arrow.up.backward.circle")
                                                .font(.system(size: 11))
                                                .foregroundColor(.accentColor)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.platformControlBackground)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                                    )
                                }
                            }
                        } else if !isLoadingSuggestions {
                            Text("Không tìm thấy gợi ý phù hợp.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Huỷ Bỏ") {
                    dismiss()
                }
                .controlSize(.regular)

                Button("Đổi Tên") {
                    applyRename()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.platformControlBackground)
        }
        .frame(minWidth: 540, maxWidth: 600)
        .onAppear {
            newTitle = book.baseName
            loadSuggestions()
        }
    }

    private func loadSuggestions() {
        isLoadingSuggestions = true
        Task {
            let list = await classifier.extractTitleSuggestions(for: book.url)
            self.suggestions = list
            self.isLoadingSuggestions = false
        }
    }

    private func applyRename() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRenameConfirmed(trimmed)
        dismiss()
    }
}
