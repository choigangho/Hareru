import Foundation

// MARK: - 성우 캐릭터 분류
public enum VoiceArchetype: String, Codable, Equatable, Hashable, Sendable {
    case everyday = "everyday"       // 현실 일상·직장 캐릭터
    case homage = "homage"           // 서브컬처·장르 오마주 캐릭터
    case modulated = "modulated"     // 특수 음향 필터(변조/방송 등) 캐릭터
}

// MARK: - 256kbps AivisSpeech 성우 캐릭터 프로필
public struct VoiceProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let archetype: VoiceArchetype
    public let tagline: String
    public let accentHex: String
    public let aivisStyleId: Int?

    public init(
        id: String,
        label: String,
        archetype: VoiceArchetype = .everyday,
        tagline: String = "",
        accentHex: String = "#5C4033",
        aivisStyleId: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.archetype = archetype
        self.tagline = tagline
        self.accentHex = accentHex
        self.aivisStyleId = aivisStyleId
    }

    // MARK: - 음성 캐릭터 미정 (게임 인물이 확정되면 배정)
    // 음성 캐릭터는 연구소 게임의 인물(주연·조연·기타 인물)과 연동하기로 결정 (Docs/GAME_DESIGN.md §2.1).
    // 인물이 정해지기 전에 만든 단어 데이터는 이 값으로 두고, 카드에서는 별명 태그를 숨깁니다.
    public static let unassigned = VoiceProfile(id: "unassigned", label: "")

    public var isAssigned: Bool { id != Self.unassigned.id }

    // MARK: - 연구소(NJL) 게임 음성 캐릭터 10인 (Docs/GAME_DESIGN.md §2.2)
    // 단어·예문 음성은 이 인물들이 맡음. 카드 별명 태그에는 label이 표시되므로,
    // 주임 연구원은 이름 읽기 비밀 설정(§6.1)에 따라 직함만 씀.

    public static let guideResearcher = VoiceProfile(
        id: "guide_researcher",
        label: "주임 연구원",
        tagline: "한자를 전부 아는 최후의 1인. 좋아하는 어원이 나오면 말이 빨라짐",
        accentHex: "#4F6D8F"
    )

    public static let aiKuro = VoiceProfile(
        id: "ai_kuro",
        label: "KURO",
        archetype: .modulated,
        tagline: "수리된 구형 언어 기록 안드로이드 NJL-09. 담담한 보고체",
        accentHex: "#3F4A56"
    )

    public static let masterGen = VoiceProfile(
        id: "master_gen",
        label: "미나모토 겐",
        tagline: "연구소 1층 찻집 겸 식당 마스터. 아날로그 요리를 고집하는 아저씨",
        accentHex: "#8A5A3C"
    )

    public static let courierRin = VoiceProfile(
        id: "courier_rin",
        label: "카자마 린",
        tagline: "폐허 서점가에서 종이책을 찾아오는 스쿠터 배달원",
        accentHex: "#E07A3F"
    )

    public static let rivalReina = VoiceProfile(
        id: "rival_reina",
        label: "칸자키 레이나",
        tagline: "NeuroLex 언어압축부 수석 이사. 한자를 레거시 데이터로 보는 완벽주의자",
        accentHex: "#5B4B8A"
    )

    public static let inspectorRen = VoiceProfile(
        id: "inspector_ren",
        label: "타치바나 렌",
        tagline: "연구소 예산을 쥔 감사관. 회의적인 척하지만 은근히 돕는다",
        accentHex: "#2F6F73"
    )

    public static let elderTsuru = VoiceProfile(
        id: "elder_tsuru",
        label: "시라이시 츠루",
        tagline: "종이 시대를 기억하는 최고령 기증자",
        accentHex: "#9C6B7A"
    )

    public static let citizenMio = VoiceProfile(
        id: "citizen_mio",
        label: "미오",
        tagline: "손글씨에 호기심이 생긴 뉴럴링크 세대 고등학생",
        accentHex: "#D9668A"
    )

    public static let craftsmanJin = VoiceProfile(
        id: "craftsman_jin",
        label: "진",
        tagline: "복원된 한자로 도시의 간판을 고치는 장인",
        accentHex: "#B5893A"
    )

    public static let announcerAI = VoiceProfile(
        id: "announcer_ai",
        label: "원내 방송",
        archetype: .modulated,
        tagline: "연구소 안내 방송 겸 도시 기상·뉴스 속보 AI",
        accentHex: "#4A7FB5"
    )

    public static let gameCast: [VoiceProfile] = [
        .guideResearcher, .aiKuro,
        .masterGen, .courierRin, .rivalReina, .inspectorRen, .elderTsuru,
        .citizenMio, .craftsmanJin, .announcerAI
    ]

    // MARK: - 기존 시그니처 성우 라인업 (SPEC.md §4)
    // ⚠️ 게임 인물 확정 전의 임시 라인업. 이미 번들된 30단어·녹음 오디오가 참조하고 있어 남겨 둠.

    public static let buchou = VoiceProfile(
        id: "buchou",
        label: "이자카야 부장님",
        archetype: .everyday,
        tagline: "퇴근 후 생맥주 한 잔에 진심인 호탕한 상사",
        accentHex: "#73421F"
    )

    public static let tenchou = VoiceProfile(
        id: "tenchou",
        label: "라멘집 사장님",
        archetype: .everyday,
        tagline: "진한 돈코츠 육수 자부심으로 뭉친 장인",
        accentHex: "#8C271E"
    )

    public static let konbiniClerk = VoiceProfile(
        id: "konbini_clerk",
        label: "편의점 알바생",
        archetype: .everyday,
        tagline: "새벽 근무 중에도 텐션 높은 친절 알바생",
        accentHex: "#2563EB"
    )

    public static let tokyoSenpai = VoiceProfile(
        id: "tokyo_senpai",
        label: "도쿄 오피스 선배",
        archetype: .everyday,
        tagline: "정중하고 깔끔한 비즈니스 일본어의 정석",
        accentHex: "#334155"
    )

    public static let cafeStaff = VoiceProfile(
        id: "cafe_staff",
        label: "디저트 점원",
        archetype: .everyday,
        tagline: "부드럽고 상냥한 디저트 카페 파티시에",
        accentHex: "#DB2777"
    )

    public static let kyotoGrandma = VoiceProfile(
        id: "kyoto_grandma",
        label: "교토 할머니",
        archetype: .everyday,
        tagline: "나긋나긋한 교토 사투리로 차를 내어주는 어르신",
        accentHex: "#65A30D"
    )

    public static let expeditionCaptain = VoiceProfile(
        id: "expedition_captain",
        label: "벽 외 조사단장",
        archetype: .homage,
        tagline: "안일한 생각을 단숨에 꾸짖는 냉철한 지휘관",
        accentHex: "#3F6212"
    )

    public static let knightCommander = VoiceProfile(
        id: "knight_commander",
        label: "왕국 기사단장",
        archetype: .homage,
        tagline: "맹세와 신의를 중시하는 중후한 기사",
        accentHex: "#B45309"
    )

    public static let alchemyMerchant = VoiceProfile(
        id: "alchemy_merchant",
        label: "연금술 상인",
        archetype: .homage,
        tagline: "등가교환과 흥정에 능숙한 노련한 상인",
        accentHex: "#9333EA"
    )

    public static let modulatedDetective = VoiceProfile(
        id: "modulated_detective",
        label: "음성변조 명탐정",
        archetype: .modulated,
        tagline: "모니터 너머 기계 변조음으로 허점을 찌르는 탐정",
        accentHex: "#0284C7"
    )

    public static let allPresets: [VoiceProfile] = [
        .buchou,
        .tenchou,
        .konbiniClerk,
        .tokyoSenpai,
        .cafeStaff,
        .kyotoGrandma,
        .expeditionCaptain,
        .knightCommander,
        .alchemyMerchant,
        .modulatedDetective
    ]

    public static func preset(forId id: String) -> VoiceProfile {
        if id == unassigned.id {
            return unassigned
        }
        if let found = (gameCast + allPresets).first(where: { $0.id == id }) {
            return found
        }
        return VoiceProfile(id: id, label: id)
    }
}
