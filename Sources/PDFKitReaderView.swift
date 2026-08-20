import SwiftUI
import PDFKit

#if os(macOS)
import AppKit

struct PDFKitReaderView: NSViewRepresentable {
    let url: URL
    @Binding var currentPageIndex: Int
    @Binding var totalPages: Int
    @Binding var displayMode: PDFDisplayMode
    @Binding var scaleFactor: CGFloat
    @Binding var autoScales: Bool
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
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
        
        context.coordinator.pdfView = pdfView
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitReaderView
        weak var pdfView: PDFView?
        
        init(_ parent: PDFKitReaderView) {
            self.parent = parent
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
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#elseif os(iOS)
import UIKit

struct PDFKitReaderView: UIViewRepresentable {
    let url: URL
    @Binding var currentPageIndex: Int
    @Binding var totalPages: Int
    @Binding var displayMode: PDFDisplayMode
    @Binding var scaleFactor: CGFloat
    @Binding var autoScales: Bool
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
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
        
        context.coordinator.pdfView = pdfView
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
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
        weak var pdfView: PDFView?
        
        init(_ parent: PDFKitReaderView) {
            self.parent = parent
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
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#endif
