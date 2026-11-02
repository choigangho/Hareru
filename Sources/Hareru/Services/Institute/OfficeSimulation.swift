import Foundation
import CoreGraphics

// MARK: - 연구소 화면 전용 시뮬레이션 (저장하지 않음)
// 연구원 이동 · 떠오르는 버블 · 복원 진행 연출은 모두 '보여 주기'용입니다.
// 자원(研究P · 予算)과 복원 결과는 InstituteEngine이 즉시 확정하고, 여기서는 절대 바꾸지 않습니다.
// → 연출 도중 탭을 옮기거나 앱이 꺼져도 저장된 결과와 어긋나지 않음.

// MARK: - 재현 가능한 난수 (테스트에서 같은 동선을 다시 만들 수 있게)
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - 격자 길찾기 (BFS, 시설이 놓인 칸은 지나갈 수 없음)
public enum OfficePathfinder {
    public static func isWalkable(_ position: GridPosition, facilities: [PlacedFacility]) -> Bool {
        (0..<InstituteState.gridColumns).contains(position.column)
            && (0..<InstituteState.gridRows).contains(position.row)
            && !InstituteState.fixedCells.contains(position)
            && !facilities.contains { $0.position == position }
    }

    static func neighbors(of position: GridPosition) -> [GridPosition] {
        [(0, 1), (1, 0), (0, -1), (-1, 0)].map {
            GridPosition(column: position.column + $0.0, row: position.row + $0.1)
        }
    }

    /// 시설 옆에서 일할 수 있는 빈 칸들
    public static func standingSpots(beside target: GridPosition, facilities: [PlacedFacility]) -> [GridPosition] {
        neighbors(of: target).filter { isWalkable($0, facilities: facilities) }
    }

    /// 주임 연구원이 책상에서 일하는 자리 (책상 앞 칸을 우선, 막혀 있으면 다른 옆 칸)
    public static func deskSpot(facilities: [PlacedFacility]) -> GridPosition? {
        spot(inFrontOf: .researcherDesk, facilities: facilities, avoiding: nil)
    }

    /// 1인 1책상: 주임 연구원은 연구원 책상 앞, 신입은 신입 책상 앞 (책상을 옮기면 자리도 따라감).
    /// 신입 책상이 없으면 연구원 책상 옆의 다른 칸
    public static func homeSpot(for role: ResearcherAgent.Role, facilities: [PlacedFacility]) -> GridPosition? {
        let chief = deskSpot(facilities: facilities)
        guard role == .newcomer else { return chief }
        return spot(inFrontOf: .traineeDesk, facilities: facilities, avoiding: chief)
            ?? spot(inFrontOf: .researcherDesk, facilities: facilities, avoiding: chief)
            ?? chief
    }

    private static func spot(inFrontOf kind: FacilityKind, facilities: [PlacedFacility], avoiding other: GridPosition?) -> GridPosition? {
        let desk = facilities.first { $0.kind == kind }?.position
            ?? (kind == .traineeDesk ? nil : InstituteState.deskPosition)
        guard let desk else { return nil }
        let preferred = GridPosition(column: desk.column, row: desk.row + 1)
        if isWalkable(preferred, facilities: facilities), preferred != other { return preferred }
        if let beside = standingSpots(beside: desk, facilities: facilities).first(where: { $0 != other }) { return beside }
        return nearestFreeCell(to: desk, facilities: facilities, avoiding: other)
    }

    /// 책상 둘레가 모두 막혔을 때(방 그림의 고정 가구 + 시설) 가장 가까운 빈 칸
    private static func nearestFreeCell(to target: GridPosition, facilities: [PlacedFacility], avoiding other: GridPosition?) -> GridPosition? {
        var best: (distance: Int, cell: GridPosition)?
        for row in 0..<InstituteState.gridRows {
            for column in 0..<InstituteState.gridColumns {
                let cell = GridPosition(column: column, row: row)
                guard cell != other, isWalkable(cell, facilities: facilities) else { continue }
                let distance = abs(cell.column - target.column) + abs(cell.row - target.row)
                if best == nil || distance < best!.distance { best = (distance, cell) }
            }
        }
        return best?.cell
    }

