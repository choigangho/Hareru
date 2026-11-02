import Foundation

// MARK: - 연구소 시설 (M1: 1단계 사무실에 놓을 수 있는 5종, Docs/GAME_DESIGN.md §5.2)
public enum FacilityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case researcherDesk   // 주임 연구원 책상 (시작 시 배치, 철거 불가)
    case traineeDesk      // 신입 연구원(나) 책상 (시작 시 배치, 철거 불가) — 1인 1책상
    case kanjiArchive     // 한자 서고
    case copyRoom         // 필사실
    case recordingBooth   // 녹음 부스
    case serverRack       // 서버 랙

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .researcherDesk: return "연구원 책상"
        case .traineeDesk: return "신입 책상"
        case .kanjiArchive: return "한자 서고"
        case .copyRoom: return "필사실"
        case .recordingBooth: return "녹음 부스"
        case .serverRack: return "서버 랙"
        }
    }

    public var summary: String {
        switch self {
        case .researcherDesk: return "연구소의 시작점. 주임 연구원이 머무는 자리"
        case .traineeDesk: return "새로 배정된 신입 연구원(나)의 자리"
        case .kanjiArchive: return "복원한 한자를 보관 · 연구 포인트 +5%"
        case .copyRoom: return "획순과 부수를 옮겨 적는 방 · 복원 비용 -10%"
        case .recordingBooth: return "말로 하는 일본어를 기록 · 연구 포인트 +5%"
        case .serverRack: return "AI 모듈이 돌아가는 서버 · 연구 포인트 +10%"
        }
    }

    /// 설치 비용 (予算)
    public var budgetCost: Int {
        switch self {
        case .researcherDesk, .traineeDesk: return 0
        case .kanjiArchive: return 120
        case .copyRoom: return 100
        case .recordingBooth: return 150
        case .serverRack: return 200
        }
    }

    public var researchBonusPercent: Int {
        switch self {
        case .kanjiArchive, .recordingBooth: return 5
        case .serverRack: return 10
        case .researcherDesk, .traineeDesk, .copyRoom: return 0
        }
    }

    public var restoreDiscountPercent: Int {
        self == .copyRoom ? 10 : 0
    }

    /// 사람이 앉는 책상 (1인 1책상 — 건설 목록에 없고 치울 수 없음, 옮기기만 가능)
    public var isDesk: Bool { self == .researcherDesk || self == .traineeDesk }

    /// 한 사무실에 하나만 둘 수 있는 시설
    public var isUnique: Bool { isDesk }

    public var isRemovable: Bool { !isDesk }
}

// MARK: - 인접 콤보 (서로 맞닿게 배치하면 추가 효과)
public enum FacilityCombo: String, Codable, CaseIterable, Identifiable, Sendable {
    case copyWorkshop     // 写本工房: 한자 서고 + 필사실
    case voiceArchive     // 音声アーカイブ: 녹음 부스 + 서버 랙
    case researchCorner   // 研究デスク: 연구원 책상 + 한자 서고

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .copyWorkshop: return "写本工房 (사본 공방)"
        case .voiceArchive: return "音声アーカイブ (음성 아카이브)"
        case .researchCorner: return "研究デスク (연구 코너)"
        }
    }

    public var pair: (FacilityKind, FacilityKind) {
        switch self {
        case .copyWorkshop: return (.kanjiArchive, .copyRoom)
        case .voiceArchive: return (.recordingBooth, .serverRack)
        case .researchCorner: return (.researcherDesk, .kanjiArchive)
        }
    }

    public var researchBonusPercent: Int {
        switch self {
        case .voiceArchive: return 15
        case .researchCorner: return 10
        case .copyWorkshop: return 0
        }
    }

    public var restoreDiscountPercent: Int {
        self == .copyWorkshop ? 20 : 0
    }

    public var summary: String {
        switch self {
        case .copyWorkshop: return "한자 서고와 필사실을 붙이면 복원 비용 -20%"
        case .voiceArchive: return "녹음 부스와 서버 랙을 붙이면 연구 포인트 +15%"
        case .researchCorner: return "연구원 책상 옆에 한자 서고를 두면 연구 포인트 +10%"
        }
    }
}

