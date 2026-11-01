import SpriteKit

// MARK: - 연구소 사무실 SpriteKit 장면
// - 저장 데이터(InstituteState)는 apply(...)로 받아 노드만 맞춰 그림 — 장면이 자원을 바꾸는 일은 없음
// - 연구원 이동 · 버블 · 복원 연출은 OfficeSimulationRuntime(테스트로 고정된 화면 전용 상태)을 매 프레임 따라 그림
// - 좌표: 격자 ↔ 화면 변환은 IsoGrid(뷰 좌표, 위-왼쪽 원점) 한 곳에서, 장면 좌표는 y만 뒤집음
// - 픽셀: 텍스처는 아트 해상도 + 최근접 필터링, 노드는 정수 배율, 위치는 아트 픽셀 단위로 맞춤
final class OfficeScene: SKScene {
    let runtime: OfficeSimulationRuntime

    private(set) var grid: IsoGrid?
    private(set) var pixelScale: CGFloat = 1

    private var state = InstituteState()
    private var comboMemberIDs: Set<String> = []
    private var selectedCell: GridPosition?
    private var isPlacing = false

    private let roomNode = SKSpriteNode()
    private let selectionNode = SKShapeNode()
    private let agentNode = SKSpriteNode()
    private let newcomerNode = SKSpriteNode()
    private let gaugeNode = SKNode()
    private let gaugeLabel = SKLabelNode(fontNamed: "HiraMinProN-W6")
    private let gaugeTrack = SKSpriteNode(color: .white, size: .zero)
    private let gaugeFill = SKSpriteNode(color: .white, size: .zero)
    private var facilityNodes: [String: SKSpriteNode] = [:]
    /// 벽가 장식 소품 (OfficePixelArt.decorPlacements 순서, 에셋이 없으면 비어 있음)
    private var decorNodes: [(node: SKSpriteNode, cell: GridPosition, artSize: CGSize)] = []
    private var bubbleNodes: [UUID: SKNode] = [:]

    private var textureCache: [String: SKTexture] = [:]
    private lazy var chiefFrames = OfficePixelArt.characterFrames(.chief)
    private lazy var newcomerFrames = OfficePixelArt.characterFrames(.newcomer)

    init(runtime: OfficeSimulationRuntime) {
        self.runtime = runtime
        super.init(size: CGSize(width: 390, height: 400))
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero

        roomNode.texture = OfficePixelArt.makeRoom()
        roomNode.zPosition = 0
        addChild(roomNode)

        for decor in OfficePixelArt.decorPlacements {
            guard let image = OfficePixelArt.bundledImage(decor.asset) else { continue }
            let node = SKSpriteNode(texture: OfficePixelArt.texture(image))
            let density = CGFloat(OfficePixelArt.assetDensity)
            let artSize = CGSize(width: CGFloat(image.width) / density, height: CGFloat(image.height) / density)
            // 소품 바닥이 타일 중심보다 4px 아래 → 벽에 붙어 서 있는 느낌
            node.anchorPoint = CGPoint(x: 0.5, y: 4 / artSize.height)
            addChild(node)
            decorNodes.append((node, decor.cell, artSize))
        }

        selectionNode.zPosition = 5
        selectionNode.isHidden = true
        addChild(selectionNode)

        for node in [agentNode, newcomerNode] {
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            addChild(node)
        }

        gaugeLabel.fontColor = .white
        gaugeLabel.verticalAlignmentMode = .bottom
        gaugeTrack.anchorPoint = CGPoint(x: 0, y: 0.5)
        gaugeTrack.color = SKColor(white: 0, alpha: 0.55)
        gaugeFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        gaugeNode.addChild(gaugeTrack)
        gaugeNode.addChild(gaugeFill)
        gaugeNode.addChild(gaugeLabel)
        gaugeNode.zPosition = 900
        gaugeNode.isHidden = true
        addChild(gaugeNode)

        layoutRoom()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - 바깥(SwiftUI)에서 받는 저장 상태

    func apply(state: InstituteState, comboMemberIDs: Set<String>, selectedCell: GridPosition?, isPlacing: Bool) {
        self.state = state
        self.comboMemberIDs = comboMemberIDs
        self.selectedCell = selectedCell
        self.isPlacing = isPlacing
        syncFacilities(frame: 0)
        syncDecor()
        syncSelection()
    }

    /// SwiftUI 탭 위치(뷰 좌표) → 격자 칸. 격자 밖이면 nil
    func cell(atViewPoint point: CGPoint) -> GridPosition? {
        guard let grid else { return nil }
        let hit = grid.cell(at: point)
        let position = GridPosition(column: hit.column, row: hit.row)
        guard (0..<InstituteState.gridColumns).contains(hit.column),
              (0..<InstituteState.gridRows).contains(hit.row) else { return nil }
        return position
    }

    /// 테스트·디버그용: 시설 노드 수와 앞뒤 순서
    var facilityNodeCount: Int { facilityNodes.count }
    func zPosition(ofFacility id: String) -> CGFloat? { facilityNodes[id]?.zPosition }
    var agentZPosition: CGFloat { agentNode.zPosition }
    var newcomerZPosition: CGFloat { newcomerNode.zPosition }
    /// 화면에 실제로 그려지는 연구원 크기 (배율 이중 적용 회귀 방지용)
    var agentRenderedSize: CGSize { CGSize(width: abs(agentNode.frame.width), height: abs(agentNode.frame.height)) }
    var newcomerRenderedSize: CGSize { CGSize(width: abs(newcomerNode.frame.width), height: abs(newcomerNode.frame.height)) }
    var isNewcomerVisible: Bool { newcomerNode.parent != nil && !newcomerNode.isHidden && newcomerNode.texture != nil }
    func facilityRenderedSize(_ id: String) -> CGSize? { facilityNodes[id].map { $0.frame.size } }

    // MARK: - 배치

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutRoom()
    }

