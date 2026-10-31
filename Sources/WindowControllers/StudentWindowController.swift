import AppKit
import SwiftUI

@MainActor
public class StudentWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = StudentWindowController()
    
    private var model: PresenterModel?
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1024, height: 768),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "학생용 강의 화면 (온라인 화면 공유용)"
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.fullScreenPrimary, .participatesInCycle]
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(white: 0.08, alpha: 1.0)
        window.minSize = NSSize(width: 600, height: 450)
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setup(with model: PresenterModel) {
        self.model = model
        let rootView = StudentView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        window?.contentViewController = hostingController
    }
    
    public func showStudentWindow() {
        guard let window = window else { return }
        
        let screens = NSScreen.screens
        if screens.count > 1 {
            // Place automatically on secondary display (projector or external monitor)
            let secondaryScreen = screens[1]
            let frame = secondaryScreen.visibleFrame
            let targetRect = NSRect(
                x: frame.minX + 40,
                y: frame.minY + 40,
                width: min(1280, frame.width - 80),
                height: min(800, frame.height - 80)
            )
            window.setFrame(targetRect, display: true)
        } else if let mainScreen = NSScreen.main {
            // Smart layout on single monitor
            let frame = mainScreen.visibleFrame
            let winWidth: CGFloat = min(960, max(720, frame.width * 0.45))
            let winHeight: CGFloat = min(720, max(540, frame.height * 0.75))
            let originX = frame.maxX - winWidth - 30
            let originY = frame.minY + (frame.height - winHeight) / 2
            window.setFrame(NSRect(x: originX, y: originY, width: winWidth, height: winHeight), display: true)
        }
        
        window.makeKeyAndOrderFront(nil)
        model?.isStudentWindowOpen = true
    }
    
    public func hideStudentWindow() {
        window?.orderOut(nil)
        model?.isStudentWindowOpen = false
    }
    
    public func toggleStudentWindow() {
        if window?.isVisible == true {
            hideStudentWindow()
        } else {
            showStudentWindow()
        }
    }
    
    // MARK: - NSWindowDelegate
    public func windowWillClose(_ notification: Notification) {
        model?.isStudentWindowOpen = false
    }
    
    public func windowDidBecomeMain(_ notification: Notification) {
        model?.isStudentWindowOpen = true
    }
}
