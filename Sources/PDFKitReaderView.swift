import SwiftUI
import PDFKit

#if os(macOS)
import AppKit

// MARK: - Native macOS Inking PDFView (Pixel-Perfect with pdfView.convert)
class InkingPDFView: PDFView {
    var isDrawingEnabled: Bool = false
    var activeColor: NSColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false
    
    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0
    
    private lazy var overlayView: MacOSInkingOverlayView = {
        let view = MacOSInkingOverlayView(parentPDFView: self)
        view.autoresizingMask = [.width, .height]
        return view
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
        addSubview(overlayView)
        overlayView.frame = bounds
    }
    
    override func layout() {
        super.layout()
        overlayView.frame = bounds
        overlayView.needsDisplay = true
    }
    
    func redrawInking() {
        overlayView.needsDisplay = true
    }
}

// MARK: - macOS Inking Overlay View
class MacOSInkingOverlayView: NSView {
    weak var parentPDFView: InkingPDFView?
    
    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0
    
    init(parentPDFView: InkingPDFView) {
        self.parentPDFView = parentPDFView
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let parent = parentPDFView, parent.isDrawingEnabled else { return nil }
        return self
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let parent = parentPDFView, let doc = parent.document else { return }
        let syncManager = LiveCompanionSyncManager.shared
        
        let visiblePages = parent.visiblePages
        for page in visiblePages {
            let pageIndex = doc.index(for: page)
            let pageBounds = page.bounds(for: .cropBox)
            guard pageBounds.width > 0, pageBounds.height > 0 else { continue }
            guard let strokes = syncManager.pageStrokes[pageIndex], !strokes.isEmpty else { continue }
            
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                let firstPdfX = first.x * pageBounds.width + pageBounds.minX
                let firstPdfY = pageBounds.maxY - (first.y * pageBounds.height)
                let firstScreenPoint = parent.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page)
                
                let path = NSBezierPath()
                path.lineWidth = stroke.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: firstScreenPoint)
                
                for pt in stroke.points.dropFirst() {
                    let pdfX = pt.x * pageBounds.width + pageBounds.minX
                    let pdfY = pageBounds.maxY - (pt.y * pageBounds.height)
                    let screenPoint = parent.convert(CGPoint(x: pdfX, y: pdfY), from: page)
                    path.line(to: screenPoint)
                }
                
