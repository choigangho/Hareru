import Foundation

// MARK: - JLPT 급수 열거형 및 급수별 표준 신규 어휘 수 기준
public enum JLPTLevel: String, Codable, CaseIterable, Comparable, Hashable, Sendable, Identifiable {
    case n5 = "N5"
    case n4 = "N4"
    case n3 = "N3"
    case n2 = "N2"
    case n1 = "N1"

    public var id: String { rawValue }

    private var sortOrder: Int {
        switch self {
        case .n5: return 1
        case .n4: return 2
        case .n3: return 3
        case .n2: return 4
        case .n1: return 5
        }
    }

    public static func < (lhs: JLPTLevel, rhs: JLPTLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    /// 해당 급수 단독 신규 어휘 수 (하위 급수는 이미 알고 있다고 가정할 때 해당 급수에서 새로 외워야 할 표준 어휘량)
    /// 누적 기준(N5 800 / N4 1,500 / N3 3,700 / N2 6,000 / N1 10,000)에서 하위 급수를 뺀 순수 해당 급수 어휘 수
    public var standardLevelWordCount: Int {
        switch self {
        case .n5: return 800
        case .n4: return 700
        case .n3: return 2200
        case .n2: return 2300
        case .n1: return 4000
        }
    }

    /// 급수 설명 부제
    public var subtitle: String {
        switch self {
        case .n5: return "기초 입문 · 일상 필수 표현 (신규 약 800단어)"
        case .n4: return "초급 완성 · 기본 생활 회화 (신규 약 700단어)"
        case .n3: return "중급 도약 · 자연스러운 일상·직장 어휘 (신규 약 2,200단어)"
        case .n2: return "실무·뉴스 · 비즈니스 핵심 어휘 (신규 약 2,300단어)"
        case .n1: return "최상급 · 학술·추상·고급 한자어 (신규 약 4,000단어)"
        }
    }
}