    /// start에서 goals 중 가장 가까운 칸까지의 경로 (start 제외, 도착 칸 포함). 이미 도착해 있으면 []. 길이 없으면 nil
    public static func path(
        from start: GridPosition,
        toAnyOf goals: [GridPosition],
        facilities: [PlacedFacility]
    ) -> [GridPosition]? {
        let goalSet = Set(goals)
        guard !goalSet.isEmpty else { return nil }
        if goalSet.contains(start) { return [] }
        var previous: [GridPosition: GridPosition] = [:]
        var visited: Set<GridPosition> = [start]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for next in neighbors(of: current) where !visited.contains(next) && isWalkable(next, facilities: facilities) {
                visited.insert(next)
                previous[next] = current
                if goalSet.contains(next) {
                    var route = [next]
                    var cursor = next
                    while let back = previous[cursor], back != start {
                        route.append(back)
                        cursor = back
                    }
                    return route.reversed()
                }
                queue.append(next)
            }
        }
        return nil
    }
}

// MARK: - 연구원 자율 행동 (자기 자리 ↔ 시설 왕복) — 주임 연구원 · 신입(플레이어) 2명
public struct ResearcherAgent: Equatable, Sendable {
    public enum Role: Equatable, Sendable {
        case chief, newcomer
    }

    public enum Activity: Equatable, Sendable {
        case idle(remaining: Double)
        case walking(path: [GridPosition], progress: Double, toward: FacilityKind?)   // nil = 자기 자리로 복귀
        case working(facility: FacilityKind, remaining: Double)
    }

    /// 아이소메트릭 화면 방향. 열이 늘면 오른쪽 아래(남동), 행이 늘면 왼쪽 아래(남서)
    public enum Heading: Equatable, Sendable {
        case southeast, southwest, northeast, northwest

        init(from: GridPosition, to: GridPosition) {
            if to.column > from.column { self = .southeast }
            else if to.column < from.column { self = .northwest }
            else if to.row > from.row { self = .southwest }
            else { self = .northeast }
        }

        /// 얼굴이 보이는 방향 (남동·남서). 아니면 뒷모습
        public var showsFront: Bool { self == .southeast || self == .southwest }
        /// 스프라이트는 남동(앞) · 북서(뒤) 두 장 — 남서 · 북동은 좌우 반전
        public var isMirrored: Bool { self == .southwest || self == .northeast }
    }

    public static let secondsPerTile = 0.35
    public static let workSeconds = 2.0
    /// 쉬는 시간이 끝날 때 업무 때문에 시설로 가는 확률 — 10번 중 2번, 나머지는 자기 책상에서 계속 일함
    public static let taskTripChance = 0.2
    /// 복원 연출 중에는 더 자주 오감
    public static let busyTripChance = 0.5

    public let role: Role
    public private(set) var tile: GridPosition
    public private(set) var activity: Activity
    public private(set) var heading = Heading.southeast
    /// 화면에서 오른쪽을 보고 있는지 (남동 · 북동)
    public var facingRight: Bool { heading == .southeast || heading == .northeast }
    /// 복원 연출 중에는 쉬는 시간을 줄여 바쁘게 오감
    public var isBusy = false

    public init(tile: GridPosition, role: Role = .chief, idleSeconds: Double = 2.0) {
        self.role = role
        self.tile = tile
        self.activity = .idle(remaining: idleSeconds)
    }

    /// 화면에 그릴 연속 좌표 (column, row) — 타일 사이를 선형 보간
    public var visualPosition: (column: CGFloat, row: CGFloat) {
        if case let .walking(path, progress, _) = activity, let next = path.first {
            let t = CGFloat(min(max(progress, 0), 1))
            return (CGFloat(tile.column) + CGFloat(next.column - tile.column) * t,
                    CGFloat(tile.row) + CGFloat(next.row - tile.row) * t)
        }
        return (CGFloat(tile.column), CGFloat(tile.row))
    }

    public var isWalking: Bool {
        if case .walking = activity { return true }
        return false
    }

    /// 시설이 치워지거나 옮겨져 현재 칸이 막혔을 때 자기 자리로 되돌림
    public mutating func recover(facilities: [PlacedFacility]) {
        guard !OfficePathfinder.isWalkable(tile, facilities: facilities),
              let spot = OfficePathfinder.homeSpot(for: role, facilities: facilities) else { return }
        tile = spot
        activity = .idle(remaining: 1.0)
    }

