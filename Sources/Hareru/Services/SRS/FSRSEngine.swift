import Foundation

// MARK: - 사용자 노출 4버튼 (직관적 UI 유지, SPEC.md §3.1)
public enum ReviewButton: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case again = "again"   // 어려움
    case hard = "hard"     // 애매함
    case good = "good"     // 앎
    case easy = "easy"     // 쉬움

    public var koreanTitle: String {
        switch self {
        case .again: return "어려움"
        case .hard: return "애매함"
        case .good: return "앎"
        case .easy: return "쉬움"
        }
    }
}

// MARK: - 내부 6단계 히든 평가 등급 (반응 시간 × 선택 버튼 조합, SPEC.md §3.1)
public enum EvaluationGrade: Int, Codable, CaseIterable, Comparable, Equatable, Hashable, Sendable {
    case again = 1                // 1. 어려움 (큐 재투입 + 침식도 상승)
    case hiddenHintAssisted = 2   // 2. [히든 1 · 힌트의존] (세션 말미 가벼운 재확인)
    case hard = 3                 // 3. 애매함 (세션 내 1회 재확인)
    case good = 4                 // 4. 앎 [졸업 기준선] (즉시 졸업 + 컬러 정화, 약 1일)
    case hiddenNearEasy = 5       // 5. [히든 2 · 준-쉬움] (즉시 졸업 + 컬러 정화, 약 2일)
    case easy = 6                 // 6. 쉬움 (즉시 졸업 + 컬러 정화, 4일 이상 장기 점프)

    public static func < (lhs: EvaluationGrade, rhs: EvaluationGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 당일 세션 졸업 기준선 달성 여부 (`4등급: 앎` 이상)
    public var isGraduating: Bool {
        rawValue >= EvaluationGrade.good.rawValue
    }

    /// 배경 그라데이션 Red+Black 침식을 유발하는 등급 여부 (`1등급: 어려움`)
    public var incrementsErosion: Bool {
        self == .again
    }

    public var displayName: String {
        switch self {
        case .again: return "어려움"
        case .hiddenHintAssisted: return "히든1·힌트의존"
        case .hard: return "애매함"
        case .good: return "앎"
        case .hiddenNearEasy: return "히든2·준쉬움"
        case .easy: return "쉬움"
        }
    }
}

// MARK: - 반응 시간 판정 임계값 설정 (단위: 초)
public struct ReactionThresholds: Codable, Equatable, Hashable, Sendable {
    public let lightningGoodUpperBound: Double   // 0 ~ 2.5초 '앎' → 히든2(준-쉬움)
    public let standardGoodUpperBound: Double    // 2.5 ~ 6.0초 '앎' → 앎(4), 6.0초 이상 → 히든1(2)
    public let confidentHardUpperBound: Double   // 0 ~ 6.0초 '애매함' → 애매함(3)
    public let hintWindowUpperBound: Double      // 6.0 ~ 10.0초 '애매함' → 히든1(2), 10.0초 이상 → 어려움(1)
    public let fastEasyUpperBound: Double        // 0 ~ 3.5초 '쉬움' → 쉬움(6)
    public let moderateEasyUpperBound: Double    // 3.5 ~ 7.0초 '쉬움' → 히든2(5), 7.0초 이상 → 앎(4) 완충

    public init(
        lightningGoodUpperBound: Double = 2.5,
        standardGoodUpperBound: Double = 6.0,
        confidentHardUpperBound: Double = 6.0,
        hintWindowUpperBound: Double = 10.0,
        fastEasyUpperBound: Double = 3.5,
        moderateEasyUpperBound: Double = 7.0
    ) {
        self.lightningGoodUpperBound = lightningGoodUpperBound
        self.standardGoodUpperBound = standardGoodUpperBound
        self.confidentHardUpperBound = confidentHardUpperBound
        self.hintWindowUpperBound = hintWindowUpperBound
        self.fastEasyUpperBound = fastEasyUpperBound
        self.moderateEasyUpperBound = moderateEasyUpperBound
    }

