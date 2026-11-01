import Foundation

// MARK: - 성실도 잔디(히트맵) 하루 칸
public struct StudyHeatmapDay: Identifiable, Equatable, Hashable, Sendable {
    public let date: Date            // 해당 날짜의 자정(시작 시각)
    public let dayKey: String
    public let studiedWordCount: Int // 그날 평가한 고유 단어 수
    public let reviewCount: Int      // 그날 누른 평가 버튼 총 횟수
    public let intensityLevel: Int   // 0(없음) ~ 4(가장 많음)
    public let isFuture: Bool        // 이번 주의 아직 오지 않은 날

    public var id: String { dayKey }
}

// MARK: - 최근 N주 성실도 잔디 계산기
// GitHub 잔디처럼 열 = 주(일요일 시작), 행 = 요일로 배치합니다.
public enum StudyHeatmapCalculator {
    /// 고유 단어 수 → 0~4 단계 강도 (1~4 / 5~9 / 10~19 / 20+)
    public static func intensityLevel(forWordCount count: Int) -> Int {
        switch count {
        case ..<1: return 0
        case 1..<5: return 1
        case 5..<10: return 2
        case 10..<20: return 3
        default: return 4
        }
    }

    /// 최근 `weeks`주를 주 단위 열(각 7칸)로 반환합니다. 마지막 열은 `now`가 속한 주입니다.
    public static func weeklyColumns(
        logs: [ReviewLogEntry],
        weeks: Int = 14,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [[StudyHeatmapDay]] {
        guard weeks > 0 else { return [] }

        var wordsByDayKey: [String: Set<String>] = [:]
        var reviewsByDayKey: [String: Int] = [:]
        for log in logs {
            let key = DayKeyFormatter.dayKey(for: log.reviewedAt, calendar: calendar)
            wordsByDayKey[key, default: []].insert(log.wordId)
            reviewsByDayKey[key, default: 0] += 1
        }

        let today = calendar.startOfDay(for: now)
        let weekdayOffset = calendar.component(.weekday, from: today) - 1 // 일요일 = 0
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -weekdayOffset, to: today),
              let firstWeekStart = calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: currentWeekStart) else {
            return []
        }

        return (0..<weeks).map { weekIndex in
            (0..<7).compactMap { dayIndex -> StudyHeatmapDay? in
                guard let date = calendar.date(byAdding: .day, value: weekIndex * 7 + dayIndex, to: firstWeekStart) else {
                    return nil
                }
                let key = DayKeyFormatter.dayKey(for: date, calendar: calendar)
                let wordCount = wordsByDayKey[key]?.count ?? 0
                return StudyHeatmapDay(
                    date: date,
                    dayKey: key,
                    studiedWordCount: wordCount,
                    reviewCount: reviewsByDayKey[key] ?? 0,
                    intensityLevel: intensityLevel(forWordCount: wordCount),
                    isFuture: date > today
                )
            }
        }
    }

    /// 오늘(또는 오늘 학습 전이라면 어제)부터 거슬러 올라가며 연속 학습한 일수
    public static func currentStreak(
        logs: [ReviewLogEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let studiedKeys = Set(logs.map { DayKeyFormatter.dayKey(for: $0.reviewedAt, calendar: calendar) })
        var cursor = calendar.startOfDay(for: now)
        if !studiedKeys.contains(DayKeyFormatter.dayKey(for: cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while studiedKeys.contains(DayKeyFormatter.dayKey(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// 사용자가 실제로 누른 4버튼('모르겠음 / 애매함 / 알고있음 / 쉬움')별 누적 횟수
    public static func buttonDistribution(logs: [ReviewLogEntry]) -> [(button: ReviewButton, count: Int)] {
        var counts: [ReviewButton: Int] = [:]
        for log in logs {
            counts[log.button, default: 0] += 1
        }
        return ReviewButton.allCases.map { ($0, counts[$0, default: 0]) }
    }
}