    /// dt초만큼 진행. 반환값: 이번 틱에 일을 시작한 시설 (말풍선 연출용)
    @discardableResult
    public mutating func step<G: RandomNumberGenerator>(
        dt: Double,
        facilities: [PlacedFacility],
        rng: inout G
    ) -> FacilityKind? {
        switch activity {
        case .idle(let remaining):
            let left = remaining - dt
            guard left <= 0 else {
                activity = .idle(remaining: left)
                return nil
            }
            // 자기 자리가 아니면(시설이 옮겨지는 등) 먼저 책상으로
            if let home = OfficePathfinder.homeSpot(for: role, facilities: facilities), home != tile,
               let route = OfficePathfinder.path(from: tile, toAnyOf: [home], facilities: facilities), !route.isEmpty {
                activity = .walking(path: route, progress: 0, toward: nil)
                return nil
            }
            // 대부분은 책상에서 계속 일하고, 가끔(2할) 업무 때문에 시설로 감
            let chance = isBusy ? Self.busyTripChance : Self.taskTripChance
            guard Double.random(in: 0..<1, using: &rng) < chance else {
                activity = .idle(remaining: isBusy ? 0.8 : Double.random(in: 3...6, using: &rng))
                return nil
            }
            let targets = facilities.filter { !$0.kind.isDesk }
            guard let target = targets.randomElement(using: &rng),
                  let route = OfficePathfinder.path(
                    from: tile,
                    toAnyOf: OfficePathfinder.standingSpots(beside: target.position, facilities: facilities),
                    facilities: facilities) else {
                activity = .idle(remaining: isBusy ? 0.5 : 3.0)
                return nil
            }
            if route.isEmpty {
                activity = .working(facility: target.kind, remaining: Self.workSeconds)
                return target.kind
            }
            activity = .walking(path: route, progress: 0, toward: target.kind)
            return nil

        case .walking(var path, var progress, let toward):
            progress += dt / Self.secondsPerTile
            while progress >= 1, !path.isEmpty {
                let next = path.removeFirst()
                heading = Heading(from: tile, to: next)
                tile = next
                progress -= 1
            }
            if let next = path.first {
                heading = Heading(from: tile, to: next)
            }
            guard path.isEmpty else {
                activity = .walking(path: path, progress: progress, toward: toward)
                return nil
            }
            if let kind = toward {
                activity = .working(facility: kind, remaining: Self.workSeconds)
                return kind
            }
            activity = .idle(remaining: isBusy ? 0.6 : Double.random(in: 3...6, using: &rng))
            return nil

        case .working(let facility, let remaining):
            let left = remaining - dt
            guard left <= 0 else {
                activity = .working(facility: facility, remaining: left)
                return nil
            }
            if let home = OfficePathfinder.homeSpot(for: role, facilities: facilities),
               let route = OfficePathfinder.path(from: tile, toAnyOf: [home], facilities: facilities),
               !route.isEmpty {
                activity = .walking(path: route, progress: 0, toward: nil)
            } else {
                activity = .idle(remaining: isBusy ? 0.6 : 3.0)
            }
            return nil
        }
    }
}

// MARK: - 복원 연출에 쓸 학습 데이터 요약 (읽기 전용)
// 버블은 장식이 아니라 '내가 이 한자를 어떻게 알고 있는지'를 보여 줌:
// 音 = 음독으로 읽은 단어를 외움, 訓 = 훈독으로 읽은 단어를 외움, 文 = 외운 단어 수, 形 = 획수·부수
public struct RestorationInsight: Equatable, Sendable {
    public let kanji: String
    public let knowsOnReading: Bool
    public let knowsKunReading: Bool
    public let learnedWordCount: Int
    public let strokeCount: Int?
    public let averageStability: Double

    /// 외운 단어들을 평균 3일 이상 기억해 왔으면 '크리티컬 집중'
    public static let criticalStability = 3.0
    public var isCritical: Bool { averageStability >= Self.criticalStability }