    public static let standard = ReactionThresholds()
}

// MARK: - FSRS 핵심 기억 상태 값 타입 (DSR: Difficulty · Stability · Retrievability)
public struct MemoryState: Codable, Equatable, Hashable, Sendable {
    public var stability: Double        // S: 기억 안정성 (예상 90% 유지 일수)
    public var difficulty: Double       // D: 내재 난이도 (1.0 ~ 10.0)
    public var reps: Int                // 누적 일일 졸업 횟수
    public var lapses: Int              // 일간 망각 횟수 (세션 내 다회 실패는 중복 가산하지 않음)
    public var lastReviewedAt: Date?
    public var dueAt: Date

    public init(
        stability: Double,
        difficulty: Double,
        reps: Int,
        lapses: Int,
        lastReviewedAt: Date?,
        dueAt: Date
    ) {
        self.stability = max(0.1, stability)
        self.difficulty = min(max(difficulty, 1.0), 10.0)
        self.reps = max(0, reps)
        self.lapses = max(0, lapses)
        self.lastReviewedAt = lastReviewedAt
        self.dueAt = dueAt
    }
}

// MARK: - 졸업 시점 FSRS 스케줄링 결과
public struct FSRSScheduleResult: Equatable, Sendable {
    public let grade: EvaluationGrade
    public let updatedState: MemoryState
    public let scheduledIntervalDays: Int
    public let retrievabilityBeforeReview: Double
}

// MARK: - 날짜 키 포맷터 (당일 조우 캡 및 서로 다른 날 보류 판정용)
public enum DayKeyFormatter {
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public static func startOfNextDay(after date: Date, calendar: Calendar = .current, days: Int = 1) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: max(1, days), to: startOfToday)
            ?? date.addingTimeInterval(Double(max(1, days)) * 86_400.0)
    }
}

// MARK: - FSRS 6단계 기억 엔진 (SPEC.md §3.1, §3.2)
public struct FSRSEngine: Sendable {
    /// FSRS v4.5/v5 표준 망각 곡선 상수: R(t = S, S) = (1 + 19/81 * 1)^(-0.5) = 0.90
    private static let forgettingFactor: Double = 19.0 / 81.0
    private static let forgettingDecay: Double = -0.5

    public let desiredRetention: Double
    public let thresholds: ReactionThresholds

    public init(
        desiredRetention: Double = 0.90,
        thresholds: ReactionThresholds = .standard
    ) {
        self.desiredRetention = min(max(desiredRetention, 0.70), 0.97)
        self.thresholds = thresholds
    }

    // MARK: - 1) 반응 시간 × 4버튼 → 6단계 히든 등급 판정

    public func classifyGrade(
        button: ReviewButton,
        elapsedSeconds: Double
    ) -> EvaluationGrade {
        let t = max(0.0, elapsedSeconds)

        switch button {
        case .again:
            return .again

        case .hard:
            if t < thresholds.confidentHardUpperBound {
                return .hard
            } else if t < thresholds.hintWindowUpperBound {
                return .hiddenHintAssisted
            } else {
                return .again
            }

        case .good:
            if t < thresholds.lightningGoodUpperBound {
                return .hiddenNearEasy
            } else if t < thresholds.standardGoodUpperBound {
                return .good
            } else {
                return .hiddenHintAssisted
            }

        case .easy:
            if t < thresholds.fastEasyUpperBound {
                return .easy
            } else if t < thresholds.moderateEasyUpperBound {
                return .hiddenNearEasy
            } else {
                // 늦은 시간에 '쉬움'을 누른 경우 과도한 강등 없이 표준 졸업선(4등급)으로 완충
                return .good
            }
        }
    }

    // MARK: - 2) 현재 기억 인출 확률 R(t, S) 및 목표 복습 간격 I(S, r) 계산