// MARK: - 인테리어 테마 (샘플을 고르면 바닥 · 외벽 전체가 바뀜, 무료)
public enum FloorTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case lightWood    // 밝은 원목 마루
    case darkWood     // 짙은 원목 마루

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lightWood: return "밝은 마루"
        case .darkWood: return "짙은 마루"
        }
    }
}

public enum WallTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case plasterTeal  // 회벽 + 청록 징두리
    case woodPanel    // 낡은 목재 판벽
    case concrete     // 노출 콘크리트

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .plasterTeal: return "회벽"
        case .woodPanel: return "목재 판벽"
        case .concrete: return "콘크리트"
        }
    }
}

// MARK: - 아이소메트릭 격자 위 배치 (행·열 기준, 화면 좌표 변환은 IsoGrid 한 곳에서만)
public struct GridPosition: Codable, Hashable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    public func isAdjacent(to other: GridPosition) -> Bool {
        abs(column - other.column) + abs(row - other.row) == 1
    }
}

public struct PlacedFacility: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let kind: FacilityKind
    public let position: GridPosition

    public init(id: String = UUID().uuidString, kind: FacilityKind, position: GridPosition) {
        self.id = id
        self.kind = kind
        self.position = position
    }
}

// MARK: - 연구소 상태 (학습 데이터와 별도 파일에 저장)
public struct InstituteState: Codable, Equatable, Sendable {
    public var stage: Int                       // 연구소 단계 1~5 (M1은 1단계 사무실)
    public var researchPoints: Int              // 研究P
    public var budget: Int                      // 予算
    public var facilities: [PlacedFacility]
    public var restoredKanji: [String]          // 복원 순서대로
    public var rewardedReviewKeys: Set<String>  // "단어ID|날짜" — 같은 날 같은 단어 중복 보상 방지
    public var lastBudgetGrantDayKey: String?
    public var hasSeenIntro: Bool
    public var floorTheme: FloorTheme
    public var wallTheme: WallTheme

    public static let gridColumns = 6
    public static let gridRows = 6
    public static let startingBudget = 200
    public static let deskPosition = GridPosition(column: 2, row: 2)
    public static let traineeDeskPosition = GridPosition(column: 4, row: 3)
    /// 1단계 방 그림(room_stage1)에 이미 그려져 있어 시설을 놓거나 걸을 수 없는 칸
    /// (뒷벽 · 큰 책상 · 왼쪽 다탁과 책장 · 오른쪽 분재와 연못). 그림과 맞춘 값이라 그림을 바꾸면 함께 고칠 것
    public static let fixedCells: Set<GridPosition> = {
        var cells = Set<GridPosition>()
        for column in 0..<gridColumns { cells.insert(GridPosition(column: column, row: 0)); cells.insert(GridPosition(column: column, row: 1)) }
        for column in 1...4 { cells.insert(GridPosition(column: column, row: 2)) }      // 큰 책상(주임 연구원 자리)
        for row in 3...5 { cells.insert(GridPosition(column: 0, row: row)) }            // 왼쪽 다탁 · 책장
        for row in 3...5 { cells.insert(GridPosition(column: 5, row: row)) }            // 오른쪽 분재 · 연못
        cells.insert(GridPosition(column: 4, row: 5))
        return cells
    }()
    public static let startingFacilities = [
        PlacedFacility(kind: .researcherDesk, position: deskPosition),
        PlacedFacility(kind: .traineeDesk, position: traineeDeskPosition)
    ]

    public init(
        stage: Int = 1,
        researchPoints: Int = 0,
        budget: Int = InstituteState.startingBudget,
        facilities: [PlacedFacility] = InstituteState.startingFacilities,
        restoredKanji: [String] = [],
        rewardedReviewKeys: Set<String> = [],
        lastBudgetGrantDayKey: String? = nil,
        hasSeenIntro: Bool = false,
        floorTheme: FloorTheme = .lightWood,
        wallTheme: WallTheme = .plasterTeal
    ) {
        self.stage = stage
        self.researchPoints = researchPoints
        self.budget = budget
        self.facilities = facilities
        self.restoredKanji = restoredKanji
        self.rewardedReviewKeys = rewardedReviewKeys
        self.lastBudgetGrantDayKey = lastBudgetGrantDayKey
        self.hasSeenIntro = hasSeenIntro
        self.floorTheme = floorTheme
        self.wallTheme = wallTheme
    }

