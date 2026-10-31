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
            
            CommandMenu("강의 도구") {
                Button("기본 포인터") {
                    model.activeTool = .navigation
                }
                .keyboardShortcut("0", modifiers: [.command])
                
                Button("레이저 포인터 토글") {
                    model.activeTool = (model.activeTool == .laser ? .navigation : .laser)
                }
                .keyboardShortcut("l", modifiers: [.command])
                
                Button("펜 필기 모드") {
                    model.activeTool = (model.activeTool == .pen ? .navigation : .pen)
                }
                .keyboardShortcut("d", modifiers: [.command])
                
                Button("형광펜 (하일라이터) 모드") {
                    model.activeTool = (model.activeTool == .highlighter ? .navigation : .highlighter)
                }
                .keyboardShortcut("h", modifiers: [.command])
                
                Button("텍스트 타이핑 모드") {
                    model.activeTool = (model.activeTool == .text ? .navigation : .text)
                }
                .keyboardShortcut("t", modifiers: [.command])
                
                Button("지우개 모드") {
                    model.activeTool = (model.activeTool == .eraser ? .navigation : .eraser)
                }
                .keyboardShortcut("e", modifiers: [.command])
                
                Divider()
                
                Button("현재 페이지 모든 필기/텍스트 지우기") {
                    model.clearCurrentPageAnnotations()
                }
                .keyboardShortcut("k", modifiers: [.command])
                
                Button("전체 필기/텍스트 지우기") {
                    model.clearAllAnnotations()
                }
            }
        }
    }
}
