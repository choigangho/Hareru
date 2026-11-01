import SwiftUI

// MARK: - 1단계 사무실 아이소메트릭 픽셀 디오라마 (M1 임시 아트 — 코드로 그린 픽셀 블록)
// 실제 픽셀 아트 에셋이 생기면 이 파일의 draw* 함수만 이미지 그리기로 바꾸면 됨.
struct InstituteOfficeCanvas: View {
    let state: InstituteState
    /// 실제로 맞닿아 콤보를 이룬 시설만 금색 테두리
    let comboMemberIDs: Set<String>
    /// 화면 전용 시뮬레이션 (연구원 이동 · 버블 · 복원 연출). 저장 데이터는 건드리지 않음
    let runtime: OfficeSimulationRuntime
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

            // 30fps: 이동 계산은 매끄럽게, 그리기는 아트 픽셀 단위로 맞춤
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let tick = Int(time * 2)
                Canvas { context, _ in
                    runtime.update(time: time, facilities: state.facilities)
                    drawWalls(&context, grid: grid, tick: tick)
                    drawFloor(&context, grid: grid)
                    drawObjects(&context, grid: grid, time: time)
                    drawRestorationGauge(&context, grid: grid, time: time)
                    drawBubbles(&context, grid: grid, time: time)
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

    private func drawObjects(_ context: inout GraphicsContext, grid: IsoGrid, time: Double) {
        let tick = Int(time * 2)
        let agentPosition = runtime.agent.visualPosition

        // 앞뒤 가림: (column + row) 합이 작은 것부터. 연구원은 이동 중에도 실수 좌표로 매 프레임 정렬
        enum Drawable { case facility(PlacedFacility), agent }
        var items: [(key: CGFloat, item: Drawable)] = state.facilities.map {
            (CGFloat($0.position.column + $0.position.row), .facility($0))
        }
        items.append((agentPosition.column + agentPosition.row + 0.01, .agent))
        items.sort { $0.key < $1.key }

        for entry in items {
            switch entry.item {
            case .facility(let facility):
                drawFacility(&context, grid: grid, facility: facility,
                             highlighted: comboMemberIDs.contains(facility.id), tick: tick,
                             drop: runtime.dropProgress(for: facility.id, time: time))
            case .agent:
                drawGuide(&context, grid: grid, at: agentPosition, time: time)
            }
        }
    }

    /// 실수 격자 좌표 → 아트 픽셀에 맞춘 화면 좌표 (서브픽셀 이동으로 픽셀이 흐려지지 않게)
    private func snappedCenter(_ grid: IsoGrid, column: CGFloat, row: CGFloat) -> CGPoint {
        let raw = CGPoint(
            x: grid.origin.x + (column - row) * grid.tileWidth / 2,
            y: grid.origin.y + (column + row) * grid.tileHeight / 2 + grid.tileHeight / 2
        )
        let px = grid.pixelScale
        return CGPoint(x: (raw.x / px).rounded() * px, y: (raw.y / px).rounded() * px)
    }

    private func drawFacility(
        _ context: inout GraphicsContext, grid: IsoGrid, facility: PlacedFacility, highlighted: Bool, tick: Int,
        drop: Double?
    ) {
        let style = Self.style(for: facility.kind)
        let column = facility.position.column, row = facility.position.row
        let height = style.artHeight * grid.pixelScale
        let top = grid.topCorner(column: column, row: row)
        let w = grid.tileWidth / 2 - 2 * grid.pixelScale, h = grid.tileHeight / 2 - grid.pixelScale
        // 설치 직후: 위에서 떨어져 착지하며 살짝 튐 (아트 픽셀 단위로 끊어서)
        let dropLift: CGFloat = drop.map { t in
            let fall = t < 0.7 ? 18 * (1 - t / 0.7) * (1 - t / 0.7) : 0
            let bounce = t >= 0.7 ? 3 * sin((t - 0.7) / 0.3 * .pi) : 0
            return (CGFloat(fall + bounce)).rounded() * grid.pixelScale
        } ?? 0
        let center = CGPoint(x: top.x, y: top.y + grid.tileHeight / 2 - dropLift)

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

    private func drawGuide(_ context: inout GraphicsContext, grid: IsoGrid, at position: (column: CGFloat, row: CGFloat), time: Double) {
        let px = grid.pixelScale
        let center = snappedCenter(grid, column: position.column, row: position.row)
        // 걸을 때는 초당 8장으로 통통 튀고, 서 있을 때는 천천히 숨쉬기
        let frame = runtime.agent.isWalking ? Int(time * 8) % 2 : Int(time * 1.5) % 2
        let bob: CGFloat = frame == 0 ? 0 : -px
        let spriteHeight = CGFloat(Self.guideSprite.count) * px
        let originX = center.x - 4 * px
        let originY = center.y - spriteHeight + 2 * px + bob
        let mirrored = !runtime.agent.facingRight

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
                let column = mirrored ? 7 - x : x
                context.fill(Path(CGRect(x: originX + CGFloat(column) * px, y: originY + CGFloat(y) * px, width: px, height: px)),
                             with: .color(color))
            }
        }
    }

