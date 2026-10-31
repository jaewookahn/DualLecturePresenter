import AppKit
import PDFKit
import SwiftUI

public enum PDFViewRole {
    case instructor
    case student
    case preview
}

@MainActor
public class InteractivePDFContainerView: NSView {
    public let pdfView = PDFView()
    private let overlayView = AnnotationCanvasView()
    
    public var role: PDFViewRole = .instructor
    public weak var model: PresenterModel?
    
    private var isPerformingSync = false
    private var trackingArea: NSTrackingArea?
    private var scrollObserver: NSObjectProtocol?
    private var pageObserver: NSObjectProtocol?
    private var scaleObserver: NSObjectProtocol?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = pageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = scaleObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupViews() {
        wantsLayer = true
        autoresizingMask = [.width, .height]
        
        pdfView.frame = bounds
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        addSubview(pdfView)
        
        overlayView.frame = bounds
        overlayView.autoresizingMask = [.width, .height]
        overlayView.wantsLayer = true
        overlayView.container = self
        addSubview(overlayView)
        
        setupTrackingArea()
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        if let area = trackingArea {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    public func configure(with model: PresenterModel, role: PDFViewRole) {
        self.model = model
        self.role = role
        self.overlayView.model = model
        
        let doc = (role == .instructor) ? model.instructorDoc : model.studentDoc
        if pdfView.document !== doc {
            pdfView.document = doc
        }
        
        pdfView.displayMode = model.displayMode
        pdfView.autoScales = model.autoScales
        
        // Setup observers only once or when role/document changes
        if scrollObserver == nil {
            scaleObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.overlayView.needsDisplay = true
                }
            }
            
            if role == .instructor {
                setupInstructorSyncHooks()
            } else if role == .student {
                setupStudentSyncHooks()
            }
        }
        
        // Page position sync for single-page mode (clicker, thumbnail, shortcut)
        if model.displayMode == .singlePage && model.pageCount > 0 && model.currentPageIndex < model.pageCount {
            if let curPage = pdfView.currentPage, let doc = doc {
                let currentIdx = doc.index(for: curPage)
                if currentIdx != model.currentPageIndex {
                    if let targetPage = doc.page(at: model.currentPageIndex) {
                        isPerformingSync = true
                        pdfView.go(to: targetPage)
                        isPerformingSync = false
                    }
                }
            } else if let page = doc?.page(at: model.currentPageIndex) {
                isPerformingSync = true
                pdfView.go(to: page)
                isPerformingSync = false
            }
        }
    }
    