                let col = NSColor(hex: stroke.colorHex) ?? .red
                col.withAlphaComponent(stroke.opacity).setStroke()
                path.stroke()
            }
        }
        
        // Draw in-progress live drawing stroke
        if !currentPoints.isEmpty, let page = currentPageForDrawing, let first = currentPoints.first {
            let pageBounds = page.bounds(for: .cropBox)
            let firstPdfX = first.x * pageBounds.width + pageBounds.minX
            let firstPdfY = pageBounds.maxY - (first.y * pageBounds.height)
            let firstScreenPoint = parent.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page)
            
            let path = NSBezierPath()
            path.lineWidth = parent.activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: firstScreenPoint)
            
            for pt in currentPoints.dropFirst() {
                let pdfX = pt.x * pageBounds.width + pageBounds.minX
                let pdfY = pageBounds.maxY - (pt.y * pageBounds.height)
                let screenPoint = parent.convert(CGPoint(x: pdfX, y: pdfY), from: page)
                path.line(to: screenPoint)
            }
            
            let col = parent.activeColor.withAlphaComponent(parent.isHighlighter ? 0.35 : 1.0)
            col.setStroke()
            path.stroke()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, let doc = parent.document else {
            super.mouseDown(with: event)
            return
        }
        
        let loc = convert(event.locationInWindow, from: nil)
        guard let page = parent.page(for: loc, nearest: true) else {
            super.mouseDown(with: event)
            return
        }
        
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        
        let pdfPoint = parent.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pageBounds.maxY - pdfPoint.y) / pageBounds.height))
        
        currentPageForDrawing = page
        currentPageIndexForDrawing = doc.index(for: page)
        currentPoints = [InkPoint(x: nx, y: ny)]
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, let page = currentPageForDrawing else {
            super.mouseDragged(with: event)
            return
        }
        
        let loc = convert(event.locationInWindow, from: nil)
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        
        let pdfPoint = parent.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pageBounds.maxY - pdfPoint.y) / pageBounds.height))
        
        currentPoints.append(InkPoint(x: nx, y: ny))
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, currentPoints.count > 1 else {
            currentPoints.removeAll()
            currentPageForDrawing = nil
            needsDisplay = true
            super.mouseUp(with: event)
            return
        }
        
        let stroke = LiveInkStroke(
            pageIndex: currentPageIndexForDrawing,
            points: currentPoints,
            colorHex: parent.activeColor.toHex() ?? "#FF0000",
            lineWidth: parent.activeLineWidth,
            opacity: parent.isHighlighter ? 0.35 : 1.0,
            isHighlighter: parent.isHighlighter
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
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.redrawOverlay),
            name: .PDFViewScaleChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.redrawOverlay),
            name: NSNotification.Name("LiveCompanionStrokesUpdated"),
            object: nil
        )
        
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
        
        if pdfView.displayMode != displayMode {
            pdfView.displayMode = displayMode
        }
        
        if pdfView.autoScales != autoScales {
            pdfView.autoScales = autoScales
        }
        
        if !autoScales && scaleFactor > 0 && abs(pdfView.scaleFactor - scaleFactor) > 0.05 {
            pdfView.scaleFactor = scaleFactor
        }
        
        // Jump to page if user changed currentPageIndex externally
        if let doc = pdfView.document,
           let currentPage = pdfView.currentPage,
           doc.index(for: currentPage) != currentPageIndex,
           currentPageIndex >= 0 && currentPageIndex < doc.pageCount,
           let targetPage = doc.page(at: currentPageIndex) {
            pdfView.go(to: targetPage)
        }
        
        pdfView.redrawInking()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitReaderView
        weak var pdfView: InkingPDFView?
        
        init(_ parent: PDFKitReaderView) {
            self.parent = parent
        }
        
        @objc func redrawOverlay() {
            pdfView?.redrawInking()
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let doc = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            
            let index = doc.index(for: currentPage)
            if index != parent.currentPageIndex {
                DispatchQueue.main.async {
                    self.parent.currentPageIndex = index
                }
            }
            self.pdfView?.redrawInking()
        }
        
        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            let sel = pdfView.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DispatchQueue.main.async {
                self.parent.selectedText = sel
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#elseif os(iOS)
import UIKit

// MARK: - Native iOS Inking PDFView (Pixel-Perfect with pdfView.convert & Apple Pencil)
class InkingPDFView: PDFView {
    var isDrawingEnabled: Bool = false {
        didSet {
            updateScrollLock()
        }
    }
    var activeColor: UIColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false
    
    private lazy var overlayView: InkingOverlayDrawingView = {
        let view = InkingOverlayDrawingView(parentPDFView: self)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
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
        addSubview(overlayView)
        overlayView.frame = bounds
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        overlayView.frame = bounds
        overlayView.setNeedsDisplay()
    }
    
    func redrawInking() {
        overlayView.setNeedsDisplay()
    }
    
    private func updateScrollLock() {
        // Find internal UIScrollView in PDFView to lock page scrolling while drawing
        for sub in self.subviews {
            if let scroll = sub as? UIScrollView {
                scroll.isScrollEnabled = !isDrawingEnabled
            }
        }
    }
}

// MARK: - iOS Drawing Overlay View
class InkingOverlayDrawingView: UIView {
    weak var parentPDFView: InkingPDFView?
    
    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0
    
    init(parentPDFView: InkingPDFView) {
        self.parentPDFView = parentPDFView
        super.init(frame: .zero)
        isMultipleTouchEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let parent = parentPDFView else { return false }
        return parent.isDrawingEnabled
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let parent = parentPDFView, let doc = parent.document else { return }
        let syncManager = LiveCompanionSyncManager.shared
        
        let visiblePages = parent.visiblePages
        for page in visiblePages {
            let pageIndex = doc.index(for: page)
            let pageBounds = page.bounds(for: .cropBox)
            guard pageBounds.width > 0, pageBounds.height > 0 else { continue }
            guard let strokes = syncManager.pageStrokes[pageIndex], !strokes.isEmpty else { continue }
            
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                let firstPdfX = first.x * pageBounds.width + pageBounds.minX
                let firstPdfY = pageBounds.maxY - (first.y * pageBounds.height)
                let firstScreenPoint = parent.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page)
                
                let path = UIBezierPath()
                path.lineWidth = stroke.lineWidth
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.move(to: firstScreenPoint)
                
                for pt in stroke.points.dropFirst() {
                    let pdfX = pt.x * pageBounds.width + pageBounds.minX
                    let pdfY = pageBounds.maxY - (pt.y * pageBounds.height)
                    let screenPt = parent.convert(CGPoint(x: pdfX, y: pdfY), from: page)
                    path.addLine(to: screenPt)
                }
                
                let col = UIColor(hex: stroke.colorHex) ?? .red
                col.withAlphaComponent(stroke.opacity).setStroke()
                path.stroke()
            }
        }
        
        // Draw in-progress live drawing stroke
        if !currentPoints.isEmpty, let page = currentPageForDrawing, let first = currentPoints.first {
            let pageBounds = page.bounds(for: .cropBox)
            let firstPdfX = first.x * pageBounds.width + pageBounds.minX
            let firstPdfY = pageBounds.maxY - (first.y * pageBounds.height)
            let firstScreenPoint = parent.convert(CGPoint(x: firstPdfX, y: firstPdfY), from: page)
            
            let path = UIBezierPath()
            path.lineWidth = parent.activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: firstScreenPoint)
            
            for pt in currentPoints.dropFirst() {
                let pdfX = pt.x * pageBounds.width + pageBounds.minX
                let pdfY = pageBounds.maxY - (pt.y * pageBounds.height)
                let screenPt = parent.convert(CGPoint(x: pdfX, y: pdfY), from: page)
                path.addLine(to: screenPt)
            }
            
            let col = parent.activeColor.withAlphaComponent(parent.isHighlighter ? 0.35 : 1.0)
            col.setStroke()
            path.stroke()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, let doc = parent.document, let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }
        
        let loc = touch.location(in: parent)
        guard let page = parent.page(for: loc, nearest: true) else {
            super.touchesBegan(touches, with: event)
            return
        }
        
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        
        let pdfPoint = parent.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pageBounds.maxY - pdfPoint.y) / pageBounds.height))
        
        currentPageForDrawing = page
        currentPageIndexForDrawing = doc.index(for: page)
        currentPoints = [InkPoint(x: nx, y: ny)]
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, let page = currentPageForDrawing, let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }
        
        let loc = touch.location(in: parent)
        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        
        let pdfPoint = parent.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pageBounds.maxY - pdfPoint.y) / pageBounds.height))
        
        currentPoints.append(InkPoint(x: nx, y: ny))
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, currentPoints.count > 1 else {
            currentPoints.removeAll()
            currentPageForDrawing = nil
            setNeedsDisplay()
            super.touchesEnded(touches, with: event)
            return
        }
        
        let stroke = LiveInkStroke(
            pageIndex: currentPageIndexForDrawing,
            points: currentPoints,
            colorHex: parent.activeColor.toHex() ?? "#FF0000",
            lineWidth: parent.activeLineWidth,
            opacity: parent.isHighlighter ? 0.35 : 1.0,
            isHighlighter: parent.isHighlighter
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
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.redrawOverlay),
            name: .PDFViewScaleChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.redrawOverlay),
            name: NSNotification.Name("LiveCompanionStrokesUpdated"),
            object: nil
        )
        
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
        
        if pdfView.displayMode != displayMode {
            pdfView.displayMode = displayMode
        }
        
        if pdfView.autoScales != autoScales {
            pdfView.autoScales = autoScales
        }
        
        if !autoScales && scaleFactor > 0 && abs(pdfView.scaleFactor - scaleFactor) > 0.05 {
            pdfView.scaleFactor = scaleFactor
        }
        
        // Jump to page if user changed currentPageIndex externally
        if let doc = pdfView.document,
           let currentPage = pdfView.currentPage,
           doc.index(for: currentPage) != currentPageIndex,
           currentPageIndex >= 0 && currentPageIndex < doc.pageCount,
           let targetPage = doc.page(at: currentPageIndex) {
            pdfView.go(to: targetPage)
        }
        
        pdfView.redrawInking()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitReaderView
        weak var pdfView: InkingPDFView?
        
        init(_ parent: PDFKitReaderView) {
            self.parent = parent
        }
        
        @objc func redrawOverlay() {
            pdfView?.redrawInking()
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let doc = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            
            let index = doc.index(for: currentPage)
            if index != parent.currentPageIndex {
                DispatchQueue.main.async {
                    self.parent.currentPageIndex = index
                }
            }
            self.pdfView?.redrawInking()
        }
        
        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            let sel = pdfView.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DispatchQueue.main.async {
                self.parent.selectedText = sel
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#endif
