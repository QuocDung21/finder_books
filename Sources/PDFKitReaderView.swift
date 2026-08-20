import SwiftUI
import PDFKit

// =============================================================================
// CROSS-DEVICE INKING ENGINE v5
// 
// KEY DESIGN: Store RAW PDF page coordinates (from pdfView.convert(to: page))
// directly in InkPoint. NO normalization, NO Y-inversion, NO manual math.
//
// Both Mac and iPad open the same PDF → page.bounds(for: .cropBox) is IDENTICAL.
// A point at (306.2, 421.8) in PDF page space is the SAME physical position
// on both devices. Each device renders using pdfView.convert(from: page).
//
// This is a pure round-trip through Apple's own PDFView.convert API:
//   Touch → pdfView.convert(touch, to: page) → store raw → transmit
//   Receive → pdfView.convert(raw, from: page) → draw on screen
// =============================================================================

#if os(macOS)
import AppKit

// MARK: - macOS InkingPDFView
class InkingPDFView: PDFView {
    var isDrawingEnabled: Bool = false
    var activeColor: NSColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false

    private var currentRawPoints: [CGPoint] = []   // Raw PDF page coordinates
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0

    // We draw strokes by overriding draw() on the PDFView itself.
    // PDFView.draw() first renders the PDF content, then our override
    // draws the ink strokes on top. This guarantees the coordinate
    // system matches pdfView.convert exactly.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let doc = document else { return }
        let syncManager = LiveCompanionSyncManager.shared

        // Draw all committed strokes for visible pages
        for page in visiblePages {
            let pageIndex = doc.index(for: page)
            guard let strokes = syncManager.pageStrokes[pageIndex], !strokes.isEmpty else { continue }

            for stroke in strokes {
                drawStroke(stroke, on: page)
            }
        }

        // Draw the in-progress stroke while user is dragging
        if !currentRawPoints.isEmpty, let page = currentPageForDrawing, currentRawPoints.count > 1 {
            let path = NSBezierPath()
            path.lineWidth = activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            let first = self.convert(currentRawPoints[0], from: page)
            path.move(to: first)
            for i in 1..<currentRawPoints.count {
                let pt = self.convert(currentRawPoints[i], from: page)
                path.line(to: pt)
            }

            activeColor.withAlphaComponent(isHighlighter ? 0.35 : 1.0).setStroke()
            path.stroke()
        }
    }

    private func drawStroke(_ stroke: LiveInkStroke, on page: PDFPage) {
        guard stroke.points.count > 1, let first = stroke.points.first else { return }

        let path = NSBezierPath()
        path.lineWidth = stroke.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let firstScreen = self.convert(CGPoint(x: first.x, y: first.y), from: page)
        path.move(to: firstScreen)

        for pt in stroke.points.dropFirst() {
            let screen = self.convert(CGPoint(x: pt.x, y: pt.y), from: page)
            path.line(to: screen)
        }

        let col = NSColor(hex: stroke.colorHex) ?? .red
        col.withAlphaComponent(stroke.opacity).setStroke()
        path.stroke()
    }

    // MARK: Mouse Handling
    override func mouseDown(with event: NSEvent) {
        guard isDrawingEnabled, let doc = document else {
            super.mouseDown(with: event)
            return
        }
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true) else {
            super.mouseDown(with: event)
            return
        }
        let pdfPoint = self.convert(viewPoint, to: page)
        currentPageForDrawing = page
        currentPageIndexForDrawing = doc.index(for: page)
        currentRawPoints = [pdfPoint]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawingEnabled, let page = currentPageForDrawing else {
            super.mouseDragged(with: event)
            return
        }
        let viewPoint = convert(event.locationInWindow, from: nil)
        let pdfPoint = self.convert(viewPoint, to: page)
        currentRawPoints.append(pdfPoint)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawingEnabled, currentRawPoints.count > 1 else {
            currentRawPoints.removeAll()
            currentPageForDrawing = nil
            needsDisplay = true
            if !isDrawingEnabled { super.mouseUp(with: event) }
            return
        }

        let inkPoints = currentRawPoints.map { InkPoint(x: $0.x, y: $0.y) }
        let stroke = LiveInkStroke(
            pageIndex: currentPageIndexForDrawing,
            points: inkPoints,
            colorHex: activeColor.toHex() ?? "#FF0000",
            lineWidth: activeLineWidth,
            opacity: isHighlighter ? 0.35 : 1.0,
            isHighlighter: isHighlighter
        )

        currentRawPoints.removeAll()
        currentPageForDrawing = nil
        LiveCompanionSyncManager.shared.broadcastNewStroke(stroke)
        needsDisplay = true
    }
}