    private func layoutRoom() {
        let art = OfficePixelArt.roomSize
        let scale = max(1, min(size.width / CGFloat(art.width), size.height / CGFloat(art.height)).rounded(.down))
        pixelScale = scale
        let drawnHeight = CGFloat(art.height) * scale
        let topInset = ((size.height - drawnHeight) / 2).rounded()
        let origin = CGPoint(
            x: (size.width / 2).rounded(),
            y: topInset + CGFloat(OfficePixelArt.wallHeight) * scale
        )
        grid = IsoGrid(pixelScale: scale, origin: origin)

        roomNode.size = CGSize(width: CGFloat(art.width) * scale, height: drawnHeight)
        roomNode.position = scenePoint(CGPoint(x: origin.x, y: topInset + drawnHeight / 2))

        // 크기는 항상 '아트 크기 × 픽셀 배율' 포인트로 직접 지정 (노드 배율은 좌우 반전 ±1에만 사용)
        syncFacilities(frame: 0)
        syncDecor()
        syncSelection()
    }

    private func scenePoint(_ viewPoint: CGPoint) -> CGPoint {
        CGPoint(x: viewPoint.x, y: size.height - viewPoint.y)
    }

    /// 실수 격자 좌표의 타일 중심 → 아트 픽셀에 맞춘 장면 좌표
    private func snappedScenePoint(column: CGFloat, row: CGFloat) -> CGPoint {
        guard let grid else { return .zero }
        let px = grid.pixelScale
        let x = grid.origin.x + (column - row) * grid.tileWidth / 2
        let y = grid.origin.y + (column + row) * grid.tileHeight / 2 + grid.tileHeight / 2
        return scenePoint(CGPoint(x: (x / px).rounded() * px, y: (y / px).rounded() * px))
    }

    private func depthZ(_ key: CGFloat) -> CGFloat { 10 + key * 4 }

    // MARK: - 시설 노드 (추가 · 제거 · 콤보 강조)

    private func facilityTexture(_ kind: FacilityKind, highlighted: Bool, frame: Int) -> SKTexture {
        let key = "\(kind.rawValue)-\(highlighted)-\(frame)"
        if let cached = textureCache[key] { return cached }
        let texture = OfficePixelArt.makeFacility(kind, highlighted: highlighted, frame: frame)
        textureCache[key] = texture
        return texture
    }

    private func syncFacilities(frame: Int) {
        let liveIDs = Set(state.facilities.map(\.id))
        for (id, node) in facilityNodes where !liveIDs.contains(id) {
            node.removeFromParent()
            facilityNodes[id] = nil
        }
        for facility in state.facilities {
            let node: SKSpriteNode
            if let existing = facilityNodes[facility.id] {
                node = existing
            } else {
                node = SKSpriteNode()
                node.anchorPoint = OfficePixelArt.facilitySize(facility.kind).anchor
                addChild(node)
                facilityNodes[facility.id] = node
            }
            let size = OfficePixelArt.facilitySize(facility.kind)
            node.texture = facilityTexture(facility.kind, highlighted: comboMemberIDs.contains(facility.id), frame: frame)
            node.size = CGSize(width: CGFloat(size.width) * pixelScale, height: CGFloat(size.height) * pixelScale)
            node.position = snappedScenePoint(column: CGFloat(facility.position.column), row: CGFloat(facility.position.row))
            node.zPosition = depthZ(CGFloat(facility.position.column + facility.position.row))
        }
    }

