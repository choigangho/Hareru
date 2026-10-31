import Foundation

// MARK: - JLPT 급수 열거형
public enum JLPTLevel: String, Codable, CaseIterable, Comparable, Hashable, Sendable {
    case n5 = "N5"
    case n4 = "N4"
    case n3 = "N3"
    case n2 = "N2"
    case n1 = "N1"

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
}