// MARK: - macOS PDFKitReaderView
struct PDFKitReaderView: NSViewRepresentable {
    let url: URL
    @Binding var currentPageIndex: Int
    @Binding var totalPages: Int
    @Binding var displayMode: PDFDisplayMode
    @Binding var scaleFactor: CGFloat
    @Binding var autoScales: Bool
    @Binding var selectedText: String
    var isDrawingEnabled: Bool = false
    var activeColor: Color = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false

    func makeNSView(context: Context) -> InkingPDFView {
        let pdfView = InkingPDFView()
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = autoScales
        pdfView.displayMode = displayMode
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = NSColor.windowBackgroundColor

        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            DispatchQueue.main.async {
                self.totalPages = doc.pageCount
                if currentPageIndex < doc.pageCount, let page = doc.page(at: currentPageIndex) {
                    pdfView.go(to: page)
                }
            }
        }

        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)), name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.selectionChanged(_:)), name: .PDFViewSelectionChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.redraw), name: .PDFViewScaleChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.redraw), name: NSNotification.Name("LiveCompanionStrokesUpdated"), object: nil)

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateNSView(_ pdfView: InkingPDFView, context: Context) {
        context.coordinator.parent = self
        pdfView.isDrawingEnabled = isDrawingEnabled
        pdfView.activeColor = NSColor(activeColor)
        pdfView.activeLineWidth = activeLineWidth
        pdfView.isHighlighter = isHighlighter

        if pdfView.document?.documentURL != url {
            if let doc = PDFDocument(url: url) {
                pdfView.document = doc
                self.totalPages = doc.pageCount
            }
        }
        if pdfView.displayMode != displayMode { pdfView.displayMode = displayMode }
        if pdfView.autoScales != autoScales { pdfView.autoScales = autoScales }
        if !autoScales && scaleFactor > 0 && abs(pdfView.scaleFactor - scaleFactor) > 0.05 {
            pdfView.scaleFactor = scaleFactor
        }
        if let doc = pdfView.document, let cur = pdfView.currentPage,
           doc.index(for: cur) != currentPageIndex,
           currentPageIndex >= 0 && currentPageIndex < doc.pageCount,
           let target = doc.page(at: currentPageIndex) {
            pdfView.go(to: target)
        }
        pdfView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: PDFKitReaderView
        weak var pdfView: InkingPDFView?
        init(_ parent: PDFKitReaderView) { self.parent = parent }

        @objc func redraw() { pdfView?.needsDisplay = true }

        @objc func pageChanged(_ n: Notification) {
            guard let pv = n.object as? PDFView, let doc = pv.document, let cur = pv.currentPage else { return }
            let idx = doc.index(for: cur)
            if idx != parent.currentPageIndex {
                DispatchQueue.main.async { self.parent.currentPageIndex = idx }
            }
            pdfView?.needsDisplay = true
        }

        @objc func selectionChanged(_ n: Notification) {
            guard let pv = n.object as? PDFView else { return }
            let s = pv.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DispatchQueue.main.async { self.parent.selectedText = s }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

// =========================================================================
#elseif os(iOS)
import UIKit

// MARK: - iOS InkingPDFView
class InkingPDFView: PDFView {
    var isDrawingEnabled: Bool = false {
        didSet { updateScrollLock() }
    }
    var activeColor: UIColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false

    private lazy var overlayView: InkOverlay = {
        let v = InkOverlay(pdfView: self)
        v.backgroundColor = .clear
        v.isOpaque = false
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(overlayView)
        overlayView.frame = bounds
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(overlayView)
        overlayView.frame = bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bringSubviewToFront(overlayView)
        overlayView.frame = bounds
        overlayView.setNeedsDisplay()
    }

    func redrawInking() { overlayView.setNeedsDisplay() }

    private func updateScrollLock() {
        for sub in subviews {
            if let scroll = sub as? UIScrollView {
                scroll.isScrollEnabled = !isDrawingEnabled
            }
        }
    }
}

// MARK: - iOS Ink Overlay (Transparent touch catcher + renderer)
class InkOverlay: UIView {
    weak var pdfView: InkingPDFView?

    private var currentRawPoints: [CGPoint] = []   // Raw PDF page coordinates
    private var currentPage: PDFPage? = nil
    private var currentPageIndex: Int = 0

    init(pdfView: InkingPDFView) {
        self.pdfView = pdfView
        super.init(frame: .zero)
        isMultipleTouchEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return pdfView?.isDrawingEnabled ?? false
    }

    // MARK: Drawing
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let pv = pdfView, let doc = pv.document else { return }
        let syncManager = LiveCompanionSyncManager.shared

        // Draw all committed strokes for visible pages
        for page in pv.visiblePages {
            let pageIndex = doc.index(for: page)
            guard let strokes = syncManager.pageStrokes[pageIndex], !strokes.isEmpty else { continue }

            for stroke in strokes {
                drawStroke(stroke, on: page, in: pv)
            }
        }

        // Draw in-progress stroke
        if currentRawPoints.count > 1, let page = currentPage {
            let path = UIBezierPath()
            path.lineWidth = pv.activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            let first = pv.convert(currentRawPoints[0], from: page)
            path.move(to: first)
            for i in 1..<currentRawPoints.count {
                let pt = pv.convert(currentRawPoints[i], from: page)
                path.addLine(to: pt)
            }

            pv.activeColor.withAlphaComponent(pv.isHighlighter ? 0.35 : 1.0).setStroke()
            path.stroke()
        }
    }

    private func drawStroke(_ stroke: LiveInkStroke, on page: PDFPage, in pv: PDFView) {
        guard stroke.points.count > 1, let first = stroke.points.first else { return }

        let path = UIBezierPath()
        path.lineWidth = stroke.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let firstScreen = pv.convert(CGPoint(x: first.x, y: first.y), from: page)
        path.move(to: firstScreen)

        for pt in stroke.points.dropFirst() {
            let screen = pv.convert(CGPoint(x: pt.x, y: pt.y), from: page)
            path.addLine(to: screen)
        }

        let col = UIColor(hex: stroke.colorHex) ?? .red
        col.withAlphaComponent(stroke.opacity).setStroke()
        path.stroke()
    }

    // MARK: Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pv = pdfView, pv.isDrawingEnabled, let doc = pv.document, let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }
        let viewPt = touch.location(in: pv)
        guard let page = pv.page(for: viewPt, nearest: true) else {
            super.touchesBegan(touches, with: event)
            return
        }
        let pdfPt = pv.convert(viewPt, to: page)
        currentPage = page
        currentPageIndex = doc.index(for: page)
        currentRawPoints = [pdfPt]
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pv = pdfView, pv.isDrawingEnabled, let page = currentPage, let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }
        let viewPt = touch.location(in: pv)
        let pdfPt = pv.convert(viewPt, to: page)
        currentRawPoints.append(pdfPt)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pv = pdfView, pv.isDrawingEnabled, currentRawPoints.count > 1 else {
            currentRawPoints.removeAll()
            currentPage = nil
            setNeedsDisplay()
            if !(pdfView?.isDrawingEnabled ?? false) { super.touchesEnded(touches, with: event) }
            return
        }

        let inkPoints = currentRawPoints.map { InkPoint(x: $0.x, y: $0.y) }
        let stroke = LiveInkStroke(
            pageIndex: currentPageIndex,
            points: inkPoints,
            colorHex: pv.activeColor.toHex() ?? "#FF0000",
            lineWidth: pv.activeLineWidth,
            opacity: pv.isHighlighter ? 0.35 : 1.0,
            isHighlighter: pv.isHighlighter
        )

        currentRawPoints.removeAll()
        currentPage = nil
        LiveCompanionSyncManager.shared.broadcastNewStroke(stroke)
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentRawPoints.removeAll()
        currentPage = nil
        setNeedsDisplay()
        super.touchesCancelled(touches, with: event)
    }
}