    public init(
        kanji: String,
        catalog: CatalogRepository,
        snapshots: [String: WordMemorySnapshot]
    ) {
        let learned = catalog.words.filter {
            (snapshots[$0.id]?.reps ?? 0) > 0 && $0.term.contains(kanji)
        }
        let usages = learned.compactMap { $0.kanjiUsage(for: kanji) }
        self.kanji = kanji
        knowsOnReading = usages.contains { $0.readingType == .onyomi }
        knowsKunReading = usages.contains { $0.readingType == .kunyomi }
        learnedWordCount = learned.count
        strokeCount = catalog.kanjiInfo(for: kanji)?.strokeCount
        let stabilities = learned.compactMap { snapshots[$0.id]?.stability }
        averageStability = stabilities.isEmpty ? 0 : stabilities.reduce(0, +) / Double(stabilities.count)
    }

    /// 진행 중에 차례로 떠오를 버블 문구
    public var bubbleTexts: [String] {
        var texts: [String] = []
        if knowsOnReading { texts.append("+音") }
        if knowsKunReading { texts.append("+訓") }
        texts.append(strokeCount.map { "+形 \($0)画" } ?? "+形")
        texts.append("+文 ×\(learnedWordCount)")
        return texts
    }

    /// 크리티컬이면 더 빨리 끝남
    public var showDuration: Double { isCritical ? 4.5 : 6.5 }
}

// MARK: - 떠오르는 버블
public struct FloatingBubble: Identifiable, Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        case points, budget, combo, stat, critical, emote, done
    }

    public let id: UUID
    public let text: String
    public let style: Style
    public let anchorColumn: CGFloat
    public let anchorRow: CGFloat
    public let born: Double
    public let lifetime: Double

    public init(text: String, style: Style, anchor: (column: CGFloat, row: CGFloat), born: Double, lifetime: Double = 1.2) {
        self.id = UUID()
        self.text = text
        self.style = style
        self.anchorColumn = anchor.column
        self.anchorRow = anchor.row
        self.born = born
        self.lifetime = lifetime
    }

    /// 0 → 1 진행도
    public func progress(at time: Double) -> Double {
        min(max((time - born) / lifetime, 0), 1)
    }

    public func isAlive(at time: Double) -> Bool { time < born + lifetime }
}

// MARK: - 런타임 (뷰가 들고 있는 화면 전용 상태)
public final class OfficeSimulationRuntime {
    public struct RestorationShow: Equatable, Sendable {
        public let insight: RestorationInsight
        public let startedAt: Double
        public var emittedCount: Int
        public var hasShownCritical: Bool

        public func progress(at time: Double) -> Double {
            min(max((time - startedAt) / insight.showDuration, 0), 1)
        }
    }

    /// 주임 연구원 — 복원 · 정산 버블은 이 사람 머리 위에서
    public private(set) var agent: ResearcherAgent
    /// 신입 연구원 (= 플레이어). 시작 인원 2명 중 한 명, 자기 자리에서 시설을 오가며 일을 배움
    public private(set) var newcomer: ResearcherAgent
    public private(set) var bubbles: [FloatingBubble] = []
    public private(set) var restoration: RestorationShow?
    public private(set) var dropStarts: [String: Double] = [:]
    public var reduceMotion = false
    private var lastTime: Double?
    private var rng: SeededRandom
    /// 신입은 따로 굴려서 주임 연구원의 동선(같은 seed면 같은 동선)이 바뀌지 않게 함
    private var newcomerRng: SeededRandom

    public static let maxBubbles = 24
    public static let bubbleInterval = 0.7

    public init(facilities: [PlacedFacility], seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        rng = SeededRandom(seed: seed)
        newcomerRng = SeededRandom(seed: seed ^ 0xA5A5_5A5A_C3C3_3C3C)
        let start = OfficePathfinder.homeSpot(for: .chief, facilities: facilities) ?? InstituteState.deskPosition
        agent = ResearcherAgent(tile: start)
        let newcomerStart = OfficePathfinder.homeSpot(for: .newcomer, facilities: facilities) ?? start
        newcomer = ResearcherAgent(tile: newcomerStart, role: .newcomer, idleSeconds: 4.5)
    }

