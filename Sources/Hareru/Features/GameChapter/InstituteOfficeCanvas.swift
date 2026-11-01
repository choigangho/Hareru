import SwiftUI

// MARK: - 1단계 사무실 아이소메트릭 픽셀 디오라마 (M1 임시 아트 — 코드로 그린 픽셀 블록)
// 실제 픽셀 아트 에셋이 생기면 이 파일의 draw* 함수만 이미지 그리기로 바꾸면 됨.
struct InstituteOfficeCanvas: View {
    let state: InstituteState
    let activeCombos: [FacilityCombo]
    let selectedCell: GridPosition?
    let placingKind: FacilityKind?
    var onTapCell: (GridPosition) -> Void

    static let wallArtHeight: CGFloat = 40
    static let artWidth: CGFloat = CGFloat(InstituteState.gridColumns + InstituteState.gridRows) * IsoGrid.tileArtWidth / 2
    static let artHeight: CGFloat = wallArtHeight + CGFloat(InstituteState.gridColumns + InstituteState.gridRows) * IsoGrid.tileArtHeight / 2 + 4

    var body: some View {
        GeometryReader { geo in
            let scale = max(1, (min(geo.size.width / Self.artWidth, geo.size.height / Self.artHeight)).rounded(.down))
            let drawnSize = CGSize(width: Self.artWidth * scale, height: Self.artHeight * scale)
            let grid = IsoGrid(
                pixelScale: scale,
                origin: CGPoint(
                    x: (geo.size.width / 2).rounded(),
                    y: ((geo.size.height - drawnSize.height) / 2 + Self.wallArtHeight * scale).rounded()
                )
            )

            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                let tick = Int(timeline.date.timeIntervalSinceReferenceDate * 2)
                Canvas { context, _ in
                    drawWalls(&context, grid: grid, tick: tick)
                    drawFloor(&context, grid: grid)
                    drawObjects(&context, grid: grid, tick: tick)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let hit = grid.cell(at: value.location)
                    let position = GridPosition(column: hit.column, row: hit.row)
                    if (0..<InstituteState.gridColumns).contains(hit.column),
                       (0..<InstituteState.gridRows).contains(hit.row) {
                        onTapCell(position)
                    }
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("연구소 사무실. 시설 \(state.facilities.count)개 배치됨")
    }

    // MARK: - 바닥

    private func diamond(_ grid: IsoGrid, column: Int, row: Int, lift: CGFloat = 0) -> Path {
        let top = grid.topCorner(column: column, row: row)
        let w = grid.tileWidth / 2, h = grid.tileHeight / 2
        var path = Path()
        path.move(to: CGPoint(x: top.x, y: top.y - lift))
        path.addLine(to: CGPoint(x: top.x + w, y: top.y + h - lift))
        path.addLine(to: CGPoint(x: top.x, y: top.y + 2 * h - lift))
        path.addLine(to: CGPoint(x: top.x - w, y: top.y + h - lift))
        path.closeSubpath()
        return path
    }

    private func drawFloor(_ context: inout GraphicsContext, grid: IsoGrid) {
        for row in 0..<InstituteState.gridRows {
            for column in 0..<InstituteState.gridColumns {
                let even = (column + row) % 2 == 0
                let tile = diamond(grid, column: column, row: row)
                context.fill(tile, with: .color(even ? Self.floorLight : Self.floorDark))
                context.stroke(tile, with: .color(Self.floorSeam), lineWidth: grid.pixelScale / 2)

                let position = GridPosition(column: column, row: row)
                if position == selectedCell {
                    let canPlaceHere = placingKind.map { _ in !state.facilities.contains { $0.position == position } } ?? true
                    context.fill(tile, with: .color((canPlaceHere ? Color.white : Color.red).opacity(0.35)))
                    context.stroke(tile, with: .color(.white), lineWidth: grid.pixelScale)
                }
            }
        }
    }

    // MARK: - 뒤쪽 벽 두 면 + 창문 (연구소 하늘이 보임)

    private func drawWalls(_ context: inout GraphicsContext, grid: IsoGrid, tick: Int) {
        let wallHeight = Self.wallArtHeight * grid.pixelScale
        let topLeftEnd = grid.topCorner(column: 0, row: InstituteState.gridRows)
        let origin = grid.topCorner(column: 0, row: 0)
        let topRightEnd = grid.topCorner(column: InstituteState.gridColumns, row: 0)

        func wall(_ a: CGPoint, _ b: CGPoint) -> Path {
            var p = Path()
            p.move(to: a)
            p.addLine(to: b)
            p.addLine(to: CGPoint(x: b.x, y: b.y - wallHeight))
            p.addLine(to: CGPoint(x: a.x, y: a.y - wallHeight))
            p.closeSubpath()
            return p
        }
        context.fill(wall(topLeftEnd, origin), with: .color(Self.wallShade))
        context.fill(wall(origin, topRightEnd), with: .color(Self.wallLight))

        // 오른쪽 벽 창문 2개 — 연구소 날씨(영향력)에 따라 비 · 흐림 · 맑음
        for index in [1, 4] {
            let a = grid.topCorner(column: index, row: 0)
            let b = grid.topCorner(column: index + 1, row: 0)
            let inset = 10 * grid.pixelScale
            var window = Path()
            window.move(to: CGPoint(x: a.x, y: a.y - inset))
            window.addLine(to: CGPoint(x: b.x, y: b.y - inset))
            window.addLine(to: CGPoint(x: b.x, y: b.y - wallHeight + 6 * grid.pixelScale))
            window.addLine(to: CGPoint(x: a.x, y: a.y - wallHeight + 6 * grid.pixelScale))
            window.closeSubpath()
            context.fill(window, with: .color(skyColor))
            if state.instituteSky == .rain {
                // 비: 창문 안에서 아래로 떨어지는 픽셀 빗줄기
                for drop in 0..<4 {
                    let fraction = (CGFloat((drop * 7 + tick) % 10) / 10)
                    let x = a.x + (b.x - a.x) * (CGFloat(drop) + 0.5) / 4
                    let yTop = a.y + (b.y - a.y) * (CGFloat(drop) + 0.5) / 4 - wallHeight + 8 * grid.pixelScale
                    let y = yTop + fraction * (wallHeight - 20 * grid.pixelScale)
                    context.fill(Path(CGRect(x: x, y: y, width: grid.pixelScale, height: 3 * grid.pixelScale)),
                                 with: .color(.white.opacity(0.7)))
                }
            } else if state.instituteSky == .clear {
                let sun = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - wallHeight + 14 * grid.pixelScale)
                context.fill(Path(CGRect(x: sun.x - 2 * grid.pixelScale, y: sun.y - 2 * grid.pixelScale,
                                         width: 4 * grid.pixelScale, height: 4 * grid.pixelScale)),
                             with: .color(Color(red: 1.0, green: 0.86, blue: 0.4)))
            }
            context.stroke(window, with: .color(Self.windowFrame), lineWidth: grid.pixelScale)
        }
    }

    private var skyColor: Color {
        switch state.instituteSky {
        case .rain: return Color(red: 0.36, green: 0.43, blue: 0.53)
        case .cloudy: return Color(red: 0.62, green: 0.68, blue: 0.75)
        default: return Color(red: 0.55, green: 0.78, blue: 0.96)
        }
    }

    // MARK: - 시설 · 연구원 (앞뒤 가림: column + row 순서)

    private func drawObjects(_ context: inout GraphicsContext, grid: IsoGrid, tick: Int) {
        let comboKinds = Set(activeCombos.flatMap { [$0.pair.0, $0.pair.1] })
        let guidePosition = GridPosition(
            column: InstituteState.deskPosition.column,
            row: InstituteState.deskPosition.row + 1
        )
        let ordered = state.facilities.sorted {
            ($0.position.column + $0.position.row, $0.position.column) < ($1.position.column + $1.position.row, $1.position.column)
        }
        var guideDrawn = false
        for facility in ordered {
            let depth = facility.position.column + facility.position.row
            if !guideDrawn, guidePosition.column + guidePosition.row < depth {
                drawGuide(&context, grid: grid, at: guidePosition, tick: tick)
                guideDrawn = true
            }
            drawFacility(&context, grid: grid, facility: facility,
                         highlighted: comboKinds.contains(facility.kind), tick: tick)
        }
        if !guideDrawn, state.facilities.contains(where: { $0.position == guidePosition }) == false {
            drawGuide(&context, grid: grid, at: guidePosition, tick: tick)
        }
    }

    private func drawFacility(
        _ context: inout GraphicsContext, grid: IsoGrid, facility: PlacedFacility, highlighted: Bool, tick: Int
    ) {
        let style = Self.style(for: facility.kind)
        let column = facility.position.column, row = facility.position.row
        let height = style.artHeight * grid.pixelScale
        let top = grid.topCorner(column: column, row: row)
        let w = grid.tileWidth / 2 - 2 * grid.pixelScale, h = grid.tileHeight / 2 - grid.pixelScale
        let center = CGPoint(x: top.x, y: top.y + grid.tileHeight / 2)

        // 블록 세 면: 윗면 · 왼쪽 앞면 · 오른쪽 앞면
        var left = Path()
        left.move(to: CGPoint(x: center.x - w, y: center.y))
        left.addLine(to: CGPoint(x: center.x, y: center.y + h))
        left.addLine(to: CGPoint(x: center.x, y: center.y + h - height))
        left.addLine(to: CGPoint(x: center.x - w, y: center.y - height))
        left.closeSubpath()
        var right = Path()
        right.move(to: CGPoint(x: center.x + w, y: center.y))
        right.addLine(to: CGPoint(x: center.x, y: center.y + h))
        right.addLine(to: CGPoint(x: center.x, y: center.y + h - height))
        right.addLine(to: CGPoint(x: center.x + w, y: center.y - height))
        right.closeSubpath()
        var topFace = Path()
        topFace.move(to: CGPoint(x: center.x, y: center.y - h - height))
        topFace.addLine(to: CGPoint(x: center.x + w, y: center.y - height))
        topFace.addLine(to: CGPoint(x: center.x, y: center.y + h - height))
        topFace.addLine(to: CGPoint(x: center.x - w, y: center.y - height))
        topFace.closeSubpath()

        context.fill(left, with: .color(style.left))
        context.fill(right, with: .color(style.right))
        context.fill(topFace, with: .color(style.top))

        // 시설별 픽셀 디테일 (오른쪽 앞면에 가로줄·점)
        let px = grid.pixelScale
        switch facility.kind {
        case .kanjiArchive:
            for shelf in 1...3 {
                let y = center.y + h - height + CGFloat(shelf) * height / 4
                for book in 0..<5 {
                    let x = center.x + 2 * px + CGFloat(book) * (w - 4 * px) / 5
                    let colors: [Color] = [.red, .orange, .teal, .indigo, .brown]
                    context.fill(Path(CGRect(x: x, y: y - 5 * px - CGFloat(book) * h / CGFloat(10), width: 2 * px, height: 5 * px)),
                                 with: .color(colors[(book + shelf) % colors.count].opacity(0.85)))
                }
            }
        case .serverRack:
            for slot in 0..<4 {
                let y = center.y + h - height + CGFloat(slot + 1) * height / 5
                let blinkOn = (tick + slot) % 3 != 0
                context.fill(Path(CGRect(x: center.x + 4 * px, y: y - 2 * px, width: 2 * px, height: 2 * px)),
                             with: .color(blinkOn ? .green : .green.opacity(0.25)))
            }
        case .recordingBooth:
            let micX = center.x - px, micY = center.y - height - 2 * px
            context.fill(Path(CGRect(x: micX, y: micY - 6 * px, width: 2 * px, height: 6 * px)), with: .color(.black.opacity(0.7)))
            context.fill(Path(CGRect(x: micX - px, y: micY - 9 * px, width: 4 * px, height: 4 * px)), with: .color(.gray))
        case .copyRoom:
            context.fill(Path(CGRect(x: center.x - 4 * px, y: center.y - height - 2 * px, width: 8 * px, height: 4 * px)),
                         with: .color(.white))
            context.fill(Path(CGRect(x: center.x - 2 * px, y: center.y - height - px, width: 4 * px, height: px)),
                         with: .color(.black.opacity(0.6)))
        case .researcherDesk:
            // 책상 위 노트북 + 책 더미
            context.fill(Path(CGRect(x: center.x - 6 * px, y: center.y - height - 4 * px, width: 6 * px, height: 4 * px)),
                         with: .color(Color(white: 0.85)))
            context.fill(Path(CGRect(x: center.x + 2 * px, y: center.y - height - 5 * px, width: 4 * px, height: 5 * px)),
                         with: .color(.red.opacity(0.8)))
        }

        let outlineWidth = highlighted ? px : px / 2
        let outline = highlighted ? Color(red: 1.0, green: 0.86, blue: 0.4) : Color.black.opacity(0.35)
        context.stroke(left, with: .color(outline), lineWidth: outlineWidth)
        context.stroke(right, with: .color(outline), lineWidth: outlineWidth)
        context.stroke(topFace, with: .color(outline), lineWidth: outlineWidth)
    }

    // MARK: - 가이드 연구원 픽셀 스프라이트 (단발 · 안경 · 흰 가운)

    private static let guideSprite = [
        "..hhhh..",
        ".hhhhhh.",
        ".hssssh.",
        ".gegeg..",
        ".hssssh.",
        "..ssss..",
        "..cccc..",
        ".cccccc.",
        "scccccs.",
        ".cccccc.",
        "..cccc..",
        "..pppp..",
        "..p..p..",
        "..k..k.."
    ]

    private func drawGuide(_ context: inout GraphicsContext, grid: IsoGrid, at position: GridPosition, tick: Int) {
        let px = grid.pixelScale
        let center = grid.center(column: position.column, row: position.row)
        let bob: CGFloat = tick % 2 == 0 ? 0 : -px
        let spriteHeight = CGFloat(Self.guideSprite.count) * px
        let originX = center.x - 4 * px
        let originY = center.y - spriteHeight + 2 * px + bob

        // 발밑 그림자
        context.fill(Path(ellipseIn: CGRect(x: center.x - 5 * px, y: center.y, width: 10 * px, height: 3 * px)),
                     with: .color(.black.opacity(0.25)))
        let palette: [Character: Color] = [
            "h": Color(red: 0.16, green: 0.13, blue: 0.16),
            "s": Color(red: 0.98, green: 0.86, blue: 0.76),
            "g": Color(red: 0.25, green: 0.30, blue: 0.40),
            "e": Color(red: 0.55, green: 0.75, blue: 0.95),
            "c": Color(red: 0.96, green: 0.96, blue: 0.98),
            "p": Color(red: 0.25, green: 0.30, blue: 0.42),
            "k": Color(red: 0.15, green: 0.15, blue: 0.18)
        ]
        for (y, line) in Self.guideSprite.enumerated() {
            for (x, char) in line.enumerated() {
                guard let color = palette[char] else { continue }
                context.fill(Path(CGRect(x: originX + CGFloat(x) * px, y: originY + CGFloat(y) * px, width: px, height: px)),
                             with: .color(color))
            }
        }
    }

    // MARK: - 임시 팔레트

    private struct BlockStyle {
        let artHeight: CGFloat
        let top: Color
        let left: Color
        let right: Color
    }

    private static func style(for kind: FacilityKind) -> BlockStyle {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch kind {
        case .researcherDesk:
            return BlockStyle(artHeight: 10, top: rgb(0.66, 0.46, 0.28), left: rgb(0.50, 0.33, 0.20), right: rgb(0.42, 0.27, 0.16))
        case .kanjiArchive:
            return BlockStyle(artHeight: 28, top: rgb(0.48, 0.33, 0.21), left: rgb(0.38, 0.25, 0.15), right: rgb(0.32, 0.21, 0.13))
        case .copyRoom:
            return BlockStyle(artHeight: 12, top: rgb(0.85, 0.82, 0.74), left: rgb(0.68, 0.64, 0.56), right: rgb(0.60, 0.56, 0.49))
        case .recordingBooth:
            return BlockStyle(artHeight: 30, top: rgb(0.52, 0.72, 0.86), left: rgb(0.38, 0.56, 0.70), right: rgb(0.32, 0.48, 0.62))
        case .serverRack:
            return BlockStyle(artHeight: 32, top: rgb(0.24, 0.28, 0.34), left: rgb(0.17, 0.20, 0.25), right: rgb(0.13, 0.15, 0.19))
        }
    }

    private static let floorLight = Color(red: 0.79, green: 0.64, blue: 0.48)
    private static let floorDark = Color(red: 0.72, green: 0.57, blue: 0.42)
    private static let floorSeam = Color(red: 0.55, green: 0.42, blue: 0.30).opacity(0.6)
    private static let wallLight = Color(red: 0.90, green: 0.86, blue: 0.78)
    private static let wallShade = Color(red: 0.80, green: 0.75, blue: 0.67)
    private static let windowFrame = Color(red: 0.45, green: 0.36, blue: 0.27)
}