    // MARK: - 복원 진행 게이지 (책상 위: 복원 중인 한자 + 픽셀 막대)

    private func drawRestorationGauge(_ context: inout GraphicsContext, grid: IsoGrid, time: Double) {
        guard let show = runtime.restoration else { return }
        let px = grid.pixelScale
        let desk = InstituteState.deskPosition
        let anchor = snappedCenter(grid, column: CGFloat(desk.column), row: CGFloat(desk.row))
        let barWidth = 28 * px, barHeight = 4 * px
        let barOrigin = CGPoint(x: anchor.x - barWidth / 2, y: anchor.y - 34 * px)
        let progress = CGFloat(show.progress(at: time))

        let kanji = context.resolve(Text(show.insight.kanji).font(JLPTFont.termMincho(size: 13 * px)).foregroundColor(.white))
        context.draw(kanji, at: CGPoint(x: anchor.x, y: barOrigin.y - 9 * px), anchor: .center)
        context.fill(Path(CGRect(x: barOrigin.x - px, y: barOrigin.y - px, width: barWidth + 2 * px, height: barHeight + 2 * px)),
                     with: .color(.black.opacity(0.6)))
        context.fill(Path(CGRect(x: barOrigin.x, y: barOrigin.y, width: barWidth, height: barHeight)),
                     with: .color(.white.opacity(0.18)))
        let filled = ((barWidth * progress) / px).rounded(.down) * px
        let barColor = show.insight.isCritical ? Color(red: 1.0, green: 0.78, blue: 0.3) : Color(red: 0.55, green: 0.85, blue: 0.75)
        context.fill(Path(CGRect(x: barOrigin.x, y: barOrigin.y, width: filled, height: barHeight)), with: .color(barColor))
    }

    // MARK: - 떠오르는 버블 (톡 튀어나와 떠오르며 사라짐)

    private func drawBubbles(_ context: inout GraphicsContext, grid: IsoGrid, time: Double) {
        let px = grid.pixelScale
        for bubble in runtime.bubbles where time >= bubble.born {
            let t = bubble.progress(at: time)
            let rise = runtime.reduceMotion ? 0 : CGFloat(1 - pow(1 - t, 3)) * 16
            let pop = t < 0.12 ? 0.7 + 0.3 * (t / 0.12) : 1.0
            let opacity = t < 0.7 ? 1.0 : (1 - t) / 0.3
            let base = snappedCenter(grid, column: bubble.anchorColumn, row: bubble.anchorRow)
            // 머리 위 22 아트 픽셀에서 시작해 떠오름 — 아트 픽셀 단위로 반올림
            let center = CGPoint(x: base.x, y: base.y - (22 + rise).rounded() * px)

            let (fill, textColor, size) = Self.bubbleStyle(bubble.style)
            let text = context.resolve(
                Text(bubble.text)
                    .font(.system(size: size * px * pop, weight: .heavy, design: .rounded))
                    .foregroundColor(textColor)
            )
            let textSize = text.measure(in: CGSize(width: 400, height: 100))
            let pill = CGRect(x: center.x - textSize.width / 2 - 3 * px, y: center.y - textSize.height / 2 - px,
                              width: textSize.width + 6 * px, height: textSize.height + 2 * px)
            var layer = context
            layer.opacity = opacity
            if bubble.style != .emote {
                layer.fill(Path(roundedRect: pill, cornerRadius: 2 * px), with: .color(fill))
                layer.stroke(Path(roundedRect: pill, cornerRadius: 2 * px), with: .color(.black.opacity(0.35)), lineWidth: px / 2)
            }
            layer.draw(text, at: center, anchor: .center)
        }
    }

    private static func bubbleStyle(_ style: FloatingBubble.Style) -> (Color, Color, CGFloat) {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch style {
        case .points: return (rgb(0.36, 0.62, 0.95), .white, 6)
        case .budget: return (rgb(0.96, 0.74, 0.25), rgb(0.25, 0.17, 0.05), 6)
        case .combo: return (rgb(1.0, 0.86, 0.4), rgb(0.35, 0.2, 0.0), 7)
        case .stat: return (rgb(0.98, 0.97, 0.93), rgb(0.25, 0.27, 0.35), 6)
        case .critical: return (rgb(0.95, 0.35, 0.35), .white, 8)
        case .emote: return (.clear, .white, 7)
        case .done: return (rgb(0.35, 0.75, 0.6), .white, 8)
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
