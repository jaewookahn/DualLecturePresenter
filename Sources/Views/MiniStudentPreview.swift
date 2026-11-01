import SwiftUI
import PDFKit

public struct MiniStudentPreview: View {
    @ObservedObject public var model: PresenterModel
    
    public init(model: PresenterModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(model.isBlackout ? Color.red : (model.isSyncEnabled ? Color.green : Color.orange))
                    .frame(width: 8, height: 8)
                
                Text(previewStatusTitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    StudentWindowController.shared.toggleStudentWindow()
                }) {
                    Image(systemName: model.isStudentWindowOpen ? "macwindow.on.rectangle" : "macwindow")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(model.isStudentWindowOpen ? "학생용 창 활성화 / 닫기" : "학생용 창 열기")
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: NSColor(white: 0.1, alpha: 1.0)))
                    .frame(height: 160)
                
                if model.studentDoc != nil {
                    if model.isBlackout {
                        VStack(spacing: 6) {
                            Image(systemName: "pause.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            Text("학생 화면 암전 중")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    } else {
                        // Embedded student view
                        PDFKitRepresentedView(model: model, role: .preview, pageIndex: model.currentPageIndex)
                            .frame(height: 160)
                            .cornerRadius(8)
                            .allowsHitTesting(false) // Preview only
                    }
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.badge.arrow.up")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("학생용 PDF 미로드")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        if model.instructorDoc != nil {
                            Button("강사용과 동일 설정") {
                                model.useInstructorDocForStudent()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        }
                    }
                    .padding(8)
                }
                
                // Border indicator
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1.5)
                    .frame(height: 160)
            }
            
            HStack {
                Text(model.isStudentWindowOpen ? "🟢 창 공유 대기 중" : "⚪ 창 닫힘")
                    .font(.system(size: 10))
                    .foregroundColor(model.isStudentWindowOpen ? .green : .gray)
                
                Spacer()
                
                Button(action: {
                    StudentWindowController.shared.showStudentWindow()
                }) {
                    Text("창 띄우기")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    private var previewStatusTitle: String {
        if model.isBlackout {
            return "학생 화면: 화면 가림"
        } else if model.isSyncEnabled {
            return "학생 화면: 동기화 중"
        } else {
            return "학생 화면: 동기화 일시정지"
        }
    }
    
    private var borderColor: Color {
        if model.isBlackout {
            return Color.red.opacity(0.8)
        } else if model.isSyncEnabled {
            return Color.green.opacity(0.5)
        } else {
            return Color.orange.opacity(0.7)
        }
    }
}