    /// 경과 일수(`elapsedDays`)와 안정성(`stability`)으로 현재 기억 유지율 `R` (0.0 ~ 1.0) 산출
    public func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0.0 }
        let t = max(0.0, elapsedDays)
        guard t > 0 else { return 1.0 }
        let value = pow(1.0 + Self.forgettingFactor * (t / stability), Self.forgettingDecay)
        return min(max(value, 0.0), 1.0)
    }

    /// 특정 시각(`now`) 기준 `MemoryState`의 실시간 기억 유지율 `R`
    public func currentRetrievability(for state: MemoryState, now: Date = Date()) -> Double {
        guard let lastReviewedAt = state.lastReviewedAt, state.reps > 0 else {
            return 0.0
        }
        let elapsedDays = max(0.0, now.timeIntervalSince(lastReviewedAt) / 86_400.0)
        return retrievability(elapsedDays: elapsedDays, stability: state.stability)
    }

    /// 목표 기억 유지율(`desiredRetention`)을 만족하는 다음 복습 일수 산출
    public func nextIntervalDays(stability: Double, minimumDays: Int = 1) -> Int {
        let s = max(0.1, stability)
        let rawInterval = (s / Self.forgettingFactor) * (pow(desiredRetention, 1.0 / Self.forgettingDecay) - 1.0)
        return max(minimumDays, Int(rawInterval.rounded()))
    }

    // MARK: - 3) 당일 졸업 시점 FSRS 상태 갱신 (당일 세션 내 실패 면책 보장)

    /// 4등급(`앎`) 이상으로 졸업할 때 호출하여 장기 기억 파라미터(`S`, `D`, `dueAt`)를 갱신합니다.
    /// - 중요(Ease Hell 방지, SPEC.md §3.2):
    ///   당일 세션 내 반복 실패 횟수는 예열 과정으로 간주하여 장기 난이도(`D`)에 페널티를 전혀 부과하지 않습니다.
    public func evaluateGraduation(
        previousState: MemoryState?,
        grade: EvaluationGrade,
        hadInterDayLapseToday: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FSRSScheduleResult {
        precondition(grade.isGraduating, "evaluateGraduation requires a graduating grade (>= 4).")

        let minDaysForGrade: Int
        switch grade {
        case .good: minDaysForGrade = 1
        case .hiddenNearEasy: minDaysForGrade = 2
        case .easy: minDaysForGrade = 4
        default: minDaysForGrade = 1
        }

        // Case A: 신규 학습 단어 첫 졸업 (`reps == 0`)
        guard let prev = previousState, prev.reps > 0 else {
            let initS = Self.initialStability(for: grade)
            let initD = Self.initialDifficulty(for: grade)
            let interval = nextIntervalDays(stability: initS, minimumDays: minDaysForGrade)
            let dueDate = DayKeyFormatter.startOfNextDay(after: now, calendar: calendar, days: interval)

            let newState = MemoryState(
                stability: initS,
                difficulty: initD,
                reps: 1,
                lapses: 0,
                lastReviewedAt: now,
                dueAt: dueDate
            )
            return FSRSScheduleResult(
                grade: grade,
                updatedState: newState,
                scheduledIntervalDays: interval,
                retrievabilityBeforeReview: 0.0
            )
        }

        // Case B: 기존 졸업 이력이 있는 복습 단어
        let elapsedDays: Double
        if let last = prev.lastReviewedAt {
            elapsedDays = max(0.0, now.timeIntervalSince(last) / 86_400.0)
        } else {
            elapsedDays = 1.0
        }
        let priorR = retrievability(elapsedDays: elapsedDays, stability: prev.stability)

        // 당일 실패 면책(Ease Hell 방지):
        // 세션 내 몇 번을 틀렸든 난이도 D를 가중 처벌하지 않으며,
        // 높은 등급(5, 6)으로 졸업한 경우에만 완만한 난이도 하향 및 평균 회귀(5.0) 적용
        let updatedDifficulty = Self.updatedDifficultyOnGraduation(
            currentDifficulty: prev.difficulty,
            grade: grade,
            hadInterDayLapseToday: hadInterDayLapseToday
        )

        let updatedStability: Double
        let updatedLapses: Int

        if hadInterDayLapseToday {
            // 이전 날 외웠던 단어를 오늘 첫 대면에서 잊어버린 뒤 재학습하여 졸업한 경우:
            // 일간 망각(lapses)은 오늘 하루 최대 1회만 기록하고, 재학습 안정성으로 부드럽게 재설정
            updatedLapses = prev.lapses + 1
            let baseRelearnS = Self.initialStability(for: grade)
            let retainedPortion = pow(max(prev.stability, 1.0), 0.5) * Self.relearnMultiplier(for: grade)
            updatedStability = min(max(baseRelearnS, retainedPortion), max(baseRelearnS, prev.stability))
        } else {
            // 첫 대면에서 자력 인출에 성공한 정식 복습 졸업: 안정성(S) 성장
            updatedLapses = prev.lapses
            let effectiveElapsed = max(elapsedDays, 0.5)
            let effectiveR = retrievability(elapsedDays: effectiveElapsed, stability: prev.stability)
            let bonus = Self.recallBonus(for: grade)
            let growth = exp(0.95)
                * (11.0 - updatedDifficulty)
                * pow(max(prev.stability, 0.5), -0.15)
                * (exp(0.85 * (1.0 - effectiveR)) - 1.0)
                * bonus
            updatedStability = max(prev.stability * (1.0 + max(0.15, growth)), Self.initialStability(for: grade))
        }

        let interval = nextIntervalDays(stability: updatedStability, minimumDays: minDaysForGrade)
        let dueDate = DayKeyFormatter.startOfNextDay(after: now, calendar: calendar, days: interval)

        let newState = MemoryState(
            stability: updatedStability,
            difficulty: updatedDifficulty,
            reps: prev.reps + 1,
            lapses: updatedLapses,
            lastReviewedAt: now,
            dueAt: dueDate
        )

        return FSRSScheduleResult(
            grade: grade,
            updatedState: newState,
            scheduledIntervalDays: interval,
            retrievabilityBeforeReview: priorR
        )
    }

    // MARK: - 내부 파라미터 헬퍼

    private static func initialStability(for grade: EvaluationGrade) -> Double {
        switch grade {
        case .good:
            return 1.0   // 표준 초기 주기: 약 1일
        case .hiddenNearEasy:
            return 2.0   // 우대 주기: 약 2일
        case .easy:
            return 4.5   // 장기 점프: 4~5일
        default:
            return 1.0
        }
    }

    private static func initialDifficulty(for grade: EvaluationGrade) -> Double {
        switch grade {
        case .good:
            return 5.0
        case .hiddenNearEasy:
            return 4.0
        case .easy:
            return 2.8
        default:
            return 5.0
        }
    }

    private static func updatedDifficultyOnGraduation(
        currentDifficulty: Double,
        grade: EvaluationGrade,
        hadInterDayLapseToday: Bool
    ) -> Double {
        // 당일 실패 면책(SPEC.md §3.2): 재학습 졸업이더라도 난이도 D 페널티를 부과하지 않음
        if hadInterDayLapseToday {
            if grade == .easy {
                return clampDifficulty(currentDifficulty - 0.25)
            }
            return clampDifficulty(currentDifficulty)
        }

        let delta: Double
        switch grade {
        case .good:
            delta = 0.0
        case .hiddenNearEasy:
            delta = -0.35
        case .easy:
            delta = -0.75
        default:
            delta = 0.0
        }
        let meanReverted = 0.10 * 5.0 + 0.90 * (currentDifficulty + delta)
        return clampDifficulty(meanReverted)
    }

    private static func recallBonus(for grade: EvaluationGrade) -> Double {
        switch grade {
        case .good: return 1.00
        case .hiddenNearEasy: return 1.22
        case .easy: return 1.48
        default: return 1.00
        }
    }

    private static func relearnMultiplier(for grade: EvaluationGrade) -> Double {
        switch grade {
        case .good: return 0.85
        case .hiddenNearEasy: return 1.10
        case .easy: return 1.40
        default: return 0.85
        }
    }

    private static func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1.0), 10.0)
    }
}
