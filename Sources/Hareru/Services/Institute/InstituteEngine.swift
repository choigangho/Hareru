import Foundation
import Observation

// MARK: - 연구소 상태 저장소 (학습 기록 스토어와 분리 — 게임 버그가 학습 데이터를 망가뜨리지 않게)
public protocol InstituteStoreProtocol: AnyObject {
    func loadState() -> InstituteState?
    func saveState(_ state: InstituteState)
}

public final class InMemoryInstituteStore: InstituteStoreProtocol {
    private var state: InstituteState?

    public init(state: InstituteState? = nil) {
        self.state = state
    }

    public func loadState() -> InstituteState? { state }
    public func saveState(_ state: InstituteState) { self.state = state }
}

/// Application Support/Hareru/institute.json 에 JSON으로 저장
public final class JSONFileInstituteStore: InstituteStoreProtocol {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = base.appendingPathComponent("Hareru", isDirectory: true)
                .appendingPathComponent("institute.json")
        }
    }

    public func loadState() -> InstituteState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(InstituteState.self, from: data)
    }

    public func saveState(_ state: InstituteState) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("연구소 상태 저장 실패: \(error)")
        }
    }
}

// MARK: - 연구소 경영 엔진 (M1: 정산 · 시설 배치 · 인접 콤보 · 한자 복원)
@Observable
public final class InstituteEngine {
    public private(set) var state: InstituteState
    private let store: InstituteStoreProtocol

    public static let baseRestoreCost = 30
    public static let dailyBudgetBase = 50
    public static let dailyBudgetPerInfluence = 10

    public init(store: InstituteStoreProtocol = InMemoryInstituteStore()) {
        self.store = store
        self.state = store.loadState() ?? InstituteState()
    }

    private func commit(_ newState: InstituteState) {
        state = newState
        store.saveState(newState)
    }

    // MARK: - 효과 합산

    public var activeCombos: [FacilityCombo] {
        FacilityCombo.allCases.filter { combo in
            let (a, b) = combo.pair
            let first = state.facilities.filter { $0.kind == a }
            let second = state.facilities.filter { $0.kind == b }
            return first.contains { x in second.contains { y in x.position.isAdjacent(to: y.position) } }
        }
    }

    /// 실제로 맞닿아 콤보를 이룬 시설들의 id (같은 종류라도 떨어져 있으면 제외)
    public var comboMemberIDs: Set<String> {
        var members = Set<String>()
        for combo in FacilityCombo.allCases {
            let (a, b) = combo.pair
            for x in state.facilities where x.kind == a {
                for y in state.facilities where y.kind == b && x.position.isAdjacent(to: y.position) {
                    members.insert(x.id)
                    members.insert(y.id)
                }
            }
        }
        return members
    }

    public var researchBonusPercent: Int {
        state.facilities.reduce(0) { $0 + $1.kind.researchBonusPercent }
            + activeCombos.reduce(0) { $0 + $1.researchBonusPercent }
    }

    public var restoreDiscountPercent: Int {
        min(60, state.facilities.reduce(0) { $0 + $1.kind.restoreDiscountPercent }
            + activeCombos.reduce(0) { $0 + $1.restoreDiscountPercent })
    }

    public var restoreCost: Int {
        max(1, Self.baseRestoreCost * (100 - restoreDiscountPercent) / 100)
    }

    // MARK: - 1) 학습 기록 정산 (읽기 전용) + 하루 한 번 예산 지급

