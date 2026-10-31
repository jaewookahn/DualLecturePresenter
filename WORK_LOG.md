# 📝 DualLecturePresenter 개발 작업 기록 및 기술 보고서 (Work Log)

## 1. 개요 및 배경
- **작업 일시**: 2026-10-31
- **목표**: 온라인 강의 시 **강사용(어노테이션, 비밀 메모, 풀이 포함)**과 **학생용(클린 버전)**의 두 PDF를 동시에 열고, 강사의 스크롤 및 화면 조작이 학생 화면에 실시간으로 완벽하게 동기화되는 macOS 네이티브 앱 개발.
- **핵심 요구사항**:
  1. 두 버전의 PDF를 동시에 표시 및 제어
  2. 스크롤, 슬라이드 넘김, 액션(레이저 포인터, 필기 등)의 실시간 동기화
  3. 화상회의(Zoom, Google Meet, Teams 등)에서 학생용 창만 단독 화면 공유할 수 있도록 **독립 윈도우(`NSWindow`)** 구조 제공
  4. 강사 전용 기능: 학생 화면 실시간 미니 모니터, 비밀 엿보기(싱크 일시정지), 학생 화면 가리기(Blackout), 강의 타이머

---

## 2. 기술 스택 및 아키텍처 결정

### 2.1 기술 스택 선정
- **언어**: Swift 6.1 (Strict Concurrency 완벽 대응)
- **UI 프레임워크**: SwiftUI + AppKit (하이브리드 구조)
- **문서 렌더링 엔진**: Apple PDFKit (`PDFView`, `PDFDocument`, `PDFDestination`)
- **타깃 OS**: macOS 13.0+ (macOS 15 Sequoia 완벽 지원)

### 2.2 하이브리드 아키텍처 이유
- 순수 SwiftUI만으로는 macOS에서 다중 독립 윈도우의 좌표 제어, 외장 디스플레이(프로젝터) 감지 및 자동 배치, `PDFView`의 내부 `NSScrollView`/`PDFClipView` 이벤트 캡처에 한계가 있음.
- 따라서 **`NSWindowController`를 활용한 독립 윈도우 라이프사이클 관리**와 **`NSViewRepresentable`을 통한 PDFKit 네이티브 스크롤 제어**, 그리고 **SwiftUI를 통한 반응형 대시보드 및 툴바**를 결합한 아키텍처를 채택함.

---

## 3. 핵심 동기화 메커니즘 설계

### 3.1 슬라이드 모드 (1장씩 넘기기)
- 키보드 방향키(`←`, `→`), 스페이스바, 프레젠테이션 클릭커, 또는 썸네일 클릭 시 동작.
- `PresenterModel.goToPage(index)`가 호출되면 강사용 및 학생용 `PDFView.go(to: targetPage)`가 즉시 트리거되어 레이턴시 없이 페이지가 전환됨.

### 3.2 연속 스크롤 모드 (Continuous Scrolling)
- 트랙패드나 마우스 휠로 부드럽게 스크롤할 때의 동기화.
- **비례 스크롤 비율(Proportional Scroll Fraction) 계산**:
  - `NSScrollView.contentView`(`PDFClipView`)의 `boundsDidChangeNotification`을 감지.
  - AppKit의 `isFlipped == false` 좌표계 특성을 고려하여 총 스크롤 가능 높이 대비 현재 스크롤 위치의 비율(`fraction = origin.y / maxScrollY`)을 산출.
  - 학생용 뷰는 수신한 비율에 따라 `scrollView.contentView.scroll(to: targetPoint)` 및 `reflectScrolledClipView()`를 호출하여 창 크기나 해상도가 달라도 정확하게 동일한 비율 위치를 픽셀 단위로 미러링함.

### 3.3 레이저 포인터 및 펜 필기 정규화 좌표 동기화
- 강사가 슬라이드 위에서 마우스를 움직이거나 펜으로 필기할 때:
  1. `pdfView.convert(viewPoint, to: page)`로 해당 PDF 페이지 내부 좌표로 변환.
  2. 페이지 크기로 정규화: `(normX = pt.x / page.width, normY = pt.y / page.height)`.
  3. 학생용 창에서는 `(normX * studentPage.width, normY * studentPage.height)`를 뷰 좌표로 역변환하여 정확한 위치에 네온 레드 레이저 포인터 및 드로잉 패스를 렌더링.

