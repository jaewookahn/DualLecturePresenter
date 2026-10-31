import AppKit
import PDFKit

public enum SamplePDFGenerator {
    private static var sampleDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DualLecturePresenter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public static var sampleInstructorURL: URL {
        return sampleDirectory.appendingPathComponent("Sample_Instructor.pdf")
    }
    
    public static var sampleStudentURL: URL {
        return sampleDirectory.appendingPathComponent("Sample_Student.pdf")
    }
    
    public static func ensureSamplePDFsExist(forceRecreate: Bool = false) {
        let fileManager = FileManager.default
        if forceRecreate || !fileManager.fileExists(atPath: sampleInstructorURL.path) {
            createSamplePDF(isInstructor: true, outputURL: sampleInstructorURL)
        }
        if forceRecreate || !fileManager.fileExists(atPath: sampleStudentURL.path) {
            createSamplePDF(isInstructor: false, outputURL: sampleStudentURL)
        }
    }
    
    private static func createSamplePDF(isInstructor: Bool, outputURL: URL) {
        let pdfData = NSMutableData()
        let pageSize = CGRect(x: 0, y: 0, width: 800, height: 600)
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return
        }
        
        let topics = [
            ("1. 강의 개요 & 학습 목표", "본 강의에서는 컴퓨터 아키텍처와 운영체제의 핵심 원리를 다룹니다.\n\n• 컴퓨터 시스템의 기본 구조 및 동작 모델\n• 프로세서 구조와 고속 메모리 계층\n• 프로세스와 스레드 동기화 메커니즘", "💡 [강사 메모]: 학생들에게 1주차 과제 제출 기한(금요일 자정)을 다시 한 번 안내할 것!"),
            ("2. CPU와 메모리 계층 구조", "L1, L2, L3 캐시와 RAM의 속도 차이 및 캐시 히트율의 중요성.\n\n• CPU 레지스터: ~1 클럭 사이클\n• L1 캐시: ~4 클럭 사이클\n• L2/L3 캐시: ~10-40 클럭 사이클\n• 메인 메모리(DRAM): ~100-200 클럭 사이클", "⚠️ [시험 힌트]: 중간고사에 L1/L2 레이턴시 비교 문제 출제 예정. 꼭 강조하기."),
            ("3. 가상 메모리와 페이징 기법", "MMU(Memory Management Unit)와 TLB(Translation Lookaside Buffer)의 동작 원리.\n\n• 논리 주소(Logical Address) -> 물리 주소(Physical Address)\n• 멀티레벨 페이지 테이블 엔트리(PTE) 구조\n• Page Fault 발생 시 OS 핸들러 루틴과 디스크 I/O", "🔍 [질문 던지기]: TLB Miss가 발생했을 때 하드웨어와 OS 커널 중 누가 개입하는지 학생들에게 질문 유도."),
            ("4. 프로세스와 스레드 동기화", "Mutex, Semaphore, 그리고 Deadlock의 4가지 필요충분조건.\n\n1. 상호 배제 (Mutual Exclusion)\n2. 점유 대기 (Hold and Wait)\n3. 비선점 (No Preemption)\n4. 순환 대기 (Circular Wait)", "📝 [풀이 해설]: 교재 142페이지 연습문제 4번 식과 정답 미리 띄워둘 것."),
            ("5. 질의응답 및 다음 강의 예고", "Q&A 세션 및 파일 시스템과 I/O 가상화 미리보기.\n\n오늘 강의는 여기까지입니다. 질문은 손들기 또는 채팅창을 이용해 주세요.\n수고하셨습니다!", "⭐️ [종료 체크]: 온라인 출석 체크 번호 8492 화면에 띄우지 말고 구두로만 안내할 것.")
        ]
        
        for (pageIndex, topic) in topics.enumerated() {
            var mediaBox = pageSize
            context.beginPage(mediaBox: &mediaBox)
            
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            
            // Background
            let bgColor = isInstructor ? NSColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1.0) : NSColor.white
            bgColor.setFill()
            context.fill(pageSize)
            
            // Header bar
            let headerColor = isInstructor ? NSColor(red: 0.18, green: 0.35, blue: 0.65, alpha: 1.0) : NSColor(red: 0.12, green: 0.22, blue: 0.35, alpha: 1.0)
            headerColor.setFill()
            context.fill(CGRect(x: 0, y: 530, width: 800, height: 70))
            
            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 22),
                .foregroundColor: NSColor.white
            ]
            let titleStr = NSAttributedString(string: "\(topic.0) (Slide \(pageIndex + 1)/5)", attributes: titleAttrs)
            titleStr.draw(at: CGPoint(x: 30, y: 550))
            
            // Badge
            let badgeText = isInstructor ? "[강사용 - 비밀 메모/답안 포함]" : "[학생용 - 온라인 공유 화면]"
            let badgeColor = isInstructor ? NSColor.systemYellow : NSColor.systemGreen
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .foregroundColor: badgeColor
            ]
            let badgeStr = NSAttributedString(string: badgeText, attributes: badgeAttrs)
            badgeStr.draw(at: CGPoint(x: 570, y: 555))
            
            // Body Content
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.textColor
            ]
            let bodyStr = NSAttributedString(string: topic.1, attributes: bodyAttrs)
            bodyStr.draw(in: CGRect(x: 40, y: 280, width: 720, height: 230))
            
            // Diagram Box
            let diagRect = CGRect(x: 40, y: 120, width: 720, height: 140)
            NSColor.lightGray.withAlphaComponent(0.18).setFill()
            context.fill(diagRect)
            NSColor.lightGray.withAlphaComponent(0.4).setStroke()
            context.stroke(diagRect, width: 1)
            
            let diagAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let diagStr = NSAttributedString(string: "[ 강의 다이어그램 및 핵심 요약 도표 영역 - Slide \(pageIndex + 1) ]", attributes: diagAttrs)
            diagStr.draw(at: CGPoint(x: 230, y: 180))
            
            // Instructor ONLY annotations
            if isInstructor {
                let noteBoxRect = CGRect(x: 40, y: 18, width: 720, height: 85)
                NSColor(red: 1.0, green: 0.95, blue: 0.78, alpha: 1.0).setFill()
                context.fill(noteBoxRect)
                
                NSColor.systemOrange.setStroke()
                context.stroke(noteBoxRect, width: 2)
                
                let noteAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: NSColor(red: 0.65, green: 0.22, blue: 0.0, alpha: 1.0)
                ]
                let noteStr = NSAttributedString(string: topic.2, attributes: noteAttrs)
                noteStr.draw(in: CGRect(x: 50, y: 28, width: 700, height: 65))
            }
            
            NSGraphicsContext.restoreGraphicsState()
            context.endPage()
        }
        
        context.closePDF()
        try? (pdfData as Data).write(to: outputURL)
    }
}
