import Foundation

// MARK: - 연구소 시설 (M1: 1단계 사무실에 놓을 수 있는 5종, Docs/GAME_DESIGN.md §5.2)
public enum FacilityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case researcherDesk   // 연구원 책상 (시작 시 배치, 철거 불가)
    case kanjiArchive     // 한자 서고
    case copyRoom         // 필사실
    case recordingBooth   // 녹음 부스
    case serverRack       // 서버 랙

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .researcherDesk: return "연구원 책상"
        case .kanjiArchive: return "한자 서고"
        case .copyRoom: return "필사실"
        case .recordingBooth: return "녹음 부스"
        case .serverRack: return "서버 랙"
        }
    }

    public var summary: String {
        switch self {
        case .researcherDesk: return "연구소의 시작점. 가이드 연구원이 머무는 자리"
        case .kanjiArchive: return "복원한 한자를 보관 · 연구 포인트 +5%"
        case .copyRoom: return "획순과 부수를 옮겨 적는 방 · 복원 비용 -10%"
        case .recordingBooth: return "말로 하는 일본어를 기록 · 연구 포인트 +5%"
        case .serverRack: return "AI 모듈이 돌아가는 서버 · 연구 포인트 +10%"
        }
    }

    /// 설치 비용 (予算)
    public var budgetCost: Int {
        switch self {
        case .researcherDesk: return 0
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
        case .researcherDesk, .copyRoom: return 0
        }
    }

    public var restoreDiscountPercent: Int {
        self == .copyRoom ? 10 : 0
    }

    /// 한 사무실에 하나만 둘 수 있는 시설
    public var isUnique: Bool { self == .researcherDesk }
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

    public static let gridColumns = 6
    public static let gridRows = 6
    public static let startingBudget = 200
    public static let deskPosition = GridPosition(column: 2, row: 2)

    public init(
        stage: Int = 1,
        researchPoints: Int = 0,
        budget: Int = InstituteState.startingBudget,
        facilities: [PlacedFacility] = [PlacedFacility(kind: .researcherDesk, position: InstituteState.deskPosition)],
        restoredKanji: [String] = [],
        rewardedReviewKeys: Set<String> = [],
        lastBudgetGrantDayKey: String? = nil,
        hasSeenIntro: Bool = false
    ) {
        self.stage = stage
        self.researchPoints = researchPoints
        self.budget = budget
        self.facilities = facilities
        self.restoredKanji = restoredKanji
        self.rewardedReviewKeys = rewardedReviewKeys
        self.lastBudgetGrantDayKey = lastBudgetGrantDayKey
        self.hasSeenIntro = hasSeenIntro
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
