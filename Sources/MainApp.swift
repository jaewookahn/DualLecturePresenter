import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct DualLecturePresenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = PresenterModel()
    
    init() {
        SamplePDFGenerator.ensureSamplePDFsExist()
    }
    
    var body: some Scene {
        WindowGroup("강사용 프리젠터 (Instructor Presenter)") {
            InstructorView(model: model)
                .onAppear {
                    StudentWindowController.shared.setup(with: model)
                    // Automatically load sample documents for instant ready-to-test state
                    if model.instructorDoc == nil {
                        model.loadSampleDocuments()
                    }
                    // Automatically open student window on launch
                    StudentWindowController.shared.showStudentWindow()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandMenu("프레젠테이션") {
                Button("다음 슬라이드") {
                    model.nextPage()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                
                Button("이전 슬라이드") {
                    model.previousPage()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Divider()
                
                Button(model.isSyncEnabled ? "동기화 일시정지 (비밀 엿보기)" : "학생 화면과 다시 동기화") {
                    model.isSyncEnabled.toggle()
                    if model.isSyncEnabled {
                        model.goToPage(model.currentPageIndex)
                    }
                }
                .keyboardShortcut("s", modifiers: [.command])
                
                Button("학생 화면 암전 (Blackout)") {
                    model.isBlackout.toggle()
                }
                .keyboardShortcut("b", modifiers: [.command])
                
                Divider()
                
                Button(model.isStudentWindowOpen ? "학생용 독립 윈도우 닫기" : "학생용 독립 윈도우 열기 (온라인 공유용)") {
                    StudentWindowController.shared.toggleStudentWindow()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
