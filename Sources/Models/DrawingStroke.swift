import SwiftUI

public struct DrawingStroke: Identifiable, Equatable {
    public let id: UUID
    public let pageIndex: Int
    public var points: [CGPoint] // Normalized (0.0 ... 1.0) relative to page bounds
    public var color: Color
    public var lineWidth: CGFloat
    public var isHighlighter: Bool
    
    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        points: [CGPoint] = [],
        color: Color = .red,
        lineWidth: CGFloat = 3.5,
        isHighlighter: Bool = false
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.isHighlighter = isHighlighter
    }
}

public struct TextAnnotation: Identifiable, Equatable {
    public let id: UUID
    public let pageIndex: Int
    public var normalizedPosition: CGPoint // (0.0 ... 1.0) on page
    public var text: String
    public var fontSize: CGFloat
    public var color: Color
    public var hasBackground: Bool
    
    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        normalizedPosition: CGPoint,
        text: String = "",
        fontSize: CGFloat = 18.0,
        color: Color = .red,
        hasBackground: Bool = true
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.normalizedPosition = normalizedPosition
        self.text = text
        self.fontSize = fontSize
        self.color = color
        self.hasBackground = hasBackground
    }
}

public enum ToolMode: String, CaseIterable, Identifiable {
    case navigation = "기본 포인터"
    case laser = "레이저 포인터"
    case pen = "펜 필기"
    case highlighter = "형광펜"
    case text = "텍스트"
    case eraser = "지우개"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .navigation: return "arrow.up.left"
        case .laser: return "smallcircle.filled.circle"
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .text: return "character.cursor.ibeam"
        case .eraser: return "eraser"
        }
    }
}
