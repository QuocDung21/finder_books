import SwiftUI
import PDFKit

// =============================================================================
// CROSS-DEVICE INKING ENGINE
//
// COORDINATE SYSTEM:
// - InkPoint(x, y) stores normalized coordinates [0.0, 1.0] across the PDF page:
//     x = 0.0 at Left edge, 1.0 at Right edge
//     y = 0.0 at TOP edge (natural reading order), 1.0 at BOTTOM edge
//
// PLATFORM ADAPTATION:
// - macOS AppKit PDFView:
//     pdfView.convert(to: page) has Y = 0 at BOTTOM of page (CoreGraphics / AppKit).
//     Input:  ny = (pageBounds.maxY - pdfPt.y) / pageBounds.height  [Invert bottom-Y to top-Y]
//     Render: pdfY = pageBounds.maxY - (ny * pageBounds.height)      [Invert top-Y to bottom-Y]
//
// - iOS UIKit PDFView:
//     pdfView.convert(to: page) ALREADY has Y = 0 at TOP of page (UIKit flipped).
//     Input:  ny = (pdfPt.y - pageBounds.minY) / pageBounds.height  [Direct Top-Y]
//     Render: pdfY = ny * pageBounds.height + pageBounds.minY        [Direct Top-Y]
// =============================================================================

#if os(macOS)
import AppKit

// MARK: - macOS InkingPDFView
class InkingPDFView: PDFView {
    var isDrawingEnabled: Bool = false
    var activeColor: NSColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false

    private(set) lazy var inkOverlay: MacInkOverlay = {
        let v = MacInkOverlay(pdfView: self)
        v.autoresizingMask = [.width, .height]
        return v
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }

    private func setupOverlay() {
        addSubview(inkOverlay)
        inkOverlay.frame = bounds
    }

    override func layout() {
        super.layout()
        inkOverlay.frame = bounds
        inkOverlay.needsDisplay = true
    }

    func redrawInking() {
        inkOverlay.needsDisplay = true
    }
}

// MARK: - macOS Ink Overlay
class MacInkOverlay: NSView {
    weak var pdfView: InkingPDFView?

    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0