// MARK: - iOS PDFKitReaderView
struct PDFKitReaderView: UIViewRepresentable {
    let url: URL
    @Binding var currentPageIndex: Int
    @Binding var totalPages: Int
    @Binding var displayMode: PDFDisplayMode
    @Binding var scaleFactor: CGFloat
    @Binding var autoScales: Bool
    @Binding var selectedText: String
    var isDrawingEnabled: Bool = false
    var activeColor: Color = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false

    func makeUIView(context: Context) -> InkingPDFView {
        let pdfView = InkingPDFView()
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pdfView.autoScales = autoScales
        pdfView.displayMode = displayMode
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = UIColor.systemBackground

        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
            DispatchQueue.main.async {
                self.totalPages = doc.pageCount
                if currentPageIndex < doc.pageCount, let page = doc.page(at: currentPageIndex) {
                    pdfView.go(to: page)
                }
            }
        }

        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)), name: .PDFViewPageChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.selectionChanged(_:)), name: .PDFViewSelectionChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.redraw), name: .PDFViewScaleChanged, object: pdfView)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.redraw), name: NSNotification.Name("LiveCompanionStrokesUpdated"), object: nil)

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateUIView(_ pdfView: InkingPDFView, context: Context) {
        context.coordinator.parent = self
        pdfView.isDrawingEnabled = isDrawingEnabled
        pdfView.activeColor = UIColor(activeColor)
        pdfView.activeLineWidth = activeLineWidth
        pdfView.isHighlighter = isHighlighter

        if pdfView.document?.documentURL != url {
            if let doc = PDFDocument(url: url) {
                pdfView.document = doc
                self.totalPages = doc.pageCount
            }
        }
        if pdfView.displayMode != displayMode { pdfView.displayMode = displayMode }
        if pdfView.autoScales != autoScales { pdfView.autoScales = autoScales }
        if !autoScales && scaleFactor > 0 && abs(pdfView.scaleFactor - scaleFactor) > 0.05 {
            pdfView.scaleFactor = scaleFactor
        }
        if let doc = pdfView.document, let cur = pdfView.currentPage,
           doc.index(for: cur) != currentPageIndex,
           currentPageIndex >= 0 && currentPageIndex < doc.pageCount,
           let target = doc.page(at: currentPageIndex) {
            pdfView.go(to: target)
        }
        pdfView.redrawInking()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: PDFKitReaderView
        weak var pdfView: InkingPDFView?
        init(_ parent: PDFKitReaderView) { self.parent = parent }

        @objc func redraw() { pdfView?.redrawInking() }

        @objc func pageChanged(_ n: Notification) {
            guard let pv = n.object as? PDFView, let doc = pv.document, let cur = pv.currentPage else { return }
            let idx = doc.index(for: cur)
            if idx != parent.currentPageIndex {
                DispatchQueue.main.async { self.parent.currentPageIndex = idx }
            }
            pdfView?.redrawInking()
        }

        @objc func selectionChanged(_ n: Notification) {
            guard let pv = n.object as? PDFView else { return }
            let s = pv.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DispatchQueue.main.async { self.parent.selectedText = s }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
#endif
