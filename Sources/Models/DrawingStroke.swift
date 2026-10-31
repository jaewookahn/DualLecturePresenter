import SwiftUI

public struct DrawingStroke: Identifiable, Equatable {
    public let id: UUID
    public let pageIndex: Int
    public var points: [CGPoint] // Normalized (0.0 ... 1.0) relative to page bounds
    public var color: Color
    public var lineWidth: CGFloat
    
    public init(id: UUID = UUID(), pageIndex: Int, points: [CGPoint] = [], color: Color = .red, lineWidth: CGFloat = 3.0) {
        self.id = id
        self.pageIndex = pageIndex
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
    }
}

public enum ToolMode: String, CaseIterable, Identifiable {
    case navigation = "기본 포인터"
    case laser = "레이저 포인터"
    case pen = "펜 필기"
    case eraser = "지우개"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .navigation: return "arrow.up.left"
        case .laser: return "smallcircle.filled.circle"
        case .pen: return "pencil.tip"
        case .eraser: return "eraser"
        }
    }
}