    private func syncDecor() {
        let occupied = Set(state.facilities.map(\.position))
        for decor in decorNodes {
            decor.node.isHidden = occupied.contains(decor.cell)
            decor.node.size = CGSize(width: decor.artSize.width * pixelScale, height: decor.artSize.height * pixelScale)
            decor.node.position = snappedScenePoint(column: CGFloat(decor.cell.column), row: CGFloat(decor.cell.row))
            // 같은 칸의 연구원(+1, +2)·시설(+0)보다 뒤
            decor.node.zPosition = depthZ(CGFloat(decor.cell.column + decor.cell.row)) - 1
        }
    }

    /// 테스트·디버그용: 보이는 장식 소품 칸
    var visibleDecorCells: [GridPosition] { decorNodes.filter { !$0.node.isHidden }.map(\.cell) }

    private func syncSelection() {
        guard let grid, let cell = selectedCell else {
            selectionNode.isHidden = true
            return
        }
        let top = grid.topCorner(column: cell.column, row: cell.row)
        let w = grid.tileWidth / 2, h = grid.tileHeight / 2
        let path = CGMutablePath()
        path.move(to: scenePoint(top))
        path.addLine(to: scenePoint(CGPoint(x: top.x + w, y: top.y + h)))
        path.addLine(to: scenePoint(CGPoint(x: top.x, y: top.y + 2 * h)))
        path.addLine(to: scenePoint(CGPoint(x: top.x - w, y: top.y + h)))
        path.closeSubpath()
        selectionNode.path = path
        let occupied = state.facilities.contains { $0.position == cell }
        let blocked = isPlacing && occupied
        selectionNode.fillColor = blocked ? SKColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.35) : SKColor(white: 1, alpha: 0.3)
        selectionNode.strokeColor = blocked ? SKColor(red: 1, green: 0.4, blue: 0.4, alpha: 1) : .white
        selectionNode.lineWidth = grid.pixelScale
        selectionNode.isHidden = false
    }

    // MARK: - 매 프레임

    override func update(_ currentTime: TimeInterval) {
        let time = Date().timeIntervalSinceReferenceDate
        runtime.update(time: time, facilities: state.facilities)
        let blinkFrame = Int(time * 2) % 2
        updateFacilityAnimations(time: time, frame: blinkFrame)
        draw(runtime.agent, frames: chiefFrames, on: agentNode, time: time, tieBreak: 1)
        draw(runtime.newcomer, frames: newcomerFrames, on: newcomerNode, time: time, tieBreak: 2)
        updateGauge(time: time)
        updateBubbles(time: time)
    }

    private func updateFacilityAnimations(time: Double, frame: Int) {
        for facility in state.facilities {
            guard let node = facilityNodes[facility.id] else { continue }
            if facility.kind == .serverRack || facility.kind == .researcherDesk || facility.kind == .recordingBooth {
                node.texture = facilityTexture(facility.kind, highlighted: comboMemberIDs.contains(facility.id), frame: frame)
            }
            // 설치 직후 낙하 · 착지 (아트 픽셀 단위)
            var base = snappedScenePoint(column: CGFloat(facility.position.column), row: CGFloat(facility.position.row))
            if let t = runtime.dropProgress(for: facility.id, time: time) {
                let fall = t < 0.7 ? 18 * (1 - t / 0.7) * (1 - t / 0.7) : 0
                let bounce = t >= 0.7 ? 3 * sin((t - 0.7) / 0.3 * .pi) : 0
                base.y += CGFloat(fall + bounce).rounded() * pixelScale
            }
            node.position = base
        }
    }

    /// 연구원 한 명 그리기: 앞(남동·남서) / 뒤(북서·북동) 스프라이트 + 좌우 반전, 캐릭터 픽셀은 방 픽셀의 절반 크기
    private func draw(_ agent: ResearcherAgent, frames: OfficePixelArt.CharacterFrames, on node: SKSpriteNode, time: Double, tieBreak: CGFloat) {
        let position = agent.visualPosition
        let step = Int(time * 8) % 2
        if agent.heading.showsFront {
            node.texture = agent.isWalking ? frames.walkFront[step] : frames.idleFront
        } else {
            node.texture = frames.back
        }
        let ratio = OfficePixelArt.characterPixelRatio
        node.size = CGSize(width: frames.artSize.width * ratio * pixelScale, height: frames.artSize.height * ratio * pixelScale)
        node.xScale = agent.heading.isMirrored ? -1 : 1
        var point = snappedScenePoint(column: position.column, row: position.row)
        point.y -= 2 * pixelScale
        // 서 있을 때는 천천히 숨쉬기, 걸을 때는 통통 (뒷모습은 걷기 프레임이 없어 통통만)
        let bob = agent.isWalking ? (step == 0 ? 0 : 1) : (Int(time * 1.5 + tieBreak * 0.5) % 2)
        point.y += CGFloat(bob) * pixelScale
        node.position = point
        node.zPosition = depthZ(position.column + position.row) + tieBreak
    }

    private func updateGauge(time: Double) {
        guard let show = runtime.restoration else {
            gaugeNode.isHidden = true
            return
        }
        let desk = InstituteState.deskPosition
        var anchor = snappedScenePoint(column: CGFloat(desk.column), row: CGFloat(desk.row))
        anchor.y += 34 * pixelScale
        gaugeNode.position = anchor
        gaugeNode.isHidden = false

        let barWidth = 28 * pixelScale, barHeight = 4 * pixelScale
        gaugeTrack.size = CGSize(width: barWidth + 2 * pixelScale, height: barHeight + 2 * pixelScale)
        gaugeTrack.position = CGPoint(x: -barWidth / 2 - pixelScale, y: 0)
        let filled = (barWidth * CGFloat(show.progress(at: time)) / pixelScale).rounded(.down) * pixelScale
        gaugeFill.size = CGSize(width: filled, height: barHeight)
        gaugeFill.position = CGPoint(x: -barWidth / 2, y: 0)
        gaugeFill.color = show.insight.isCritical
            ? SKColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1)
            : SKColor(red: 0.55, green: 0.85, blue: 0.75, alpha: 1)
        gaugeLabel.text = show.insight.kanji
        gaugeLabel.fontSize = 13 * pixelScale
        gaugeLabel.position = CGPoint(x: 0, y: barHeight)
    }

    // MARK: - 떠오르는 버블

    private func updateBubbles(time: Double) {
        let live = runtime.bubbles.filter { time >= $0.born }
        let liveIDs = Set(live.map(\.id))
        for (id, node) in bubbleNodes where !liveIDs.contains(id) {
            node.removeFromParent()
            bubbleNodes[id] = nil
        }
        for bubble in live {
            let node = bubbleNodes[bubble.id] ?? makeBubbleNode(bubble)
            let t = bubble.progress(at: time)
            let rise = runtime.reduceMotion ? 0 : CGFloat(1 - pow(1 - t, 3)) * 16
            var point = snappedScenePoint(column: bubble.anchorColumn, row: bubble.anchorRow)
            point.y += (22 + rise).rounded() * pixelScale
            node.position = point
            node.setScale(t < 0.12 ? 0.7 + 0.3 * t / 0.12 : 1)
            node.alpha = t < 0.7 ? 1 : (1 - t) / 0.3
        }
    }

    private func makeBubbleNode(_ bubble: FloatingBubble) -> SKNode {
        let style = Self.bubbleStyle(bubble.style)
        let label = SKLabelNode(fontNamed: "HiraginoSans-W7")
        label.text = bubble.text
        label.fontSize = style.size * pixelScale
        label.fontColor = style.text
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let container = SKNode()
        container.zPosition = 1000
        if bubble.style != .emote {
            let frame = label.frame.insetBy(dx: -3 * pixelScale, dy: -1.5 * pixelScale)
            let pill = SKShapeNode(rect: frame, cornerRadius: 2 * pixelScale)
            pill.fillColor = style.fill
            pill.strokeColor = SKColor(white: 0, alpha: 0.35)
            pill.lineWidth = pixelScale / 2
            container.addChild(pill)
        }
        container.addChild(label)
        addChild(container)
        bubbleNodes[bubble.id] = container
        return container
    }

    private static func bubbleStyle(_ style: FloatingBubble.Style) -> (fill: SKColor, text: SKColor, size: CGFloat) {
        func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> SKColor { SKColor(red: r, green: g, blue: b, alpha: 1) }
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
}
