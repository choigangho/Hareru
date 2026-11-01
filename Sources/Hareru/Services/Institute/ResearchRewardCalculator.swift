import Foundation

// MARK: - 학습 → 연구 포인트(研究P) 정산 (Docs/GAME_DESIGN.md §4.1 무결성 규칙)
// 1) 근거는 학습 기록(ReviewLogEntry)뿐 — 읽기만 하고 수정하지 않음
// 2) 같은 날 같은 단어는 한 번만 보상 (반복 클릭 파밍 차단)
// 3) 외움 완료(didGraduate)로 판정된 기록만 보상
// 4) 보상 크기 = 기억 품질: 오래 기억해 온 단어(복습 직전 안정도 S)일수록, 간격을 두고 떠올렸을수록 큼
public struct ResearchReward: Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case newWord   // 처음 외움
        case review    // 다시 떠올림 (복습)
    }

    public let wordId: String
    public let dayKey: String
    public let kind: Kind
    public let points: Int

    /// 같은 날 같은 단어 중복 보상을 막는 키
    public var key: String { "\(wordId)|\(dayKey)" }
}

public enum ResearchRewardCalculator {
    public static let newWordPoints = 10
    public static let reviewBasePoints = 6
    public static let spacedRecallBonus = 2      // 하루 이상 간격을 두고 떠올림
    public static let fluentRecallBonus = 2      // 빠르고 확실한 인출 (히든 등급 5·6)
    public static let maxStabilityBonus = 8

    /// 학습 기록 한 건이 받을 수 있는 포인트 (외움 완료가 아니면 0)
    public static func points(for log: ReviewLogEntry) -> (kind: ResearchReward.Kind, points: Int)? {
        guard log.didGraduate else { return nil }

        let isFirstLearning = log.elapsedDaysSinceLastReview == nil && log.priorStability <= 0
        var total: Int
        let kind: ResearchReward.Kind
        if isFirstLearning {
            kind = .newWord
            total = newWordPoints
        } else {
            kind = .review
            // 안정도 S가 1 → +1, 3 → +2, 7 → +3, 15 → +4 … (로그 스케일, 상한 8)
            let stabilityBonus = min(maxStabilityBonus, Int(log2(1 + max(0, log.priorStability)).rounded()))
            total = reviewBasePoints + stabilityBonus
            if (log.elapsedDaysSinceLastReview ?? 0) >= 1 {
                total += spacedRecallBonus
            }
        }
        if log.grade == .easy || log.grade == .hiddenNearEasy {
            total += fluentRecallBonus
        }
        return (kind, total)
    }

    /// 아직 정산되지 않은 기록에서 (단어, 날짜)마다 가장 좋은 한 건만 보상으로 뽑음
    public static func rewards(
        logs: [ReviewLogEntry],
        alreadyRewardedKeys: Set<String>,
        calendar: Calendar = .current
    ) -> [ResearchReward] {
        var bestByKey: [String: ResearchReward] = [:]
        for log in logs {
            guard let scored = points(for: log) else { continue }
            let reward = ResearchReward(
                wordId: log.wordId,
                dayKey: DayKeyFormatter.dayKey(for: log.reviewedAt, calendar: calendar),
                kind: scored.kind,
                points: scored.points
            )
            guard !alreadyRewardedKeys.contains(reward.key) else { continue }
            if let existing = bestByKey[reward.key], existing.points >= reward.points {
                continue
            }
            bestByKey[reward.key] = reward
        }
        return bestByKey.values.sorted { ($0.dayKey, $0.wordId) < ($1.dayKey, $1.wordId) }
    }
}
