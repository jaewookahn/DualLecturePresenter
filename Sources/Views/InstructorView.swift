import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

public struct InstructorView: View {
    @ObservedObject public var model: PresenterModel
    
    @State private var showThumbnails: Bool = true
    @State private var showDashboard: Bool = true
    @State private var isDropTargeted: Bool = false
    
    public init(model: PresenterModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            toolbarHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Main Content Area
            HStack(spacing: 0) {
                // Left: Slide Thumbnails
                if showThumbnails && model.pageCount > 0 {
                    SlideThumbnailView(model: model)
                    Divider()
                }
                
                // Center: Main Instructor PDF View
                GeometryReader { geo in
                    ZStack {
                        Color(nsColor: NSColor(white: 0.15, alpha: 1.0))
                            .ignoresSafeArea()
                        
                        if model.instructorDoc != nil {
                            PDFKitRepresentedView(model: model, role: .instructor)
                                .ignoresSafeArea()
                        } else {
                            emptyStateView
                        }
                        
                        // Secret Peek Mode Banner (When instructor un-synced)
                        if !model.isSyncEnabled {
                            VStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "eye.slash.fill")
                                        .foregroundColor(.white)
                                    Text("비밀 엿보기 모드 (학생 화면은 현재 페이지에 고정되어 있습니다)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button("학생 화면과 다시 동기화") {
                                        model.isSyncEnabled = true
                                        model.goToPage(model.currentPageIndex)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.95))
                                .shadow(radius: 4)
                                
                                Spacer()
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .onChange(of: geo.size) { newSize in
                        model.instructorViewportSize = newSize
                    }
                    .onAppear {
                        model.instructorViewportSize = geo.size
                    }
                }
                .onDrop(of: [.pdf], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                }
                
                // Right: Presenter Control Dashboard
                if showDashboard {
                    Divider()
                    presenterDashboard
                        .frame(width: 280)
                        .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 650)
    }
    
    // MARK: - Toolbar Header
    private var toolbarHeader: some View {
        HStack(spacing: 14) {
            // Sidebar Toggle
            Button(action: { withAnimation { showThumbnails.toggle() } }) {
                Image(systemName: "sidebar.left")
                    .foregroundColor(showThumbnails ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("슬라이드 목록 보기 토글")
            
            // Document Loaders
            HStack(spacing: 6) {
                Button(action: { selectInstructorPDF() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundColor(.blue)
                        Text(model.instructorURL != nil ? model.instructorURL!.deletingPathExtension().lastPathComponent : "강사용 열기")
                            .lineLimit(1)
                            .frame(maxWidth: 110)
                    }
                }
                .buttonStyle(.bordered)
                .help("강사용 PDF (어노테이션/해설 포함) 선택")
                
                Button(action: { selectStudentPDF() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.green)
                        Text(model.studentURL != nil ? model.studentURL!.deletingPathExtension().lastPathComponent : "학생용 열기")
                            .lineLimit(1)
                            .frame(maxWidth: 110)
                    }
                }
                .buttonStyle(.bordered)
                .help("학생용 PDF (온라인 공유용 클린 버전) 선택")
                
                Menu {
                    Button("강사용 PDF 열기...") { selectInstructorPDF() }
                    Button("학생용 PDF 열기...") { selectStudentPDF() }
                    if model.instructorDoc != nil {
                        Button("강사용 PDF를 학생용으로도 동일 설정") { model.useInstructorDocForStudent() }
                    }
                    Divider()
                    Button("샘플 강의자료 로드 (테스트용)") { model.loadSampleDocuments() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
            
            Divider()
                .frame(height: 20)
            
            // Navigation Controls
            HStack(spacing: 6) {
                Button(action: { model.previousPage() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(model.currentPageIndex <= 0)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .help("이전 슬라이드 (←)")
                
                Text(model.pageCount > 0 ? "\(model.currentPageIndex + 1) / \(model.pageCount)" : "0 / 0")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .frame(minWidth: 60)
                
                Button(action: { model.nextPage() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
                .disabled(model.currentPageIndex >= model.pageCount - 1)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .help("다음 슬라이드 (→ 또는 Space)")
            }
            
            Divider()
                .frame(height: 20)
            
            // Display Mode Picker
            Picker("", selection: $model.displayMode) {
                Text("슬라이드").tag(PDFDisplayMode.singlePage)
                Text("연속 스크롤").tag(PDFDisplayMode.singlePageContinuous)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            
            // Sync Toggle (Secret Peek Mode)
            Button(action: {
                withAnimation {
                    model.isSyncEnabled.toggle()
                    if model.isSyncEnabled {
                        model.goToPage(model.currentPageIndex)
                    }
                }
            }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.isSyncEnabled ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(model.isSyncEnabled ? "동기화 켜짐" : "비밀 엿보기")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 6)
            }
            .buttonStyle(.bordered)
            .tint(model.isSyncEnabled ? .green : .orange)
            .help(model.isSyncEnabled ? "클릭 시 동기화 일시정지 (학생에게 안 보이고 다음 페이지 확인 가능)" : "클릭 시 학생 화면과 다시 동기화")
            
            // Blackout Screen
            Button(action: { withAnimation { model.isBlackout.toggle() } }) {
                Image(systemName: model.isBlackout ? "eye.slash.fill" : "eye")
                    .foregroundColor(model.isBlackout ? .red : .primary)
            }
            .buttonStyle(.bordered)
            .tint(model.isBlackout ? .red : .primary)
            .help("학생 화면 암전 토글 (B)")
            .keyboardShortcut("b", modifiers: [])
            
            Spacer()
            
            // Tool Picker
            Picker("", selection: $model.activeTool) {
                ForEach(ToolMode.allCases) { tool in
                    Label(tool.rawValue, systemImage: tool.icon).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            
            // Student Window Launch Button
            Button(action: {
                StudentWindowController.shared.toggleStudentWindow()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow.on.rectangle")
                    Text("학생용 창")
                    Circle()
                        .fill(model.isStudentWindowOpen ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isStudentWindowOpen ? .blue : .secondary)
            .help("학생용 독립 윈도우 열기/닫기 (온라인 회의에서 이 창을 공유하세요)")
            
            // Aspect Ratio Menu
            Menu {
                ForEach(AspectRatioMode.allCases) { mode in
                    Button(action: {
                        StudentWindowController.shared.applyAspectRatio(mode)
                    }) {
                        HStack {
                            Text(mode.rawValue)
                            if model.aspectRatioMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                    Text(model.aspectRatioMode.rawValue)
                        .font(.caption)
                }
            }
            .menuStyle(.borderedButton)
            .help("학생 화면 비율 고정 (PDF 원본, 강사 뷰 비율 복제, 16:9, 4:3)")
            
            // Right Dashboard Toggle
            Button(action: { withAnimation { showDashboard.toggle() } }) {
                Image(systemName: "sidebar.right")
                    .foregroundColor(showDashboard ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("강의 대시보드 토글")
        }
    }
    
    // MARK: - Presenter Control Dashboard
    private var presenterDashboard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                MiniStudentPreview(model: model)
                lectureTimerCard
                documentInfoCard
                aspectRatioControlCard
                toolSettingsCard
                shortcutGuideCard
            }
            .padding(14)
        }
    }
    
    private var lectureTimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("강의 타이머")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack {
                Text(model.formattedElapsedTime)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { model.toggleTimer() }) {
                    Image(systemName: model.isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isTimerRunning ? .orange : .green)
                
                Button(action: { model.resetTimer() }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private var documentInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("자료 정보")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                statusRow(
                    title: "강사용",
                    value: model.instructorURL?.lastPathComponent ?? "선택 안 됨",
                    icon: "person.crop.circle.badge.checkmark",
                    color: .blue
                )
                statusRow(
                    title: "학생용",
                    value: model.studentURL?.lastPathComponent ?? "선택 안 됨",
                    icon: "person.2.fill",
                    color: .green
                )
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
    
    private var aspectRatioControlCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "aspectratio")
                    .foregroundColor(.accentColor)
                Text("화면 비율 동기화 (Zoom 최적화)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            Text("학생 창 비율을 고정하여 검은 여백을 없애고 강사 화면과 똑같이 맞춥니다.")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    aspectButton("PDF 원본", mode: .pdfNative)
                    aspectButton("강사 뷰 맞춤", mode: .matchInstructor)
                }
                
                HStack(spacing: 6) {
                    aspectButton("16:9 와이드", mode: .ratio16_9)
                    aspectButton("4:3 표준", mode: .ratio4_3)
                    aspectButton("자유 조절", mode: .free)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var toolSettingsCard: some View {
        if model.activeTool == .pen {
            VStack(alignment: .leading, spacing: 10) {
                Text("✏️ 펜 필기 옵션")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ColorPicker("", selection: $model.penColor)
                        .labelsHidden()
                    
                    Slider(value: $model.penLineWidth, in: 1...12, step: 0.5)
                    
                    Text("\(String(format: "%.1f", model.penLineWidth)) pt")
                        .font(.caption2)
                        .frame(width: 40)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        } else if model.activeTool == .highlighter {
            VStack(alignment: .leading, spacing: 10) {
                Text("🖍️ 형광펜 (하일라이터)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ColorPicker("", selection: $model.highlighterColor)
                        .labelsHidden()
                    
                    Slider(value: $model.highlighterWidth, in: 12...45, step: 1.0)
                    
                    Text("\(Int(model.highlighterWidth)) pt")
                        .font(.caption2)
                        .frame(width: 36)
                }
                
                Text("노란색 반투명 굵은 선으로 글자와 도표 위를 부드럽게 강조합니다.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        } else if model.activeTool == .text {
            VStack(alignment: .leading, spacing: 10) {
                Text("💬 텍스트 타이핑")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ColorPicker("", selection: $model.textColor)
                        .labelsHidden()
                    
                    Slider(value: $model.textFontSize, in: 12...36, step: 1.0)
                    
                    Text("\(Int(model.textFontSize)) pt")
                        .font(.caption2)
                        .frame(width: 36)
                }
                
                Text("슬라이드 위 원하는 위치를 클릭하면 텍스트 입력창이 열립니다. (Enter: 완료, Esc: 취소)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        } else if model.activeTool == .eraser {
            VStack(alignment: .leading, spacing: 10) {
                Text("🧹 지우개")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Text("슬라이드 위의 펜 선이나 텍스트를 마우스로 드래그하면 지워집니다.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack(spacing: 6) {
                    Button("현재 페이지 지우기") {
                        model.clearCurrentPageAnnotations()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("전체 지우기") {
                        model.clearAllAnnotations()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    private var shortcutGuideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("단축키 가이드")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                shortcutRow(key: "Space / →", desc: "다음 슬라이드")
                shortcutRow(key: "←", desc: "이전 슬라이드")
                shortcutRow(key: "B", desc: "학생 화면 암전 (Blackout)")
                shortcutRow(key: "L", desc: "레이저 포인터")
                shortcutRow(key: "P", desc: "펜 필기 모드")
                shortcutRow(key: "H", desc: "형광펜 (하일라이터)")
                shortcutRow(key: "T", desc: "텍스트 타이핑")
                shortcutRow(key: "E", desc: "지우개 모드")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("강의자료 PDF를 열어주세요")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("강사용 PDF와 학생용 PDF를 각각 불러옵니다.\n두 PDF는 동일한 슬라이드 번호 체계로 동기화됩니다.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("강사용 PDF 열기") {
                    selectInstructorPDF()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("샘플 강의자료 로드") {
                    model.loadSampleDocuments()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Text("또는 PDF 파일을 이 창으로 드래그 & 드롭하세요.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
    
    private func statusRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    private func shortcutRow(key: String, desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .tertiaryLabelColor).opacity(0.2))
                .cornerRadius(4)
            Spacer()
            Text(desc)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func aspectButton(_ title: String, mode: AspectRatioMode) -> some View {
        Button(action: {
            StudentWindowController.shared.applyAspectRatio(mode)
        }) {
            HStack(spacing: 3) {
                if model.aspectRatioMode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(title)
            }
        }
        .buttonStyle(.bordered)
        .tint(model.aspectRatioMode == mode ? .blue : .secondary)
        .controlSize(.mini)
    }
    
    // MARK: - File Selection Helpers
    private func selectInstructorPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "강사용 PDF (어노테이션/해설 포함)를 선택하세요"
        
        if panel.runModal() == .OK, let url = panel.url {
            model.loadInstructorDocument(from: url)
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
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
            if let url = item as? URL {
                DispatchQueue.main.async {
                    if self.model.instructorDoc == nil {
                        self.model.loadInstructorDocument(from: url)
                    } else {
                        self.model.loadStudentDocument(from: url)
                    }
                }
            }
        }
        return true
    }
}
