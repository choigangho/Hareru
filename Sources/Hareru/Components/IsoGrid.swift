import CoreGraphics

// MARK: - 2:1 아이소메트릭 격자 ↔ 화면 좌표 변환 (Docs/GAME_DESIGN.md §9.1)
// 화면 좌표 변환은 이 타입 한 곳에서만 합니다. 앞뒤 가림은 (column + row) 합으로 정렬.
public struct IsoGrid: Equatable, Sendable {
    /// 아트 픽셀 1칸을 몇 pt로 그릴지 (정수 배율이어야 픽셀이 뭉개지지 않음)
    public let pixelScale: CGFloat
    /// 바닥 타일 크기 (아트 픽셀) — 2:1
    public static let tileArtWidth: CGFloat = 32
    public static let tileArtHeight: CGFloat = 16
    /// 격자 (0, 0) 타일 윗꼭짓점의 화면 위치
    public let origin: CGPoint

    public init(pixelScale: CGFloat, origin: CGPoint) {
        self.pixelScale = max(1, pixelScale.rounded(.down))
        self.origin = origin
    }

    public var tileWidth: CGFloat { Self.tileArtWidth * pixelScale }
    public var tileHeight: CGFloat { Self.tileArtHeight * pixelScale }

    /// 타일 윗꼭짓점 (마름모의 위쪽 끝)
    public func topCorner(column: Int, row: Int) -> CGPoint {
        CGPoint(
            x: origin.x + CGFloat(column - row) * tileWidth / 2,
            y: origin.y + CGFloat(column + row) * tileHeight / 2
        )
    }

    /// 타일 중심
    public func center(column: Int, row: Int) -> CGPoint {
        let top = topCorner(column: column, row: row)
        return CGPoint(x: top.x, y: top.y + tileHeight / 2)
    }

    /// 화면의 한 점이 어느 타일 위에 있는지 (격자 밖일 수 있음)
    public func cell(at point: CGPoint) -> (column: Int, row: Int) {
        let dx = (point.x - origin.x) / (tileWidth / 2)
        let dy = (point.y - origin.y) / (tileHeight / 2)
        return (Int(((dy + dx) / 2).rounded(.down)), Int(((dy - dx) / 2).rounded(.down)))
    }

    /// 격자 전체가 차지하는 크기 (columns × rows)
    public static func size(columns: Int, rows: Int, pixelScale: CGFloat) -> CGSize {
        let scale = max(1, pixelScale.rounded(.down))
        return CGSize(
            width: CGFloat(columns + rows) * tileArtWidth * scale / 2,
            height: CGFloat(columns + rows) * tileArtHeight * scale / 2
        )
    }
}