    @discardableResult
    public func settle(
        logs: [ReviewLogEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InstituteSettlement {
        var next = state
        let rewards = ResearchRewardCalculator.rewards(
            logs: logs, alreadyRewardedKeys: next.rewardedReviewKeys, calendar: calendar)
        let base = rewards.reduce(0) { $0 + $1.points }
        let bonus = researchBonusPercent
        let gained = base * (100 + bonus) / 100
        next.researchPoints += gained
        next.rewardedReviewKeys.formUnion(rewards.map(\.key))

        var granted = 0
        let todayKey = DayKeyFormatter.dayKey(for: now, calendar: calendar)
        if next.lastBudgetGrantDayKey != todayKey {
            granted = Self.dailyBudgetBase + Self.dailyBudgetPerInfluence * next.influence
            next.budget += granted
            next.lastBudgetGrantDayKey = todayKey
        }

        if next != state {
            commit(next)
        }
        return InstituteSettlement(
            rewards: rewards, basePoints: base, bonusPercent: bonus,
            gainedPoints: gained, budgetGranted: granted)
    }

    // MARK: - 2) 시설 배치

    public func isInsideGrid(_ position: GridPosition) -> Bool {
        (0..<InstituteState.gridColumns).contains(position.column)
            && (0..<InstituteState.gridRows).contains(position.row)
    }

    public func facility(at position: GridPosition) -> PlacedFacility? {
        state.facilities.first { $0.position == position }
    }

    public func canPlace(_ kind: FacilityKind, at position: GridPosition) -> Bool {
        guard isInsideGrid(position), facility(at: position) == nil, !InstituteState.fixedCells.contains(position) else { return false }
        if kind.isUnique, state.facilities.contains(where: { $0.kind == kind }) { return false }
        return state.budget >= kind.budgetCost
    }

    @discardableResult
    public func place(_ kind: FacilityKind, at position: GridPosition) -> Bool {
        guard canPlace(kind, at: position) else { return false }
        var next = state
        next.budget -= kind.budgetCost
        next.facilities.append(PlacedFacility(kind: kind, position: position))
        commit(next)
        return true
    }

    /// 책상(1인 1책상)은 치울 수 없음. 철거 시 비용의 절반 환급
    @discardableResult
    public func remove(at position: GridPosition) -> Bool {
        guard let target = facility(at: position), target.kind.isRemovable else { return false }
        var next = state
        next.facilities.removeAll { $0.id == target.id }
        next.budget += target.kind.budgetCost / 2
        commit(next)
        return true
    }

    /// 시설 옮기기 (책상 포함, 무료). 같은 id를 유지해서 장면 노드·콤보 표시가 그대로 따라감
    @discardableResult
    public func move(from origin: GridPosition, to destination: GridPosition) -> Bool {
        guard origin != destination, isInsideGrid(destination), facility(at: destination) == nil,
              !InstituteState.fixedCells.contains(destination),
              let target = facility(at: origin), target.kind != .researcherDesk,
              let index = state.facilities.firstIndex(where: { $0.id == target.id }) else { return false }
        var next = state
        next.facilities[index] = PlacedFacility(id: target.id, kind: target.kind, position: destination)
        commit(next)
        return true
    }

    // MARK: - 인테리어 (샘플을 누르면 바닥 · 외벽 전체가 바뀜)

    public func setFloorTheme(_ theme: FloorTheme) {
        guard state.floorTheme != theme else { return }
        var next = state
        next.floorTheme = theme
        commit(next)
    }

    public func setWallTheme(_ theme: WallTheme) {
        guard state.wallTheme != theme else { return }
        var next = state
        next.wallTheme = theme
        commit(next)
    }

    // MARK: - 3) 한자 복원

    /// 실제로 외운 단어(reps > 0)에 들어 있는 한자 중 아직 복원하지 않은 것
    public func restorableKanji(
        catalog: CatalogRepository,
        snapshots: [String: WordMemorySnapshot]
    ) -> [String] {
        var seen = Set(state.restoredKanji)
        var result: [String] = []
        for word in catalog.words where (snapshots[word.id]?.reps ?? 0) > 0 {
            for glyph in word.termGlyphs where glyph.isKanji && catalog.kanjiInfo(for: glyph.character) != nil {
                if seen.insert(glyph.character).inserted {
                    result.append(glyph.character)
                }
            }
        }
        return result
    }

    @discardableResult
    public func restore(
        kanji: String,
        catalog: CatalogRepository,
        snapshots: [String: WordMemorySnapshot]
    ) -> Bool {
        guard restorableKanji(catalog: catalog, snapshots: snapshots).contains(kanji),
              state.researchPoints >= restoreCost else { return false }
        var next = state
        next.researchPoints -= restoreCost
        next.restoredKanji.append(kanji)
        commit(next)
        return true
    }

    public func markIntroSeen() {
        guard !state.hasSeenIntro else { return }
        var next = state
        next.hasSeenIntro = true
        commit(next)
    }
}
