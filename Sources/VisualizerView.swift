import SwiftUI

struct VisualizerView: View {
    let parts: [PdfPartItem]
    let totalPages: Int
    var onSelectPart: ((PdfPartItem) -> Void)? = nil
    
    @State private var hoveredPartID: UUID? = nil
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            if totalPages <= 0 || parts.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.platformControlBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.secondary)
                        Text("Chưa có thông tin sách để hiển thị tỷ lệ chia")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                let totalCovered = parts.reduce(0) { $0 + $1.pageCount }
                let baseTotal = max(totalPages, totalCovered)
                
                HStack(spacing: 3) {
                    ForEach(parts) { part in
                        let ratio = CGFloat(part.pageCount) / CGFloat(max(1, baseTotal))
                        let segWidth = max(24, w * ratio - 3)
                        let pct = totalPages > 0 ? Int(round((Double(part.pageCount) / Double(totalPages)) * 100)) : 0
                        let isHovered = hoveredPartID == part.id
                        
                        Button {
                            onSelectPart?(part)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [part.color.opacity(isHovered ? 1.0 : 0.9), part.color],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: isHovered ? part.color.opacity(0.4) : .clear, radius: 4, y: 1)
                                
                                if segWidth > 90 {
                                    Text("P\(part.partNum): \(part.pageCount) tr (\(pct)%)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                } else if segWidth > 45 {
                                    Text("P\(part.partNum) • \(pct)%")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                } else {
                                    Text("P\(part.partNum)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: max(18, segWidth), height: h)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
                        .onHover { hovering in
                            hoveredPartID = hovering ? part.id : nil
                        }
                        .help("Bấm để xem nhanh nội dung Phần \(part.partNum) (Trang \(part.startPage) ➔ \(part.endPage))")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(height: 34)
    }
}
