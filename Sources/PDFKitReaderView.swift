import SwiftUI
import PDFKit

#if os(macOS)
import AppKit

// MARK: - Native macOS PDFView with Live Annotation Inking Engine
class InkingPDFView: PDFView {
    var isDrawingEnabled: Bool = false
    var activeColor: NSColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false
    
    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0
    private var activeDragOverlayPath: NSBezierPath? = nil
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Render in-progress active stroke overlay while user is dragging
        if isDrawingEnabled, let path = activeDragOverlayPath {
            let col = activeColor.withAlphaComponent(isHighlighter ? 0.35 : 1.0)
            col.setStroke()
            path.lineWidth = activeLineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isDrawingEnabled, let doc = document else {
            super.mouseDown(with: event)
            return
        }
        
        let loc = convert(event.locationInWindow, from: nil)
        guard let page = page(for: loc, nearest: true) else {
            super.mouseDown(with: event)
            return
        }
        
        let pageBounds = page.bounds(for: .cropBox)
        let pdfPoint = self.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pdfPoint.y - pageBounds.minY) / pageBounds.height))
        
        currentPageForDrawing = page
        currentPageIndexForDrawing = doc.index(for: page)
        currentPoints = [InkPoint(x: nx, y: ny)]
        
        activeDragOverlayPath = NSBezierPath()
        activeDragOverlayPath?.move(to: loc)
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDrawingEnabled, let page = currentPageForDrawing else {
            super.mouseDragged(with: event)
            return
        }
        
        let loc = convert(event.locationInWindow, from: nil)
        let pageBounds = page.bounds(for: .cropBox)
        let pdfPoint = self.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pdfPoint.y - pageBounds.minY) / pageBounds.height))
        
        currentPoints.append(InkPoint(x: nx, y: ny))
        activeDragOverlayPath?.line(to: loc)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDrawingEnabled, currentPoints.count > 1, let page = currentPageForDrawing else {
            currentPoints.removeAll()
            currentPageForDrawing = nil
            activeDragOverlayPath = nil
            needsDisplay = true
            super.mouseUp(with: event)
            return
        }
        
        let stroke = LiveInkStroke(
            pageIndex: currentPageIndexForDrawing,
            points: currentPoints,
            colorHex: activeColor.toHex() ?? "#FF0000",
            lineWidth: activeLineWidth,
            opacity: isHighlighter ? 0.35 : 1.0,
            isHighlighter: isHighlighter
        )
        
        currentPoints.removeAll()
        currentPageForDrawing = nil
        activeDragOverlayPath = nil
        
        // Broadcast and commit annotation to page
        LiveCompanionSyncManager.shared.broadcastNewStroke(stroke)
        PDFAnnotationHelper.applyStroke(stroke, to: page)
        needsDisplay = true
    }
    
    func syncAllAnnotations() {
        guard let doc = document else { return }
        let syncManager = LiveCompanionSyncManager.shared
        
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            // Remove existing ink annotations
            let existingInk = page.annotations.filter { $0.type == "Ink" }
            for ann in existingInk {
                page.removeAnnotation(ann)
            }
            
            // Re-apply strokes from sync manager
            if let strokes = syncManager.pageStrokes[i] {
                for s in strokes {
                    PDFAnnotationHelper.applyStroke(s, to: page)
                }
            }
        }
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
                pdfView.syncAllAnnotations()
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
            selector: #selector(Coordinator.strokesUpdated),
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
                pdfView.syncAllAnnotations()
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
        
        @objc func strokesUpdated() {
            pdfView?.syncAllAnnotations()
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

// MARK: - Native iOS PDFView with Live Annotation Inking Engine & Apple Pencil
class InkingPDFView: PDFView {
    var isDrawingEnabled: Bool = false
    var activeColor: UIColor = .red
    var activeLineWidth: CGFloat = 3.0
    var isHighlighter: Bool = false
    
    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0
    private var activeDragOverlayPath: UIBezierPath? = nil
    
    private lazy var overlayView: InkingTouchOverlayView = {
        let view = InkingTouchOverlayView(parentPDFView: self)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
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
        overlayView.frame = bounds
    }
    
    func syncAllAnnotations() {
        guard let doc = document else { return }
        let syncManager = LiveCompanionSyncManager.shared
        
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            // Remove existing ink annotations
            let existingInk = page.annotations.filter { $0.type == "Ink" }
            for ann in existingInk {
                page.removeAnnotation(ann)
            }
            
            // Re-apply strokes from sync manager
            if let strokes = syncManager.pageStrokes[i] {
                for s in strokes {
                    PDFAnnotationHelper.applyStroke(s, to: page)
                }
            }
        }
        overlayView.setNeedsDisplay()
    }
}