    init(pdfView: InkingPDFView) {
        self.pdfView = pdfView
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let pv = pdfView, pv.isDrawingEnabled else { return nil }
        return self
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let pv = pdfView, let doc = pv.document else { return }
        let sm = LiveCompanionSyncManager.shared

        for page in pv.visiblePages {
            let idx = doc.index(for: page)
            let pageBounds = page.bounds(for: .cropBox)
            guard pageBounds.width > 0, pageBounds.height > 0 else { continue }
            guard let strokes = sm.pageStrokes[idx], !strokes.isEmpty else { continue }

            for stroke in strokes {
                renderStroke(stroke, page: page, pageBounds: pageBounds, pv: pv)
            }
        }

        // Render in-progress drawing stroke
        if currentPoints.count > 1, let page = currentPageForDrawing {
            let pageBounds = page.bounds(for: .cropBox)
            guard pageBounds.width > 0, pageBounds.height > 0 else { return }

            let path = NSBezierPath()
            path.lineWidth = pv.activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            let first = currentPoints[0]
            let firstPdfX = first.x * pageBounds.width + pageBounds.minX
            let firstPdfY = pageBounds.maxY - (first.y * pageBounds.height)
            path.move(to: pv.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page))

            for pt in currentPoints.dropFirst() {
                let pdfX = pt.x * pageBounds.width + pageBounds.minX
                let pdfY = pageBounds.maxY - (pt.y * pageBounds.height)
                path.line(to: pv.convert(CGPoint(x: pdfX, y: pdfY), from: page))
            }

            pv.activeColor.withAlphaComponent(pv.isHighlighter ? 0.35 : 1.0).setStroke()
            path.stroke()
        }
    }

    private func renderStroke(_ stroke: LiveInkStroke, page: PDFPage, pageBounds: CGRect, pv: PDFView) {
        guard stroke.points.count > 1, let first = stroke.points.first else { return }

        let path = NSBezierPath()
        path.lineWidth = stroke.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let firstPdfX = first.x * pageBounds.width + pageBounds.minX
        let firstPdfY = pageBounds.maxY - (first.y * pageBounds.height)
        path.move(to: pv.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page))

        for pt in stroke.points.dropFirst() {
            let pdfX = pt.x * pageBounds.width + pageBounds.minX
            let pdfY = pageBounds.maxY - (pt.y * pageBounds.height)
            path.line(to: pv.convert(CGPoint(x: pdfX, y: pdfY), from: page))
        }

        (NSColor(hex: stroke.colorHex) ?? .red).withAlphaComponent(stroke.opacity).setStroke()
        path.stroke()
    }

    // MARK: Mouse Handling
    override func mouseDown(with event: NSEvent) {
        guard let pv = pdfView, pv.isDrawingEnabled, let doc = pv.document else {
            super.mouseDown(with: event)
            return
        }
        let loc = convert(event.locationInWindow, from: nil)
        guard let page = pv.page(for: loc, nearest: true) else {
            super.mouseDown(with: event)
            return
        }
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }

        let pdfPt = pv.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPt.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pageBounds.maxY - pdfPt.y) / pageBounds.height))

        currentPageForDrawing = page
        currentPageIndexForDrawing = doc.index(for: page)
        currentPoints = [InkPoint(x: nx, y: ny)]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pv = pdfView, pv.isDrawingEnabled, let page = currentPageForDrawing else {
            super.mouseDragged(with: event)
            return
        }
        let loc = convert(event.locationInWindow, from: nil)
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }

        let pdfPt = pv.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPt.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pageBounds.maxY - pdfPt.y) / pageBounds.height))

        currentPoints.append(InkPoint(x: nx, y: ny))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let pv = pdfView, pv.isDrawingEnabled, currentPoints.count > 1 else {
            currentPoints.removeAll()
            currentPageForDrawing = nil
            needsDisplay = true
            if !(pdfView?.isDrawingEnabled ?? false) { super.mouseUp(with: event) }
            return
        }

        let stroke = LiveInkStroke(
            pageIndex: currentPageIndexForDrawing,
            points: currentPoints,
            colorHex: pv.activeColor.toHex() ?? "#FF0000",
            lineWidth: pv.activeLineWidth,
            opacity: pv.isHighlighter ? 0.35 : 1.0,
            isHighlighter: pv.isHighlighter
        )

        currentPoints.removeAll()
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
        let pv = InkingPDFView()
        pv.autoresizingMask = [.width, .height]
        pv.autoScales = autoScales
        pv.displayMode = displayMode
        pv.displayDirection = .vertical
        pv.displaysPageBreaks = true
        pv.backgroundColor = NSColor.windowBackgroundColor

        if let doc = PDFDocument(url: url) {
            pv.document = doc
            DispatchQueue.main.async {
                self.totalPages = doc.pageCount
                if currentPageIndex < doc.pageCount, let pg = doc.page(at: currentPageIndex) {
                    pv.go(to: pg)
                }
            }
        }

        let c = context.coordinator
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.pageChanged(_:)), name: .PDFViewPageChanged, object: pv)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.selectionChanged(_:)), name: .PDFViewSelectionChanged, object: pv)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.redraw), name: .PDFViewScaleChanged, object: pv)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.redraw), name: Notification.Name("LiveCompanionStrokesUpdated"), object: nil)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.redraw), name: .PDFViewVisiblePagesChanged, object: pv)
        
        c.pdfView = pv
        return pv
    }

    func updateNSView(_ pv: InkingPDFView, context: Context) {
        context.coordinator.parent = self
        pv.isDrawingEnabled = isDrawingEnabled
        pv.activeColor = NSColor(activeColor)
        pv.activeLineWidth = activeLineWidth
        pv.isHighlighter = isHighlighter

        if pv.document?.documentURL != url, let doc = PDFDocument(url: url) {
            pv.document = doc
            self.totalPages = doc.pageCount
        }
        if pv.displayMode != displayMode { pv.displayMode = displayMode }
        if pv.autoScales != autoScales { pv.autoScales = autoScales }
        if !autoScales && scaleFactor > 0 && abs(pv.scaleFactor - scaleFactor) > 0.05 {
            pv.scaleFactor = scaleFactor
        }
        if let doc = pv.document, let cur = pv.currentPage,
           doc.index(for: cur) != currentPageIndex,
           currentPageIndex >= 0 && currentPageIndex < doc.pageCount,
           let tgt = doc.page(at: currentPageIndex) {
            pv.go(to: tgt)
        }
        pv.redrawInking()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: PDFKitReaderView
        weak var pdfView: InkingPDFView?

        init(_ p: PDFKitReaderView) { self.parent = p }

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

    private(set) lazy var inkOverlay: IOSInkOverlay = {
        let v = IOSInkOverlay(pdfView: self)
        v.backgroundColor = .clear
        v.isOpaque = false
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }

    private func setupOverlay() {
        addSubview(inkOverlay)
        inkOverlay.frame = bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bringSubviewToFront(inkOverlay)
        inkOverlay.frame = bounds
        inkOverlay.setNeedsDisplay()
    }

    func redrawInking() {
        inkOverlay.setNeedsDisplay()
    }

    private func updateScrollLock() {
        for sub in subviews where sub is UIScrollView {
            (sub as! UIScrollView).isScrollEnabled = !isDrawingEnabled
        }
    }
}