    /// 매 프레임 호출. dt는 최대 0.1초로 잘라서 백그라운드 복귀 시 순간이동을 막음
    public func update(time: Double, facilities: [PlacedFacility]) {
        let dt = min(max(time - (lastTime ?? time), 0), 0.1)
        lastTime = time
        bubbles.removeAll { !$0.isAlive(at: time) }

        agent.recover(facilities: facilities)
        agent.isBusy = restoration != nil
        if !reduceMotion, let startedWork = agent.step(dt: dt, facilities: facilities, rng: &rng) {
            emit(Self.emote(for: startedWork), style: .emote, at: agent.visualPosition, time: time, lifetime: 1.0)
        }
        newcomer.recover(facilities: facilities)
        newcomer.isBusy = restoration != nil
        if !reduceMotion {
            newcomer.step(dt: dt, facilities: facilities, rng: &newcomerRng)
        }

        guard var show = restoration else { return }
        let elapsed = time - show.startedAt
        let texts = show.insight.bubbleTexts
        let due = Int(elapsed / Self.bubbleInterval)
        while show.emittedCount < due, show.progress(at: time) < 1 {
            emit(texts[show.emittedCount % texts.count], style: .stat, at: agent.visualPosition, time: time)
            show.emittedCount += 1
        }
        if show.insight.isCritical, !show.hasShownCritical, elapsed > 1.0 {
            emit("集中!", style: .critical, at: agent.visualPosition, time: time, lifetime: 1.4)
            show.hasShownCritical = true
        }
        if show.progress(at: time) >= 1 {
            finishRestoration(show.insight, time: time)
        } else {
            restoration = show
        }
    }

    // MARK: - 이벤트 (모두 이미 엔진에서 확정된 결과를 보여 주기만 함)

    public func emitSettlement(_ settlement: InstituteSettlement, time: Double) {
        if settlement.gainedPoints > 0 {
            emit("+\(settlement.gainedPoints) 研究P", style: .points, at: agent.visualPosition, time: time, lifetime: 1.6)
        }
        if settlement.budgetGranted > 0 {
            emit("+\(settlement.budgetGranted) 予算", style: .budget, at: agent.visualPosition, time: time + 0.4, lifetime: 1.6)
        }
    }

    public func facilityPlaced(_ facility: PlacedFacility, newCombos: [FacilityCombo], all: [PlacedFacility], time: Double) {
        if !reduceMotion {
            dropStarts[facility.id] = time
        }
        for combo in newCombos {
            let (a, b) = combo.pair
            let partner = all.first { $0.id != facility.id && ($0.kind == a || $0.kind == b) && $0.position.isAdjacent(to: facility.position) }
            let mid = partner.map {
                ((CGFloat($0.position.column) + CGFloat(facility.position.column)) / 2,
                 (CGFloat($0.position.row) + CGFloat(facility.position.row)) / 2)
            } ?? (CGFloat(facility.position.column), CGFloat(facility.position.row))
            emit("Combo!", style: .combo, at: mid, time: time + 0.3, lifetime: 1.6)
        }
    }

    public func startRestoration(_ insight: RestorationInsight, time: Double) {
        restoration = RestorationShow(insight: insight, startedAt: time, emittedCount: 0, hasShownCritical: false)
    }

    /// 탭하면 연출을 건너뜀 (결과는 이미 저장돼 있음)
    public func skipRestoration(time: Double) {
        guard let show = restoration else { return }
        finishRestoration(show.insight, time: time)
    }

    public var isShowingRestoration: Bool { restoration != nil }

    /// 0 → 1 설치 낙하 진행 (끝났으면 nil)
    public func dropProgress(for facilityId: String, time: Double) -> Double? {
        guard let start = dropStarts[facilityId] else { return nil }
        let t = (time - start) / 0.45
        if t >= 1 {
            dropStarts[facilityId] = nil
            return nil
        }
        return max(0, t)
    }

    private func finishRestoration(_ insight: RestorationInsight, time: Double) {
        restoration = nil
        emit("\(insight.kanji) 復元!", style: .done, at: agent.visualPosition, time: time, lifetime: 2.0)
    }

    private func emit(_ text: String, style: FloatingBubble.Style, at anchor: (column: CGFloat, row: CGFloat), time: Double, lifetime: Double = 1.2) {
        bubbles.append(FloatingBubble(text: text, style: style, anchor: anchor, born: time, lifetime: lifetime))
        if bubbles.count > Self.maxBubbles {
            bubbles.removeFirst(bubbles.count - Self.maxBubbles)
        }
    }

    private static func emote(for kind: FacilityKind) -> String {
        switch kind {
        case .kanjiArchive: return "📖"
        case .copyRoom: return "✍️"
        case .recordingBooth: return "🎙️"
        case .serverRack: return "⚙️"
        case .researcherDesk, .traineeDesk: return "…"
        }
    }
}
