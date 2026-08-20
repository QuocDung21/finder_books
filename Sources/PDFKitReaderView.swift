import SwiftUI
import PDFKit

#if os(macOS)
import AppKit

// MARK: - Native macOS PDF Page Inking Overlay (Pixel-Perfect per PDF Page)
class PageInkingOverlayNSView: NSView {
    var pageIndex: Int = 0
    var isDrawingEnabled: Bool = false
    var activeColor: NSColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false
    
    override var isFlipped: Bool { true }
    
    private var currentPoints: [InkPoint] = []
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }
        
        let strokes = LiveCompanionSyncManager.shared.pageStrokes[pageIndex] ?? []
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            let path = NSBezierPath()
            path.lineWidth = stroke.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: NSPoint(x: first.x * w, y: first.y * h))
            for pt in stroke.points.dropFirst() {
                path.line(to: NSPoint(x: pt.x * w, y: pt.y * h))
            }
            let col = NSColor(hex: stroke.colorHex) ?? .red
            col.withAlphaComponent(stroke.opacity).setStroke()
            path.stroke()
        }
        
        if !currentPoints.isEmpty, let first = currentPoints.first {
            let path = NSBezierPath()
            path.lineWidth = activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: NSPoint(x: first.x * w, y: first.y * h))
            for pt in currentPoints.dropFirst() {
                path.line(to: NSPoint(x: pt.x * w, y: pt.y * h))
            }
            let col = activeColor.withAlphaComponent(isHighlighter ? 0.35 : 1.0)
            col.setStroke()
            path.stroke()
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if isDrawingEnabled {
            return self
        }
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isDrawingEnabled else { super.mouseDown(with: event); return }
        let loc = convert(event.locationInWindow, from: nil)
        let nx = max(0, min(1, loc.x / bounds.width))
        let ny = max(0, min(1, loc.y / bounds.height))
        currentPoints = [InkPoint(x: nx, y: ny)]
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDrawingEnabled else { super.mouseDragged(with: event); return }
        let loc = convert(event.locationInWindow, from: nil)
        let nx = max(0, min(1, loc.x / bounds.width))
        let ny = max(0, min(1, loc.y / bounds.height))
        currentPoints.append(InkPoint(x: nx, y: ny))
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDrawingEnabled, currentPoints.count > 1 else {
            currentPoints.removeAll()
            needsDisplay = true
            super.mouseUp(with: event)
            return
        }
        let stroke = LiveInkStroke(
            pageIndex: pageIndex,
            points: currentPoints,
            colorHex: activeColor.toHex() ?? "#FF0000",
            lineWidth: activeLineWidth,
            opacity: isHighlighter ? 0.35 : 1.0,
            isHighlighter: isHighlighter
        )
        currentPoints.removeAll()
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
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = autoScales
        pdfView.displayMode = displayMode
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        
        pdfView.pageOverlayViewProvider = context.coordinator
        
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
        
        context.coordinator.pdfView = pdfView
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
        
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
        
        // Update all active overlay properties
        for overlay in context.coordinator.activeOverlays.values {
            overlay.isDrawingEnabled = isDrawingEnabled
            overlay.activeColor = NSColor(activeColor)
            overlay.activeLineWidth = activeLineWidth
            overlay.isHighlighter = isHighlighter
            overlay.needsDisplay = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFPageOverlayViewProvider {
        var parent: PDFKitReaderView
        weak var pdfView: PDFView?
        var activeOverlays: [Int: PageInkingOverlayNSView] = [:]
        
        init(_ parent: PDFKitReaderView) {
            self.parent = parent
        }
        
        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> NSView? {
            guard let doc = view.document else { return nil }
            let index = doc.index(for: page)
            let overlay = PageInkingOverlayNSView()
            overlay.pageIndex = index
            overlay.isDrawingEnabled = parent.isDrawingEnabled
            overlay.activeColor = NSColor(parent.activeColor)
            overlay.activeLineWidth = parent.activeLineWidth
            overlay.isHighlighter = parent.isHighlighter
            activeOverlays[index] = overlay
            return overlay
        }
        
        func pdfView(_ view: PDFView, willEndDisplayingOverlayView overlayView: NSView, for page: PDFPage) {
            guard let doc = view.document else { return }
            let index = doc.index(for: page)
            activeOverlays.removeValue(forKey: index)
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

// MARK: - Native iOS PDF Page Inking Overlay (Pixel-Perfect per PDF Page with Apple Pencil)
class PageInkingOverlayUIView: UIView {
    var pageIndex: Int = 0
    var isDrawingEnabled: Bool = false
    var activeColor: UIColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false
    
    private var currentPoints: [InkPoint] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }
        
        let strokes = LiveCompanionSyncManager.shared.pageStrokes[pageIndex] ?? []
        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            let path = UIBezierPath()
            path.lineWidth = stroke.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(x: first.x * w, y: first.y * h))
            for pt in stroke.points.dropFirst() {
                path.addLine(to: CGPoint(x: pt.x * w, y: pt.y * h))
            }
            let col = UIColor(hex: stroke.colorHex) ?? .red
            col.withAlphaComponent(stroke.opacity).setStroke()
            path.stroke()
        }
        
        if !currentPoints.isEmpty, let first = currentPoints.first {
            let path = UIBezierPath()
            path.lineWidth = activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: CGPoint(x: first.x * w, y: first.y * h))
            for pt in currentPoints.dropFirst() {
                path.addLine(to: CGPoint(x: pt.x * w, y: pt.y * h))
            }
            let col = activeColor.withAlphaComponent(isHighlighter ? 0.35 : 1.0)
            col.setStroke()
            path.stroke()
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return isDrawingEnabled
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }
        let loc = touch.location(in: self)
        let nx = max(0, min(1, loc.x / bounds.width))
        let ny = max(0, min(1, loc.y / bounds.height))
        currentPoints = [InkPoint(x: nx, y: ny)]
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }
        let loc = touch.location(in: self)
        let nx = max(0, min(1, loc.x / bounds.width))
        let ny = max(0, min(1, loc.y / bounds.height))
        currentPoints.append(InkPoint(x: nx, y: ny))
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawingEnabled, currentPoints.count > 1 else {
            currentPoints.removeAll()
            setNeedsDisplay()
            super.touchesEnded(touches, with: event)
            return
        }
        let stroke = LiveInkStroke(
            pageIndex: pageIndex,
            points: currentPoints,
            colorHex: activeColor.toHex() ?? "#FF0000",
            lineWidth: activeLineWidth,
            opacity: isHighlighter ? 0.35 : 1.0,
            isHighlighter: isHighlighter
        )
        currentPoints.removeAll()
        LiveCompanionSyncManager.shared.broadcastNewStroke(stroke)
        setNeedsDisplay()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentPoints.removeAll()
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
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pdfView.autoScales = autoScales
        pdfView.displayMode = displayMode
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = UIColor.systemBackground
        
        pdfView.pageOverlayViewProvider = context.coordinator
        
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
        
        context.coordinator.pdfView = pdfView
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
        
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
        
        // Update all active overlay properties
        for overlay in context.coordinator.activeOverlays.values {
            overlay.isDrawingEnabled = isDrawingEnabled
            overlay.activeColor = UIColor(activeColor)
            overlay.activeLineWidth = activeLineWidth
            overlay.isHighlighter = isHighlighter
            overlay.setNeedsDisplay()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFPageOverlayViewProvider {
        var parent: PDFKitReaderView
        weak var pdfView: PDFView?
        var activeOverlays: [Int: PageInkingOverlayUIView] = [:]
        
        init(_ parent: PDFKitReaderView) {
            self.parent = parent
        }
        
        func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
            guard let doc = view.document else { return nil }
            let index = doc.index(for: page)
            let overlay = PageInkingOverlayUIView()
            overlay.pageIndex = index
            overlay.isDrawingEnabled = parent.isDrawingEnabled
            overlay.activeColor = UIColor(parent.activeColor)
            overlay.activeLineWidth = parent.activeLineWidth
            overlay.isHighlighter = parent.isHighlighter
            activeOverlays[index] = overlay
            return overlay
        }
        
        func pdfView(_ view: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
            guard let doc = view.document else { return }
            let index = doc.index(for: page)
            activeOverlays.removeValue(forKey: index)
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