    // MARK: - Instructor Side Hooks
    private func setupInstructorSyncHooks() {
        // Observe Page changes in single page mode
        pageObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, let model = self.model, !self.isPerformingSync else { return }
                if let curPage = self.pdfView.currentPage, let doc = self.pdfView.document {
                    let idx = doc.index(for: curPage)
                    if idx != NSNotFound && idx != model.currentPageIndex {
                        model.goToPage(idx)
                    }
                }
                self.overlayView.needsDisplay = true
            }
        }
        
        // Find internal scroll view clip view to observe continuous scrolling
        if let scrollView = pdfView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleInstructorContinuousScroll()
                }
            }
        }
    }
    
    private func handleInstructorContinuousScroll() {
        guard let model = model, model.isSyncEnabled, !isPerformingSync else {
            overlayView.needsDisplay = true
            return
        }
        
        guard model.displayMode == .singlePageContinuous,
              let scrollView = pdfView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
              let docView = scrollView.documentView else {
            overlayView.needsDisplay = true
            return
        }
        
        let maxScrollY = max(docView.frame.height - scrollView.contentView.bounds.height, 1.0)
        let currentY = scrollView.contentView.bounds.origin.y
        let fraction = max(0.0, min(1.0, currentY / maxScrollY))
        
        // Update currentPageIndex from visible page
        if let curPage = pdfView.currentPage, let doc = pdfView.document {
            let idx = doc.index(for: curPage)
            if idx != NSNotFound && idx != model.currentPageIndex {
                model.currentPageIndex = idx
            }
        }
        
        model.notifyInstructorContinuousScroll(fraction: fraction)
        overlayView.needsDisplay = true
    }
    
    // MARK: - Student Side Hooks
    private func setupStudentSyncHooks() {
        guard let model = model else { return }
        
        // Page jump sync (Single Page Mode & Thumbnail jumps)
        model.onPageSyncToStudent = { [weak self] pageIndex in
            guard let self = self, let doc = self.pdfView.document else { return }
            guard pageIndex >= 0 && pageIndex < doc.pageCount else { return }
            guard let page = doc.page(at: pageIndex) else { return }
            
            self.isPerformingSync = true
            self.pdfView.go(to: page)
            self.isPerformingSync = false
            self.overlayView.needsDisplay = true
        }
        
        // Continuous scroll sync (Smooth proportional document scrolling)
        model.onContinuousScrollSyncToStudent = { [weak self] fraction in
            guard let self = self,
                  let scrollView = self.pdfView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
                  let docView = scrollView.documentView else { return }
            
            self.isPerformingSync = true
            let maxScrollY = max(docView.frame.height - scrollView.contentView.bounds.height, 1.0)
            let targetY = fraction * maxScrollY
            let targetPoint = NSPoint(x: scrollView.contentView.bounds.origin.x, y: targetY)
            scrollView.contentView.scroll(to: targetPoint)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            self.isPerformingSync = false
            self.overlayView.needsDisplay = true
        }
    }
    
    // MARK: - Mouse Event Handling for Instructor Tools
    public override func mouseMoved(with event: NSEvent) {
        guard role == .instructor, let model = model else {
            super.mouseMoved(with: event)
            return
        }
        
        if model.activeTool == .laser {
            let viewPoint = convert(event.locationInWindow, from: nil)
            guard let (normPoint, pageIndex) = convertToNormalizedPagePoint(viewPoint: viewPoint) else {
                model.updateLaserPoint(normalizedPoint: nil, pageIndex: 0)
                overlayView.needsDisplay = true
                return
            }
            model.updateLaserPoint(normalizedPoint: normPoint, pageIndex: pageIndex)
            overlayView.needsDisplay = true
        } else {
            if model.laserPoint != nil {
                model.updateLaserPoint(normalizedPoint: nil, pageIndex: 0)
                overlayView.needsDisplay = true
            }
            super.mouseMoved(with: event)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        if role == .instructor, let model = model {
            model.updateLaserPoint(normalizedPoint: nil, pageIndex: 0)
            overlayView.needsDisplay = true
        }
        super.mouseExited(with: event)
    }
    
    public override func mouseDown(with event: NSEvent) {
        guard role == .instructor, let model = model else {
            super.mouseDown(with: event)
            return
        }
        
        let viewPoint = convert(event.locationInWindow, from: nil)
        
        if model.activeTool == .pen {
            if let (normPoint, pageIndex) = convertToNormalizedPagePoint(viewPoint: viewPoint) {
                model.startStroke(at: normPoint, pageIndex: pageIndex)
                overlayView.needsDisplay = true
            }
        } else if model.activeTool == .laser {
            if let (normPoint, pageIndex) = convertToNormalizedPagePoint(viewPoint: viewPoint) {
                model.updateLaserPoint(normalizedPoint: normPoint, pageIndex: pageIndex)
                overlayView.needsDisplay = true
            }
        } else {
            super.mouseDown(with: event)
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard role == .instructor, let model = model else {
            super.mouseDragged(with: event)
            return
        }
        
        let viewPoint = convert(event.locationInWindow, from: nil)
        
        if model.activeTool == .pen {
            if let (normPoint, _) = convertToNormalizedPagePoint(viewPoint: viewPoint) {
                model.addPointToStroke(normPoint)
                overlayView.needsDisplay = true
            }
        } else if model.activeTool == .laser {
            if let (normPoint, pageIndex) = convertToNormalizedPagePoint(viewPoint: viewPoint) {
                model.updateLaserPoint(normalizedPoint: normPoint, pageIndex: pageIndex)
                overlayView.needsDisplay = true
            }
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard role == .instructor, let model = model else {
            super.mouseUp(with: event)
            return
        }
        
        if model.activeTool == .pen {
            model.endStroke()
            overlayView.needsDisplay = true
        } else {
            super.mouseUp(with: event)
        }
    }
    
    // Helper to calculate normalized point (0.0 ... 1.0) on PDF page
    private func convertToNormalizedPagePoint(viewPoint: NSPoint) -> (CGPoint, Int)? {
        guard let page = pdfView.page(for: viewPoint, nearest: true),
              let doc = pdfView.document else { return nil }
        
        let pageIdx = doc.index(for: page)
        guard pageIdx != NSNotFound else { return nil }
        
        let pointOnPage = pdfView.convert(viewPoint, to: page)
        let pageBounds = page.bounds(for: pdfView.displayBox)
        
        let normX = pointOnPage.x / max(pageBounds.width, 1.0)
        let normY = pointOnPage.y / max(pageBounds.height, 1.0)
        
        return (CGPoint(x: normX, y: normY), pageIdx)
    }
    
    public func triggerOverlayRedraw() {
        overlayView.needsDisplay = true
    }
}

// MARK: - Annotation Canvas Overlay View
@MainActor
public class AnnotationCanvasView: NSView {
    public weak var container: InteractivePDFContainerView?
    public weak var model: PresenterModel?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let model = model, let container = container else { return nil }
        // Only intercept mouse clicks when Pen or Laser is selected
        if container.role == .instructor && (model.activeTool == .pen || model.activeTool == .laser) {
            return container
        }
        return nil // Let mouse events pass straight through to PDFView for scrolling, text selection, etc.
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext,
              let container = container,
              let model = model,
              let doc = container.pdfView.document else { return }
        
        // 1. Draw Saved Strokes
        for stroke in model.drawingStrokes {
            drawStroke(stroke, context: context, doc: doc, container: container)
        }
        
        // 2. Draw Current In-Progress Stroke
        if let currentStroke = model.currentStroke {
            drawStroke(currentStroke, context: context, doc: doc, container: container)
        }
        
        // 3. Draw Laser Pointer Dot
        if let laserNorm = model.laserPoint,
           model.laserPageIndex < doc.pageCount,
           let page = doc.page(at: model.laserPageIndex) {
            
            let pageBounds = page.bounds(for: container.pdfView.displayBox)
            let pagePoint = NSPoint(x: laserNorm.x * pageBounds.width, y: laserNorm.y * pageBounds.height)
            let viewPoint = container.pdfView.convert(pagePoint, from: page)
            
            // Only draw if visible in view
            if bounds.contains(viewPoint) {
                drawLaserDot(at: viewPoint, context: context)
            }
        }
    }
    
    private func drawStroke(_ stroke: DrawingStroke, context: CGContext, doc: PDFDocument, container: InteractivePDFContainerView) {
        guard stroke.pageIndex < doc.pageCount,
              let page = doc.page(at: stroke.pageIndex),
              stroke.points.count > 1 else { return }
        
        let pageBounds = page.bounds(for: container.pdfView.displayBox)
        
        let path = CGMutablePath()
        var isFirst = true
        
        for ptNorm in stroke.points {
            let pagePoint = NSPoint(x: ptNorm.x * pageBounds.width, y: ptNorm.y * pageBounds.height)
            let viewPoint = container.pdfView.convert(pagePoint, from: page)
            
            if isFirst {
                path.move(to: viewPoint)
                isFirst = false
            } else {
                path.addLine(to: viewPoint)
            }
        }
        
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(NSColor(stroke.color).cgColor)
        context.setLineWidth(stroke.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawLaserDot(at point: CGPoint, context: CGContext) {
        context.saveGState()
        
        // Outer radiant glow
        let glowRadius: CGFloat = 16.0
        let glowRect = CGRect(x: point.x - glowRadius, y: point.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.setFillColor(NSColor.systemRed.withAlphaComponent(0.3).cgColor)
        context.fillEllipse(in: glowRect)
        
        // Middle neon ring
        let midRadius: CGFloat = 9.0
        let midRect = CGRect(x: point.x - midRadius, y: point.y - midRadius, width: midRadius * 2, height: midRadius * 2)
        context.setFillColor(NSColor.systemRed.withAlphaComponent(0.7).cgColor)
        context.fillEllipse(in: midRect)
        
        // Intense red core
        let coreRadius: CGFloat = 5.0
        let coreRect = CGRect(x: point.x - coreRadius, y: point.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)
        context.setFillColor(NSColor.red.cgColor)
        context.fillEllipse(in: coreRect)
        
        // Shiny center white highlight
        let centerRadius: CGFloat = 2.0
        let centerRect = CGRect(x: point.x - centerRadius, y: point.y - centerRadius, width: centerRadius * 2, height: centerRadius * 2)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: centerRect)
        
        context.restoreGState()
    }
}

// MARK: - SwiftUI NSViewRepresentable Wrapper
public struct PDFKitRepresentedView: NSViewRepresentable {
    @ObservedObject public var model: PresenterModel
    public var role: PDFViewRole
    
    public init(model: PresenterModel, role: PDFViewRole) {
        self.model = model
        self.role = role
    }
    
    public func makeNSView(context: Context) -> InteractivePDFContainerView {
        let container = InteractivePDFContainerView()
        container.configure(with: model, role: role)
        return container
    }
    
    public func updateNSView(_ container: InteractivePDFContainerView, context: Context) {
        container.configure(with: model, role: role)
        container.triggerOverlayRedraw()
    }
}
