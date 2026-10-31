import SwiftUI
import AppKit
import PDFKit
import Combine

@MainActor
public class PresenterModel: ObservableObject {
    // MARK: - Documents
    @Published public var instructorDoc: PDFDocument?
    @Published public var studentDoc: PDFDocument?
    @Published public var instructorURL: URL?
    @Published public var studentURL: URL?
    
    @Published public var pageCount: Int = 0
    @Published public var currentPageIndex: Int = 0
    
    // MARK: - Presentation Settings
    @Published public var isSyncEnabled: Bool = true
    @Published public var displayMode: PDFDisplayMode = .singlePage
    @Published public var autoScales: Bool = true
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var isBlackout: Bool = false
    
    // MARK: - Interactive Tools
    @Published public var activeTool: ToolMode = .navigation
    @Published public var laserPoint: CGPoint? = nil // Normalized (0...1, 0...1) in page coordinates
    @Published public var laserPageIndex: Int = 0
    
    @Published public var drawingStrokes: [DrawingStroke] = []
    @Published public var currentStroke: DrawingStroke? = nil
    @Published public var penColor: Color = .red
    @Published public var penLineWidth: CGFloat = 3.5
    
    // MARK: - Student Window Status
    @Published public var isStudentWindowOpen: Bool = false
    
    // MARK: - Lecture Timer
    @Published public var elapsedSeconds: Int = 0
    @Published public var isTimerRunning: Bool = false
    private var timerCancellable: AnyCancellable?
    
    // MARK: - Sync Communication Closures / Callbacks
    public var onScrollSyncToStudent: ((_ pageIndex: Int, _ relativeY: CGFloat) -> Void)?
    public var onContinuousScrollSyncToStudent: ((_ fraction: CGFloat) -> Void)?
    public var onPageSyncToStudent: ((_ pageIndex: Int) -> Void)?
    public var onScrollSyncToInstructor: ((_ pageIndex: Int, _ relativeY: CGFloat) -> Void)?
    public var onPageSyncToInstructor: ((_ pageIndex: Int) -> Void)?
    
    public init() {
        // Setup default timer
    }
    
    // MARK: - Document Loading
    public func loadInstructorDocument(from url: URL) {
        guard let doc = PDFDocument(url: url) else { return }
        self.instructorURL = url
        self.instructorDoc = doc
        updatePageCount()
        
        // Auto-detect matching student document if in the same directory
        attemptAutoPairStudent(from: url)
    }
    
    public func loadStudentDocument(from url: URL) {
        guard let doc = PDFDocument(url: url) else { return }
        self.studentURL = url
        self.studentDoc = doc
        updatePageCount()
    }
    
    public func useInstructorDocForStudent() {
        if let url = instructorURL {
            loadStudentDocument(from: url)
        } else if let doc = instructorDoc, let url = doc.documentURL {
            loadStudentDocument(from: url)
        }
    }
    
    private func updatePageCount() {
        let instCount = instructorDoc?.pageCount ?? 0
        let studCount = studentDoc?.pageCount ?? 0
        self.pageCount = max(instCount, studCount)
        if currentPageIndex >= self.pageCount && self.pageCount > 0 {
            currentPageIndex = self.pageCount - 1
        }
    }
    
    private func attemptAutoPairStudent(from instructorUrl: URL) {
        if studentDoc != nil { return } // already loaded
        
        let directory = instructorUrl.deletingLastPathComponent()
        let filename = instructorUrl.deletingPathExtension().lastPathComponent
        
        // Try common student filename variations
        let candidates = [
            filename.replacingOccurrences(of: "_instructor", with: "_student"),
            filename.replacingOccurrences(of: "instructor", with: "student"),
            filename.replacingOccurrences(of: "Instructor", with: "Student"),
            filename.replacingOccurrences(of: "강사용", with: "학생용"),
            filename.replacingOccurrences(of: "_teacher", with: "_student"),
            filename.replacingOccurrences(of: "teacher", with: "student"),
            filename + "_student",
            filename + "_학생용"
        ]
        
        for candidate in candidates {
            if candidate == filename { continue }
            let candidateUrl = directory.appendingPathComponent(candidate).appendingPathExtension("pdf")
            if FileManager.default.fileExists(atPath: candidateUrl.path) {
                loadStudentDocument(from: candidateUrl)
                break
            }
        }
    }
    
    // MARK: - Page Navigation
    public func nextPage() {
        guard pageCount > 0 else { return }
        if currentPageIndex < pageCount - 1 {
            goToPage(currentPageIndex + 1)
        }
    }
    
    public func previousPage() {
        guard pageCount > 0 else { return }
        if currentPageIndex > 0 {
            goToPage(currentPageIndex - 1)
        }
    }
    
    public func goToPage(_ index: Int) {
        guard index >= 0 && index < pageCount else { return }
        self.currentPageIndex = index
        
        // If sync is enabled, notify student window
        if isSyncEnabled {
            onPageSyncToStudent?(index)
        }
    }
    
    // MARK: - Scroll Sync Trigger
    public func notifyInstructorScrolled(pageIndex: Int, relativeY: CGFloat) {
        guard isSyncEnabled else { return }
        self.currentPageIndex = pageIndex
        onScrollSyncToStudent?(pageIndex, relativeY)
    }
    
    public func notifyInstructorContinuousScroll(fraction: CGFloat) {
        guard isSyncEnabled else { return }
        onContinuousScrollSyncToStudent?(fraction)
    }
    
    // MARK: - Laser Pointer Sync
    public func updateLaserPoint(normalizedPoint: CGPoint?, pageIndex: Int) {
        self.laserPoint = normalizedPoint
        self.laserPageIndex = pageIndex
    }
    
    // MARK: - Live Drawing
    public func startStroke(at normalizedPoint: CGPoint, pageIndex: Int) {
        let stroke = DrawingStroke(
            pageIndex: pageIndex,
            points: [normalizedPoint],
            color: penColor,
            lineWidth: penLineWidth
        )
        self.currentStroke = stroke
    }
    
    public func addPointToStroke(_ normalizedPoint: CGPoint) {
        guard var stroke = self.currentStroke else { return }
        stroke.points.append(normalizedPoint)
        self.currentStroke = stroke
    }
    
    public func endStroke() {
        if let stroke = self.currentStroke, stroke.points.count > 1 {
            self.drawingStrokes.append(stroke)
        }
        self.currentStroke = nil
    }
    
    public func clearCurrentPageDrawings() {
        drawingStrokes.removeAll(where: { $0.pageIndex == currentPageIndex })
    }
    
    public func clearAllDrawings() {
        drawingStrokes.removeAll()
    }
    
    // MARK: - Timer Control
    public func toggleTimer() {
        if isTimerRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    public func startTimer() {
        isTimerRunning = true
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedSeconds += 1
            }
    }
    
    public func pauseTimer() {
        isTimerRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    public func resetTimer() {
        pauseTimer()
        elapsedSeconds = 0
    }
    
    public var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Sample Documents Setup
    public func loadSampleDocuments() {
        SamplePDFGenerator.ensureSamplePDFsExist(forceRecreate: true)
        let instURL = SamplePDFGenerator.sampleInstructorURL
        let studURL = SamplePDFGenerator.sampleStudentURL
        
        if FileManager.default.fileExists(atPath: instURL.path) {
            loadInstructorDocument(from: instURL)
        }
        if FileManager.default.fileExists(atPath: studURL.path) {
            loadStudentDocument(from: studURL)
        }
    }
}
