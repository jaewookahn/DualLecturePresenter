import AppKit
import PDFKit
import SwiftUI
import Combine

public enum PDFViewRole {
    case instructor
    case student
    case preview
}

@MainActor
public class InteractivePDFContainerView: NSView, NSTextFieldDelegate {
    public let pdfView = PDFView()
    private let overlayView = AnnotationCanvasView()
    private let inlineTextField = NSTextField()
    
    public var role: PDFViewRole = .instructor
    public weak var model: PresenterModel?
    public var eraserHoverPoint: CGPoint? = nil
    
    private var isPerformingSync = false
    private var trackingArea: NSTrackingArea?
    private var scrollObserver: NSObjectProtocol?
    private var pageObserver: NSObjectProtocol?
    private var scaleObserver: NSObjectProtocol?
    private var pageNavCancellable: AnyCancellable?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    deinit {
        pageNavCancellable?.cancel()
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
        
        // Inline text editor for text annotations
        inlineTextField.isHidden = true
        inlineTextField.isBordered = true
        inlineTextField.bezelStyle = .roundedBezel
        inlineTextField.backgroundColor = NSColor(white: 1.0, alpha: 0.95)
        inlineTextField.textColor = .textColor
        inlineTextField.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        inlineTextField.placeholderString = "텍스트 입력 후 Enter..."
        inlineTextField.delegate = self
        addSubview(inlineTextField)
        
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
    
    // Always forward scrollWheel to pdfView so scrolling works with ANY active tool!
    public override func scrollWheel(with event: NSEvent) {
        pdfView.scrollWheel(with: event)
        updateInlineEditorPosition()
    }
    
    public func configure(with model: PresenterModel, role: PDFViewRole) {
        self.model = model
        self.role = role
        self.overlayView.model = model
        
        let doc = (role == .instructor) ? model.instructorDoc : model.studentDoc
        let docChanged = (pdfView.document !== doc)
        if docChanged {
            pdfView.document = doc
        }
        
        if pdfView.displayMode != model.displayMode {
            pdfView.displayMode = model.displayMode
        }
        if pdfView.autoScales != model.autoScales {
            pdfView.autoScales = model.autoScales
        }
        
        // Setup direct page navigation Combine subscriber
        setupPageNavigationSubscription(model: model)
        
        // Setup observers only once
        if scrollObserver == nil {
            scaleObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.overlayView.needsDisplay = true
                    self?.updateInlineEditorPosition()
                }
            }
            
            if role == .instructor {
                setupInstructorSyncHooks()
            } else if role == .student {
                setupStudentSyncHooks()
            }
        }
        
        // Page position sync (e.g. initial document load or single-page mode sync)
        if (docChanged || model.displayMode == .singlePage) && model.pageCount > 0 && model.currentPageIndex < model.pageCount {
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
        
        updateInlineEditorPosition()
    }
    
    // MARK: - Direct Page Navigation Subscription
    private func setupPageNavigationSubscription(model: PresenterModel) {
        guard pageNavCancellable == nil else { return }
        
        pageNavCancellable = model.pageNavigationSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] targetIndex in
                guard let self = self, let doc = self.pdfView.document else { return }
                guard targetIndex >= 0 && targetIndex < doc.pageCount else { return }
                guard let page = doc.page(at: targetIndex) else { return }
                
                let shouldNavigate: Bool
                switch self.role {
                case .instructor:
                    shouldNavigate = true
                case .student, .preview:
                    shouldNavigate = self.model?.isSyncEnabled ?? true
                }
                