---

## 4. 개발 과정에서 직면한 문제 및 해결 기록 (Troubleshooting)

### 4.1 CoreGraphics PDF 생성 시 검은 화면 문제
- **증상**: 샘플 PDF 생성 스크립트 실행 시 텍스트와 배경이 모두 검은색으로 렌더링됨.
- **원인**: `CGContext` 생성 후 `NSGraphicsContext.current`가 해당 컨텍스트로 설정되지 않아 `NSColor.setFill()`과 `NSAttributedString.draw()`가 컨텍스트에 반영되지 않고 기본 검은색으로 채워짐.
- **해결**:
  ```swift
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
  // 드로잉 로직 수행
  NSGraphicsContext.restoreGraphicsState()
  ```
  적용 후 모든 슬라이드가 고화질로 선명하게 생성됨.

### 4.2 연속 스크롤 시 화면 스냅/버벅임 현상
- **증상**: 학생용 창을 열고 연속 스크롤을 시도할 때 스크롤이 매끄럽지 않거나 간헐적으로 튀는 현상 발생.
- **원인 분석**:
  1. 연속 스크롤 중에 `currentPageIndex`가 갱신되면서 SwiftUI `updateNSView`가 호출됨.
  2. `configure()` 내부에서 `currentIdx != model.currentPageIndex` 조건에 의해 `pdfView.go(to: targetPage)`가 호출되어, 연속 스크롤 도중 강제로 페이지 상단으로 스냅되는 충돌이 발생함.
  3. `updateNSView` 호출 시마다 스크롤 옵저버가 해제/재등록되는 오버헤드가 발생함.
- **해결**:
  1. 옵저버는 뷰 라이프사이클 동안 단 1회만 등록(`scrollObserver == nil` 조건)하도록 변경.
  2. `pdfView.go(to: targetPage)`는 단일 슬라이드 모드(`model.displayMode == .singlePage`)일 때만 실행되도록 분기하여, 연속 스크롤 모드에서는 순수 오프셋 비율 동기화만 매끄럽게 동작하도록 최적화 완료.

### 4.3 Swift 6 Concurrency 및 Actor 격리 경고
- `PresenterModel`이 `@MainActor`로 격리되어 있어 `NotificationCenter` 콜백에서 경고 발생.
- `InteractivePDFContainerView`, `AnnotationCanvasView` 및 모든 옵저버 핸들러에 `@MainActor` 및 `MainActor.assumeIsolated { ... }`를 명시하여 Swift 6 컴파일 에러 및 경고를 0건으로 정리.

### 4.4 레이저 포인터 활성화 시 스크롤 차단 문제 해결
- **증상**: 레이저 포인터 선택 시 마우스 휠 및 2손가락 트랙패드 스크롤이 동작하지 않음.
- **원인 분석**:
  1. `AnnotationCanvasView.hitTest()`에서 `.laser` 도구일 때 오버레이 컨테이너를 반환하여 마우스 스크롤 이벤트가 `PDFView`에 도달하지 못하고 흡수됨.
  2. `InteractivePDFContainerView`에 `scrollWheel(with:)` 포워딩이 누락되어 있었음.
- **해결**:
  1. `hitTest()`에서 `.laser`는 `nil`을 반환하도록 수정 (포인터 추적은 `NSTrackingArea`로 독립 수신하므로 클릭/스크롤을 가로챌 필요가 없음).
  2. `InteractivePDFContainerView.scrollWheel(with:)`를 오버라이드하여 `pdfView.scrollWheel(with: event)`로 전달함으로써 모든 도구 활성화 상태에서도 스크롤이 100% 작동하도록 개선.

### 4.5 지우개(Eraser) 도구 구현
- **증상**: 지우개 도구 선택 시 마우스 드래그를 해도 필기가 지워지지 않음.
- **원인**: 도구 열거형에 정의만 되어 있고 마우스 다운/드래그 시 획 제거 로직이 구현되지 않음.
- **해결**:
  - `eraseAt(normalizedPoint:pageIndex:radius:)` 메서드 구현.
  - 마우스 드래그 반경 내에 포함되는 모든 스트로크 좌표와 텍스트 노트를 탐지하여 즉시 제거 및 학생 화면 동기화.
  - 지우개 커서 위치에 시각적 원형 가이드 링 표시.

