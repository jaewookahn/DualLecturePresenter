import SwiftUI
import AppKit

public struct StudentView: View {
    @ObservedObject public var model: PresenterModel
    @State private var showWatermark: Bool = true
    
    public init(model: PresenterModel) {
        self.model = model
    }
    
    public var body: some View {
        ZStack {
            // Background
            Color(nsColor: NSColor(white: 0.08, alpha: 1.0))
                .ignoresSafeArea()
            
            if model.studentDoc != nil {
                PDFKitRepresentedView(model: model, role: .student, pageIndex: model.currentPageIndex)
                    .ignoresSafeArea()
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.system(size: 56))
                        .foregroundColor(.gray)
                    
                    Text("학생용 PDF 강의자료가 로드되지 않았습니다")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("강의 시 공유할 학생용 PDF를 선택하거나,\n강사용 파일과 동일본으로 바로 시작할 수 있습니다.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        Button("학생용 PDF 열기...") {
                            selectStudentPDF()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        
                        if model.instructorDoc != nil {
                            Button("강사용 PDF와 동일본으로 사용") {
                                model.useInstructorDocForStudent()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        
                        Button("샘플 강의자료 로드") {
                            model.loadSampleDocuments()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    .padding(.top, 8)
                }
                .padding(40)
            }
            
            // Blackout Screen Overlay
            if model.isBlackout {
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "pause.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("강의 화면이 잠시 중단되었습니다")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
                .transition(.opacity)
            }
            
            // Minimal Floating Page Indicator (Top-Right or Bottom-Right)
            if model.pageCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(model.currentPageIndex + 1) / \(model.pageCount)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Material.ultraThinMaterial)
                            .cornerRadius(12)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(16)
                    }
                }
            }
        }
    }
    
    private func selectStudentPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "학생용 PDF (강의 공유용 클린 버전)를 선택하세요"
        
        if panel.runModal() == .OK, let url = panel.url {
            model.loadStudentDocument(from: url)
        }
    }
}