                if shouldNavigate {
                    self.isPerformingSync = true
                    self.pdfView.go(to: page)
                    self.isPerformingSync = false
                    self.overlayView.needsDisplay = true
                    self.updateInlineEditorPosition()
                }
            }
    }
    
    // MARK: - Instructor Side Hooks
    private func setupInstructorSyncHooks() {
        guard let model = model else { return }
        
        // Direct closure hook from PresenterModel
        model.onPageSyncToInstructor = { [weak self] pageIndex in
            guard let self = self, let doc = self.pdfView.document else { return }
            guard pageIndex >= 0 && pageIndex < doc.pageCount else { return }
            guard let page = doc.page(at: pageIndex) else { return }
            
            self.isPerformingSync = true
            self.pdfView.go(to: page)
            self.isPerformingSync = false
            self.overlayView.needsDisplay = true
            self.updateInlineEditorPosition()
        }
        
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
                self.updateInlineEditorPosition()
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
                    self?.updateInlineEditorPosition()
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
        
        let viewPoint = convert(event.locationInWindow, from: nil)
        
        if model.activeTool == .laser {
            guard let (normPoint, pageIndex) = convertToNormalizedPagePoint(viewPoint: viewPoint) else {
                model.updateLaserPoint(normalizedPoint: nil, pageIndex: 0)
                overlayView.needsDisplay = true
                return
            }
            model.updateLaserPoint(normalizedPoint: normPoint, pageIndex: pageIndex)
            eraserHoverPoint = nil
            overlayView.needsDisplay = true
        } else if model.activeTool == .eraser {
            eraserHoverPoint = viewPoint
            if model.laserPoint != nil {
                model.updateLaserPoint(normalizedPoint: nil, pageIndex: 0)
            }
            overlayView.needsDisplay = true
        } else {
            eraserHoverPoint = nil
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
            eraserHoverPoint = nil
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
        guard let (normPoint, pageIndex) = convertToNormalizedPagePoint(viewPoint: viewPoint) else {
            super.mouseDown(with: event)
            return
        }
        
        switch model.activeTool {
        case .pen:
            model.finishEditingText()
            inlineTextField.isHidden = true
            model.startStroke(at: normPoint, pageIndex: pageIndex, isHighlighter: false)
            overlayView.needsDisplay = true
            
        case .highlighter:
            model.finishEditingText()
            inlineTextField.isHidden = true
            model.startStroke(at: normPoint, pageIndex: pageIndex, isHighlighter: true)
            overlayView.needsDisplay = true
            
        case .eraser:
            model.finishEditingText()
            inlineTextField.isHidden = true
            model.eraseAt(normalizedPoint: normPoint, pageIndex: pageIndex)
            overlayView.needsDisplay = true
            
        case .text:
            model.addOrEditTextAnnotation(at: normPoint, pageIndex: pageIndex)
            presentInlineEditor(at: viewPoint)
            overlayView.needsDisplay = true
            
        case .laser:
            model.updateLaserPoint(normalizedPoint: normPoint, pageIndex: pageIndex)
            overlayView.needsDisplay = true
            
        case .navigation:
            model.finishEditingText()
            inlineTextField.isHidden = true
            super.mouseDown(with: event)
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard role == .instructor, let model = model else {
            super.mouseDragged(with: event)
            return
        }
        
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let (normPoint, pageIndex) = convertToNormalizedPagePoint(viewPoint: viewPoint) else {
            super.mouseDragged(with: event)
            return
        }
        
        switch model.activeTool {
        case .pen, .highlighter:
            model.addPointToStroke(normPoint)
            overlayView.needsDisplay = true
            
        case .eraser:
            eraserHoverPoint = viewPoint
            model.eraseAt(normalizedPoint: normPoint, pageIndex: pageIndex)
            overlayView.needsDisplay = true
            
        case .laser:
            model.updateLaserPoint(normalizedPoint: normPoint, pageIndex: pageIndex)
            overlayView.needsDisplay = true
            
        default:
            super.mouseDragged(with: event)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard role == .instructor, let model = model else {
            super.mouseUp(with: event)
            return
        }
        
        if model.activeTool == .pen || model.activeTool == .highlighter {
            model.endStroke()
            overlayView.needsDisplay = true
        } else {
            super.mouseUp(with: event)
        }
    }
    
    // MARK: - Inline Text Editor
    private func presentInlineEditor(at viewPoint: NSPoint) {
        guard let model = model, let editingId = model.activeEditingTextId,
              let note = model.textAnnotations.first(where: { $0.id == editingId }) else { return }
        
        inlineTextField.stringValue = note.text
        inlineTextField.frame = NSRect(x: min(max(10, viewPoint.x - 10), bounds.width - 290), y: min(max(10, viewPoint.y - 18), bounds.height - 40), width: 280, height: 36)
        inlineTextField.font = NSFont.systemFont(ofSize: note.fontSize, weight: .bold)
        inlineTextField.textColor = NSColor(note.color)
        inlineTextField.isHidden = false
        window?.makeFirstResponder(inlineTextField)
    }
    
    public func controlTextDidChange(_ obj: Notification) {
        guard let model = model, let editingId = model.activeEditingTextId else { return }
        model.updateTextAnnotation(id: editingId, text: inlineTextField.stringValue)
        overlayView.needsDisplay = true
    }
    
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter key pressed -> finish editing
            inlineTextField.isHidden = true
            window?.makeFirstResponder(self)
            model?.finishEditingText()
            overlayView.needsDisplay = true
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Esc key pressed -> cancel
            if let editingId = model?.activeEditingTextId {
                model?.deleteTextAnnotation(id: editingId)
            }
            inlineTextField.isHidden = true
            window?.makeFirstResponder(self)
            model?.finishEditingText()
            overlayView.needsDisplay = true
            return true
        }
        return false
    }
    
    private func updateInlineEditorPosition() {
        guard !inlineTextField.isHidden, let model = model, let editingId = model.activeEditingTextId,
              let note = model.textAnnotations.first(where: { $0.id == editingId }),
              let doc = pdfView.document, note.pageIndex < doc.pageCount,
              let page = doc.page(at: note.pageIndex) else {
            return
        }
        
        let pageBounds = page.bounds(for: pdfView.displayBox)
        let pagePoint = NSPoint(x: note.normalizedPosition.x * pageBounds.width, y: note.normalizedPosition.y * pageBounds.height)
        let viewPoint = pdfView.convert(pagePoint, from: page)
        
        inlineTextField.frame = NSRect(x: min(max(10, viewPoint.x - 10), bounds.width - 290), y: min(max(10, viewPoint.y - 18), bounds.height - 40), width: 280, height: 36)
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
        updateInlineEditorPosition()
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
        // For Laser and Navigation: DO NOT INTERCEPT clicks or scroll!
        // This ensures two-finger scroll and wheel scroll ALWAYS work while using laser pointer!
        if container.role == .instructor {
            switch model.activeTool {
            case .pen, .highlighter, .eraser, .text:
                return container
            case .navigation, .laser:
                return nil // Let mouse events and scrolling pass directly to PDFView
            }
        }
        return nil
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext,
              let container = container,
              let model = model,
              let doc = container.pdfView.document else { return }
        
        // 1. Draw Saved Strokes (Pen and Highlighter)
        for stroke in model.drawingStrokes {
            drawStroke(stroke, context: context, doc: doc, container: container)
        }
        
        // 2. Draw Current In-Progress Stroke
        if let currentStroke = model.currentStroke {
            drawStroke(currentStroke, context: context, doc: doc, container: container)
        }
        
        // 3. Draw Text Annotations
        for note in model.textAnnotations {
            drawTextAnnotation(note, context: context, doc: doc, container: container)
        }
        
        // 4. Draw Laser Pointer Dot
        if let laserNorm = model.laserPoint,
           model.laserPageIndex < doc.pageCount,
           let page = doc.page(at: model.laserPageIndex) {
            
            let pageBounds = page.bounds(for: container.pdfView.displayBox)
            let pagePoint = NSPoint(x: laserNorm.x * pageBounds.width, y: laserNorm.y * pageBounds.height)
            let viewPoint = container.pdfView.convert(pagePoint, from: page)
            
            if bounds.contains(viewPoint) {
                drawLaserDot(at: viewPoint, context: context)
            }
        }
        
        // 5. Draw Eraser Indicator (Only in Instructor mode)
        if container.role == .instructor && model.activeTool == .eraser, let hover = container.eraserHoverPoint {
            drawEraserCursor(at: hover, context: context)
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
        
        if stroke.isHighlighter {
            // Broad semi-transparent highlighter
            context.setBlendMode(.multiply)
            context.setStrokeColor(NSColor.systemYellow.withAlphaComponent(0.38).cgColor)
            context.setLineWidth(stroke.lineWidth)
            context.setLineCap(.square)
            context.setLineJoin(.bevel)
        } else {
            // Crisp opaque pen
            context.setStrokeColor(NSColor(stroke.color).cgColor)
            context.setLineWidth(stroke.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
        }
        
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawTextAnnotation(_ note: TextAnnotation, context: CGContext, doc: PDFDocument, container: InteractivePDFContainerView) {
        guard note.pageIndex < doc.pageCount,
              let page = doc.page(at: note.pageIndex) else { return }
        
        // If actively editing in instructor view, inline textfield is visible, skip duplicate rendering
        if container.role == .instructor && model?.activeEditingTextId == note.id {
            return
        }
        
        guard !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let pageBounds = page.bounds(for: container.pdfView.displayBox)
        let pagePoint = NSPoint(x: note.normalizedPosition.x * pageBounds.width, y: note.normalizedPosition.y * pageBounds.height)
        let viewPoint = container.pdfView.convert(pagePoint, from: page)
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: note.fontSize),
            .foregroundColor: NSColor(note.color)
        ]
        let attrString = NSAttributedString(string: note.text, attributes: attrs)
        let textSize = attrString.size()
        
        let paddingH: CGFloat = 8
        let paddingV: CGFloat = 4
        let badgeRect = NSRect(
            x: viewPoint.x - paddingH,
            y: viewPoint.y - paddingV,
            width: textSize.width + (paddingH * 2),
            height: textSize.height + (paddingV * 2)
        )
        
        context.saveGState()
        
        // Draw soft badge background pill
        if note.hasBackground {
            let bgPath = CGPath(roundedRect: badgeRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            context.setFillColor(NSColor(white: 1.0, alpha: 0.92).cgColor)
            context.addPath(bgPath)
            context.fillPath()
            
            context.setStrokeColor(NSColor(note.color).withAlphaComponent(0.6).cgColor)
            context.setLineWidth(1.5)
            context.addPath(bgPath)
            context.strokePath()
        }
        
        // Draw text
        attrString.draw(at: viewPoint)
        
        context.restoreGState()
    }
    
    private func drawEraserCursor(at point: CGPoint, context: CGContext) {
        context.saveGState()
        let radius: CGFloat = 18.0
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        
        context.setFillColor(NSColor.systemPink.withAlphaComponent(0.2).cgColor)
        context.fillEllipse(in: rect)
        
        context.setStrokeColor(NSColor.systemPink.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.5)
        let lengths: [CGFloat] = [4.0, 3.0]
        context.setLineDash(phase: 0, lengths: lengths)
        context.strokeEllipse(in: rect)
        
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
    public var pageIndex: Int
    
    public init(model: PresenterModel, role: PDFViewRole, pageIndex: Int = 0) {
        self.model = model
        self.role = role
        self.pageIndex = pageIndex
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