### 4.6 형광펜(Highlighter) 및 텍스트 타이핑(Text Annotation) 추가
- **형광펜 (하일라이터)**:
  - 굵고 반투명한 노란색 스트로크(`opacity: 0.38`, 기본 22pt)와 `.multiply` 블렌드 모드를 적용하여 글자를 가리지 않고 도표/텍스트를 부드럽게 강조.
- **텍스트 타이핑**:
  - 슬라이드 원하는 곳을 클릭하면 인라인 `NSTextField`가 즉시 열려 키보드로 메모 입력 가능.
  - Enter로 완료 시 학생 화면에도 정규화 좌표계 기반으로 동일한 위치에 깔끔한 배지와 텍스트로 실시간 렌더링.

### 4.7 PDFView 내부 키보드 이벤트(스페이스바, 좌우 화살표) 삼킴 문제 해결
- **증상**: 슬라이드 모드에서 강사용 창 포커스 시 스페이스바나 좌우 화살표 키를 눌러도 슬라이드가 넘어가지 않는 현상 발생.
- **원인 분석**:
  - `PDFView`의 내부 `NSScrollView`/`PDFClipView`가 First Responder로 키 이벤트를 수신하면, 자체적인 상하좌우 스크롤 로직으로 이벤트를 소비(`keyDown` 흡수)하여 상위 SwiftUI의 `.keyboardShortcut()` 핸들러까지 이벤트가 도달하지 못함.
- **해결**:
  - AppKit 레벨의 로컬 이벤트 모니터 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`를 `PresenterModel.setupKeyboardMonitor()`에 구현.
  - 현재 First Responder가 텍스트 필드(`NSTextView`, `NSTextField`)인지 확인하여, 텍스트 타이핑 중일 때는 원본 이벤트를 그대로 통과시킴.
  - 그 외의 경우 `Space(49)`, `Right Arrow(124)`, `Left Arrow(123)`, `Down Arrow(125)`, `Up Arrow(126)`, `PageDown(121)`, `PageUp(116)` 및 단일 키 도구 토글(`B`, `L`, `P`, `H`, `T`, `E`)을 가로채어 `PresenterModel`의 상태를 즉각 변경하고 이벤트를 `nil`로 소비하여 완벽하고 즉각적인 슬라이드 전환을 보장.

### 4.8 강사/학생 창 화면 비율(Aspect Ratio) 불일치 및 Zoom 공유 시 레터박스 방지
- **증상**: 강사용 작업 창과 학생용 창의 가로세로 비율이 다르면 화상회의(Zoom, Google Meet) 공유 시 불필요한 검은 여백(Letterbox)이 발생하거나, 연속 스크롤 시 한 화면에 보이는 영역의 상하 길이가 달라 싱크 체감이 저하됨.
- **해결**:
  - `PresenterModel`에 `AspectRatioMode` 열거형 및 `pdfPageSize`, `instructorViewportSize` 상태 추가.
  - 강사용 화면의 뷰포트 크기를 `GeometryReader`로 실시간 추적.
  - `StudentWindowController.applyAspectRatio(_:nativeSize:)` 구현:
    1. **PDF 원본 비율 (`.pdfNative`)**: PDF 문서 첫 페이지의 실제 CropBox 비율로 학생 창의 가로세로를 동기화하고 `window.contentAspectRatio`를 고정.
    2. **강사 뷰 비율 복제 (`.matchInstructor`)**: 강사의 현재 메인 PDF 뷰포트 가로세로 비율로 학생 창의 높이를 자동 재계산하고 크기 조절 제약을 동기화.
    3. **16:9 와이드 / 4:3 표준**: 발표 표준 비율 프리셋 원클릭 지원.
    4. **자유 조절 (`.free`)**: 제약 해제(`contentAspectRatio = (0, 0)`).
  - 강사용 대시보드 우측 패널에 원클릭 퀵 비율 버튼 패널을 배치하여 직관적으로 모드를 전환할 수 있도록 구현 완료.

---

## 5. 빌드 및 배포 패키징
- `build_app.sh`: Release 최적화 빌드 후 Info.plist, AppIcon.icns, 번들 구조를 구성하고 ad-hoc codesign 적용.
- `install_to_applications.sh`: `/Applications/DualLecturePresenter.app`으로 1클릭 설치 및 실행 지원.
- `SamplePDFGenerator.swift`: 첫 실행 시 앱 내 테스트용 강사용/학생용 PDF 자동 탑재.