// MARK: - iOS Touch & In-Progress Preview Overlay
class InkingTouchOverlayView: UIView {
    weak var parentPDFView: InkingPDFView?
    
    private var currentPoints: [InkPoint] = []
    private var currentPageForDrawing: PDFPage? = nil
    private var currentPageIndexForDrawing: Int = 0
    private var activeDragOverlayPath: UIBezierPath? = nil
    
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
        guard let parent = parentPDFView, parent.isDrawingEnabled, let path = activeDragOverlayPath else { return }
        
        let col = parent.activeColor.withAlphaComponent(parent.isHighlighter ? 0.35 : 1.0)
        col.setStroke()
        path.lineWidth = parent.activeLineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
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
        let pdfPoint = parent.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pdfPoint.y - pageBounds.minY) / pageBounds.height))
        
        currentPageForDrawing = page
        currentPageIndexForDrawing = doc.index(for: page)
        currentPoints = [InkPoint(x: nx, y: ny)]
        
        activeDragOverlayPath = UIBezierPath()
        activeDragOverlayPath?.move(to: touch.location(in: self))
        setNeedsDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, let page = currentPageForDrawing, let touch = touches.first else {
            super.touchesMoved(touches, with: event)
            return
        }
        
        let loc = touch.location(in: parent)
        let pageBounds = page.bounds(for: .cropBox)
        let pdfPoint = parent.convert(loc, to: page)
        let nx = max(0, min(1, (pdfPoint.x - pageBounds.minX) / pageBounds.width))
        let ny = max(0, min(1, (pdfPoint.y - pageBounds.minY) / pageBounds.height))
        
        currentPoints.append(InkPoint(x: nx, y: ny))
        activeDragOverlayPath?.addLine(to: touch.location(in: self))
        setNeedsDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let parent = parentPDFView, parent.isDrawingEnabled, currentPoints.count > 1, let page = currentPageForDrawing else {
            currentPoints.removeAll()
            currentPageForDrawing = nil
            activeDragOverlayPath = nil
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
        activeDragOverlayPath = nil
        
        // Broadcast and commit annotation directly onto the PDF page
        LiveCompanionSyncManager.shared.broadcastNewStroke(stroke)
        PDFAnnotationHelper.applyStroke(stroke, to: page)
        setNeedsDisplay()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentPoints.removeAll()
        currentPageForDrawing = nil
        activeDragOverlayPath = nil
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
                pdfView.syncAllAnnotations()
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
            selector: #selector(Coordinator.strokesUpdated),
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
                pdfView.syncAllAnnotations()
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
        
        @objc func strokesUpdated() {
            pdfView?.syncAllAnnotations()
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

// MARK: - Cross-Platform PDFAnnotation Inking Helper
struct PDFAnnotationHelper {
    static func applyStroke(_ stroke: LiveInkStroke, to page: PDFPage) {
        let pageBounds = page.bounds(for: .cropBox)
        guard let first = stroke.points.first else { return }
        
        let firstPt = CGPoint(
            x: first.x * pageBounds.width + pageBounds.minX,
            y: first.y * pageBounds.height + pageBounds.minY
        )
        
        #if os(macOS)
        let path = NSBezierPath()
        path.lineWidth = stroke.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: firstPt)
        
        for pt in stroke.points.dropFirst() {
            let p = CGPoint(
                x: pt.x * pageBounds.width + pageBounds.minX,
                y: pt.y * pageBounds.height + pageBounds.minY
            )
            path.line(to: p)
        }
        
        let inkAnnotation = PDFAnnotation(bounds: pageBounds, forType: .ink, withProperties: nil)
        inkAnnotation.add(path)
        if let col = NSColor(hex: stroke.colorHex) {
            inkAnnotation.color = col.withAlphaComponent(stroke.opacity)
        }
        page.addAnnotation(inkAnnotation)
        
        #elseif os(iOS)
        let path = UIBezierPath()
        path.lineWidth = stroke.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: firstPt)
        
        for pt in stroke.points.dropFirst() {
            let p = CGPoint(
                x: pt.x * pageBounds.width + pageBounds.minX,
                y: pt.y * pageBounds.height + pageBounds.minY
            )
            path.addLine(to: p)
        }
        
        let inkAnnotation = PDFAnnotation(bounds: pageBounds, forType: .ink, withProperties: nil)
        inkAnnotation.add(path)
        if let col = UIColor(hex: stroke.colorHex) {
            inkAnnotation.color = col.withAlphaComponent(stroke.opacity)
        }
        page.addAnnotation(inkAnnotation)
        #endif
    }
}
