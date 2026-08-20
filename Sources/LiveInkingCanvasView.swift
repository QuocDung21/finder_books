import SwiftUI

struct LiveInkingCanvasView: View {
    let pageIndex: Int
    var isDrawingEnabled: Bool
    var activeColor: Color
    var activeLineWidth: CGFloat
    var isHighlighter: Bool
    
    @ObservedObject private var syncManager = LiveCompanionSyncManager.shared
    @State private var currentStrokePoints: [InkPoint] = []
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Background transparent catch area
                Color.clear
                    .contentShape(Rectangle())
                
                // Render finished strokes from both local and remote (iPad/Mac)
                let strokes = syncManager.pageStrokes[pageIndex] ?? []
                ForEach(strokes) { stroke in
                    drawStrokePath(stroke: stroke, width: w, height: h)
                }
                
                // Render currently active in-progress drawing stroke
                if !currentStrokePoints.isEmpty {
                    drawActivePath(points: currentStrokePoints, width: w, height: h)
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard isDrawingEnabled, w > 0, h > 0 else { return }
                        let normalizedX = max(0, min(1, value.location.x / w))
                        let normalizedY = max(0, min(1, value.location.y / h))
                        currentStrokePoints.append(InkPoint(x: normalizedX, y: normalizedY))
                    }
                    .onEnded { _ in
                        guard isDrawingEnabled, currentStrokePoints.count > 1 else {
                            currentStrokePoints.removeAll()
                            return
                        }
                        
                        let newStroke = LiveInkStroke(
                            pageIndex: pageIndex,
                            points: currentStrokePoints,
                            colorHex: activeColor.toHex(),
                            lineWidth: activeLineWidth,
                            opacity: isHighlighter ? 0.35 : 1.0,
                            isHighlighter: isHighlighter
                        )
                        
                        currentStrokePoints.removeAll()
                        syncManager.broadcastNewStroke(newStroke)
                    }
            )
            .allowsHitTesting(isDrawingEnabled)
        }
    }
    
    // MARK: - Draw Finished Stroke Path
    @ViewBuilder
    private func drawStrokePath(stroke: LiveInkStroke, width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            guard let first = stroke.points.first else { return }
            path.move(to: CGPoint(x: first.x * width, y: first.y * height))
            
            for pt in stroke.points.dropFirst() {
                path.addLine(to: CGPoint(x: pt.x * width, y: pt.y * height))
            }
        }
        .stroke(
            stroke.color.opacity(stroke.opacity),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
    
    // MARK: - Draw In-Progress Active Path
    @ViewBuilder
    private func drawActivePath(points: [InkPoint], width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x * width, y: first.y * height))
            
            for pt in points.dropFirst() {
                path.addLine(to: CGPoint(x: pt.x * width, y: pt.y * height))
            }
        }
        .stroke(
            activeColor.opacity(isHighlighter ? 0.35 : 1.0),
            style: StrokeStyle(
                lineWidth: activeLineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}