    /// 예전 저장 파일 호환: 테마가 없으면 기본값, 신입 책상이 없으면 빈 칸에 놓아 줌 (2명 시작 이전 저장)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage = try c.decode(Int.self, forKey: .stage)
        researchPoints = try c.decode(Int.self, forKey: .researchPoints)
        budget = try c.decode(Int.self, forKey: .budget)
        facilities = try c.decode([PlacedFacility].self, forKey: .facilities)
        restoredKanji = try c.decode([String].self, forKey: .restoredKanji)
        rewardedReviewKeys = try c.decode(Set<String>.self, forKey: .rewardedReviewKeys)
        lastBudgetGrantDayKey = try c.decodeIfPresent(String.self, forKey: .lastBudgetGrantDayKey)
        hasSeenIntro = try c.decode(Bool.self, forKey: .hasSeenIntro)
        floorTheme = try c.decodeIfPresent(FloorTheme.self, forKey: .floorTheme) ?? .lightWood
        wallTheme = try c.decodeIfPresent(WallTheme.self, forKey: .wallTheme) ?? .plasterTeal
        // 예전 저장 파일: 방 그림의 고정 가구 칸에 있던 시설은 가까운 빈 칸으로 옮김 (주임 책상은 그림 속 큰 책상 자리로 고정)
        facilities = facilities.map { placed in
            if placed.kind == .researcherDesk { return PlacedFacility(id: placed.id, kind: .researcherDesk, position: Self.deskPosition) }
            guard Self.fixedCells.contains(placed.position) || !Self.isInsideGrid(placed.position) else { return placed }
            var probe = self
            probe.facilities.removeAll { $0.id == placed.id }
            return PlacedFacility(id: placed.id, kind: placed.kind, position: probe.firstFreeCell(near: placed.position) ?? placed.position)
        }
        if !facilities.contains(where: { $0.kind == .traineeDesk }), let spot = firstFreeCell(near: Self.traineeDeskPosition) {
            facilities.append(PlacedFacility(kind: .traineeDesk, position: spot))
        }
    }

    /// target에서 가까운 빈 칸 (맨해튼 거리 순)
    func firstFreeCell(near target: GridPosition) -> GridPosition? {
        let taken = Set(facilities.map(\.position)).union(Self.fixedCells)
        var cells: [GridPosition] = []
        for column in 0..<Self.gridColumns {
            for row in 0..<Self.gridRows {
                cells.append(GridPosition(column: column, row: row))
            }
        }
        return cells.filter { !taken.contains($0) }
            .min { abs($0.column - target.column) + abs($0.row - target.row) < abs($1.column - target.column) + abs($1.row - target.row) }
    }

    static func isInsideGrid(_ position: GridPosition) -> Bool {
        (0..<gridColumns).contains(position.column) && (0..<gridRows).contains(position.row)
    }

    /// 연구소 영향력 (影響力) — M1에서는 복원한 한자 수
    public var influence: Int { restoredKanji.count }

    /// 연구소 하늘 (영향력이 오를수록 흐림 → 맑음)
    public var instituteSky: WeatherCondition {
        switch influence {
        case 0..<3: return .rain
        case 3..<6: return .cloudy
        default: return .clear
        }
    }
}

// MARK: - 정산 결과 (연구원 안내 대사에 사용)
public struct InstituteSettlement: Equatable, Sendable {
    public let rewards: [ResearchReward]
    public let basePoints: Int
    public let bonusPercent: Int
    public let gainedPoints: Int
    public let budgetGranted: Int

    public var newWordCount: Int { rewards.filter { $0.kind == .newWord }.count }
    public var reviewCount: Int { rewards.filter { $0.kind == .review }.count }
    public var isEmpty: Bool { rewards.isEmpty && budgetGranted == 0 }
}