// MARK: - iOS Ink Overlay
class IOSInkOverlay: UIView {
    weak var pdfView: InkingPDFView?

    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0

    init(pdfView: InkingPDFView) {
        self.pdfView = pdfView
        super.init(frame: .zero)
        isMultipleTouchEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return pdfView?.isDrawingEnabled ?? false
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let pv = pdfView, let doc = pv.document else { return }
        let sm = LiveCompanionSyncManager.shared

        for page in pv.visiblePages {
            let idx = doc.index(for: page)
            let pageBounds = page.bounds(for: .cropBox)
            guard pageBounds.width > 0, pageBounds.height > 0 else { continue }
            guard let strokes = sm.pageStrokes[idx], !strokes.isEmpty else { continue }

            for stroke in strokes {
                renderStroke(stroke, page: page, pageBounds: pageBounds, pv: pv)
            }
        }

        // Render in-progress drawing stroke
        if currentPoints.count > 1, let page = currentPageForDrawing {
            let pageBounds = page.bounds(for: .cropBox)
            guard pageBounds.width > 0, pageBounds.height > 0 else { return }

            let path = UIBezierPath()
            path.lineWidth = pv.activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            let first = currentPoints[0]
            let firstPdfX = first.x * pageBounds.width + pageBounds.minX
            let firstPdfY = first.y * pageBounds.height + pageBounds.minY
            path.move(to: pv.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page))

            for pt in currentPoints.dropFirst() {
                let pdfX = pt.x * pageBounds.width + pageBounds.minX
                let pdfY = pt.y * pageBounds.height + pageBounds.minY
                path.addLine(to: pv.convert(CGPoint(x: pdfX, y: pdfY), from: page))
            }

            pv.activeColor.withAlphaComponent(pv.isHighlighter ? 0.35 : 1.0).setStroke()
            path.stroke()
        }
    }

    private func renderStroke(_ stroke: LiveInkStroke, page: PDFPage, pageBounds: CGRect, pv: PDFView) {
        guard stroke.points.count > 1, let first = stroke.points.first else { return }

        let path = UIBezierPath()
        path.lineWidth = stroke.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let firstPdfX = first.x * pageBounds.width + pageBounds.minX
        let firstPdfY = first.y * pageBounds.height + pageBounds.minY
        path.move(to: pv.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page))

        for pt in stroke.points.dropFirst() {
            let pdfX = pt.x * pageBounds.width + pageBounds.minX
            let pdfY = pt.y * pageBounds.height + pageBounds.minY
            path.addLine(to: pv.convert(CGPoint(x: pdfX, y: pdfY), from: page))
        }

        (UIColor(hex: stroke.colorHex) ?? .red).withAlphaComponent(stroke.opacity).setStroke()
        path.stroke()
    }

    // MARK: Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pv = pdfView, pv.isDrawingEnabled, let doc = pv.document, let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }
        let loc = touch.location(in: pv)
        guard let page = pv.page(for: loc, nearest: true) else {
            super.touchesBegan(touches, with: event)
            return
        }
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }

        let pdfPt = pv.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPt.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pdfPt.y - pageBounds.minY) / pageBounds.height))

        currentPageForDrawing = page
        currentPageIndexForDrawing = doc.index(for: page)
        currentPoints = [InkPoint(x: nx, y: ny)]
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pv = pdfView, pv.isDrawingEnabled, let page = currentPageForDrawing, let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }
        let loc = touch.location(in: pv)
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }

        let pdfPt = pv.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPt.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pdfPt.y - pageBounds.minY) / pageBounds.height))

        currentPoints.append(InkPoint(x: nx, y: ny))
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pv = pdfView, pv.isDrawingEnabled, currentPoints.count > 1 else {
            currentPoints.removeAll()
            currentPageForDrawing = nil
            setNeedsDisplay()
            if !(pdfView?.isDrawingEnabled ?? false) { super.touchesEnded(touches, with: event) }
            return
        }

        let stroke = LiveInkStroke(
            pageIndex: currentPageIndexForDrawing,
            points: currentPoints,
            colorHex: pv.activeColor.toHex() ?? "#FF0000",
            lineWidth: pv.activeLineWidth,
            opacity: pv.isHighlighter ? 0.35 : 1.0,
            isHighlighter: pv.isHighlighter
        )

        currentPoints.removeAll()
        currentPageForDrawing = nil
        LiveCompanionSyncManager.shared.broadcastNewStroke(stroke)
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentPoints.removeAll()
        currentPageForDrawing = nil
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
        let pv = InkingPDFView()
        pv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pv.autoScales = autoScales
        pv.displayMode = displayMode
        pv.displayDirection = .vertical
        pv.displaysPageBreaks = true
        pv.backgroundColor = UIColor.systemBackground

        if let doc = PDFDocument(url: url) {
            pv.document = doc
            DispatchQueue.main.async {
                self.totalPages = doc.pageCount
                if currentPageIndex < doc.pageCount, let pg = doc.page(at: currentPageIndex) {
                    pv.go(to: pg)
                }
            }
        }

        let c = context.coordinator
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.pageChanged(_:)), name: .PDFViewPageChanged, object: pv)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.selectionChanged(_:)), name: .PDFViewSelectionChanged, object: pv)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.redraw), name: .PDFViewScaleChanged, object: pv)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.redraw), name: Notification.Name("LiveCompanionStrokesUpdated"), object: nil)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.redraw), name: .PDFViewVisiblePagesChanged, object: pv)

        c.pdfView = pv
        return pv
    }

    func updateUIView(_ pv: InkingPDFView, context: Context) {
        context.coordinator.parent = self
        pv.isDrawingEnabled = isDrawingEnabled
        pv.activeColor = UIColor(activeColor)
        pv.activeLineWidth = activeLineWidth
        pv.isHighlighter = isHighlighter

        if pv.document?.documentURL != url, let doc = PDFDocument(url: url) {
            pv.document = doc
            self.totalPages = doc.pageCount
        }
        if pv.displayMode != displayMode { pv.displayMode = displayMode }
        if pv.autoScales != autoScales { pv.autoScales = autoScales }
        if !autoScales && scaleFactor > 0 && abs(pv.scaleFactor - scaleFactor) > 0.05 {
            pv.scaleFactor = scaleFactor
        }
        if let doc = pv.document, let cur = pv.currentPage,
           doc.index(for: cur) != currentPageIndex,
           currentPageIndex >= 0 && currentPageIndex < doc.pageCount,
           let tgt = doc.page(at: currentPageIndex) {
            pv.go(to: tgt)
        }
        pv.redrawInking()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: PDFKitReaderView
        weak var pdfView: InkingPDFView?

        init(_ p: PDFKitReaderView) { self.parent = p }

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
