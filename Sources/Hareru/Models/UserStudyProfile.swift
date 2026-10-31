import Foundation
import CryptoKit

// MARK: - 사용자 계정 및 목표 학습 설정 프로필 (이메일/비밀번호 인증 + 진단 결과 저장)
public struct UserStudyProfile: Codable, Equatable, Sendable {
    public let userId: String
    public var email: String
    public var displayName: String
    public var passwordHash: String
    public var targetLevel: JLPTLevel
    public var examDate: Date
    public var diagnosticTestedCount: Int      // 진단 테스트 문항 수 (기본 10문항)
    public var diagnosticCorrectCount: Int     // 진단 테스트 정답 수 (0 ~ 10)
    public var diagnosticAverageSeconds: Double // 진단 테스트 평균 응답 시간(초)
    public var createdAt: Date

    public init(
        userId: String = UUID().uuidString,
        email: String,
        displayName: String,
        passwordHash: String,
        targetLevel: JLPTLevel,
        examDate: Date,
        diagnosticTestedCount: Int = 10,
        diagnosticCorrectCount: Int,
        diagnosticAverageSeconds: Double,
        createdAt: Date = Date()
    ) {
        self.userId = userId
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.passwordHash = passwordHash
        self.targetLevel = targetLevel
        self.examDate = examDate
        self.diagnosticTestedCount = max(1, diagnosticTestedCount)
        self.diagnosticCorrectCount = min(max(0, diagnosticCorrectCount), max(1, diagnosticTestedCount))
        self.diagnosticAverageSeconds = max(0.1, diagnosticAverageSeconds)
        self.createdAt = createdAt
    }

    /// 진단 테스트 정답률 (`0.0 ~ 1.0`)
    public var diagnosticAccuracy: Double {
        Double(diagnosticCorrectCount) / Double(max(1, diagnosticTestedCount))
    }

    public static func hashPassword(_ plainText: String) -> String {
        let digest = SHA256.hash(data: Data(plainText.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - 10문항 4지선다 진단 테스트 문항 & 응답 모델
public struct DiagnosticQuestion: Identifiable, Equatable, Sendable {
    public let id: String
    public let index: Int                  // 1...10
    public let word: Word
    public let choices: [String]           // 4지선다 한국어 뜻 보기
    public let correctIndex: Int

    public init(id: String = UUID().uuidString, index: Int, word: Word, choices: [String], correctIndex: Int) {
        self.id = id
        self.index = index
        self.word = word
        self.choices = choices
        self.correctIndex = correctIndex
    }
}

public struct DiagnosticAnswerRecord: Equatable, Sendable {
    public let questionId: String
    public let wordId: String
    public let selectedIndex: Int
    public let isCorrect: Bool
    public let reactionSeconds: Double

    public init(
        questionId: String,
        wordId: String,
        selectedIndex: Int,
        isCorrect: Bool,
        reactionSeconds: Double
    ) {
        self.questionId = questionId
        self.wordId = wordId
        self.selectedIndex = selectedIndex
        self.isCorrect = isCorrect
        self.reactionSeconds = max(0.1, reactionSeconds)
    }
}

// MARK: - 시험일 D-Day & 동적 학습 속도 기반 완주 가능성 판정
public enum ExamCompletionFeasibility: String, Codable, Equatable, Sendable {
    case comfortable = "여유롭게 완주 가능"
    case achievable = "집중 학습 시 완주 가능"
    case tight = "도전적 일정 · 학습 시간 확대 권장"

    public var summaryBadge: String { rawValue }
}

// MARK: - 동적 일일 암기 계획 및 완주 예측 리포트
public struct StudyPlanProjection: Equatable, Sendable {
    public let targetLevel: JLPTLevel
    public let examDate: Date
    public let remainingDays: Int                   // 시험까지 남은 일수 (최소 1일)
    public let totalLevelWords: Int                 // 해당 급수 총 어휘 수 (예: N2 2,300단어)
    public let estimatedKnownWordsFromTest: Int     // 10장 진단 기반으로 추정한 이미 아는 어휘 수
    public let graduatedWordsInApp: Int             // 앱에서 실제로 졸업한 어휘 수
    public let remainingWordsToLearn: Int           // 앞으로 새로 외워야 할 남은 어휘 수
    public let requiredDailyNewWords: Int           // 시험일까지 완주하려면 하루에 외워야 하는 목표 단어 수
    public let estimatedDailyPaceCapacity: Int      // 진단 점수 + 실제 학습 정답률/속도로 예측한 사용자의 일일 소화 가능 단어 수
    public let blendedRetentionAccuracy: Double     // 진단 테스트 + 실제 학습 블렌딩 정답률 (0.0 ~ 1.0)
    public let isUsingLiveLearningTrend: Bool       // 실제 카드 학습 데이터가 반영되어 동향이 갱신되었는지 여부
    public let expectedDaysAtCurrentPace: Int       // 현재 학습 속도로 완주 시 걸리는 예상 일수
    public let feasibility: ExamCompletionFeasibility
    public let statusHeadline: String
    public let statusDetail: String
}

// MARK: - 진단 테스트 생성 & 동적 학습 계획 산출기
public enum StudyPlanCalculator {
    /// 선택한 급수(`level`)를 우선으로 10장의 4지선다 진단 테스트 문항을 생성합니다.
    public static func makeDiagnosticQuestions(
        for level: JLPTLevel,
        catalog: CatalogRepository = .shared,
        count: Int = 10
    ) -> [DiagnosticQuestion] {
        let targetCount = max(1, count)
        let exactMatches = catalog.words(for: level)
        let otherWords = catalog.words.filter { $0.jlptLevel != level }.sorted { lhs, rhs in
            abs(lhs.jlptLevel.standardLevelWordCount - level.standardLevelWordCount)
                < abs(rhs.jlptLevel.standardLevelWordCount - level.standardLevelWordCount)
        }

        var selectedWords: [Word] = []
        for word in exactMatches + otherWords {
            if selectedWords.count >= targetCount { break }
            if !selectedWords.contains(where: { $0.id == word.id }) {
                selectedWords.append(word)
            }
        }

        let allMeanings = catalog.words.map(\.meaning)
        return selectedWords.enumerated().map { offset, word in
            let correctMeaning = word.meaning
            let distractors = allMeanings
                .filter { $0 != correctMeaning }
                .enumerated()
                .sorted { lhs, rhs in
                    let lHash = abs((lhs.element.hashValue ^ (offset * 31)))
                    let rHash = abs((rhs.element.hashValue ^ (offset * 31)))
                    return lHash < rHash
                }
                .prefix(3)
                .map(\.element)

            var options = Array(distractors)
            let correctSlot = offset % 4
            let safeIndex = min(correctSlot, options.count)
            options.insert(correctMeaning, at: safeIndex)

            return DiagnosticQuestion(
                id: "diag_\(offset + 1)_\(word.id)",
                index: offset + 1,
                word: word,
                choices: options,
                correctIndex: safeIndex
            )
        }
    }

    /// 10문항 진단 결과 + 이후 실제 학습 기록(`snapshots`, `reviewLogs`)을 결합하여
    /// 남은 시험일자 대비 일일 암기 목표와 완주 가능성(동향 변화 포함)을 실시간 계산합니다.
    public static func evaluatePlan(
        profile: UserStudyProfile,
        snapshots: [String: WordMemorySnapshot],
        reviewLogs: [ReviewLogEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StudyPlanProjection {
        let startOfNow = calendar.startOfDay(for: now)
        let startOfExam = calendar.startOfDay(for: profile.examDate)
        let rawDays = calendar.dateComponents([.day], from: startOfNow, to: startOfExam).day ?? 30
        let remainingDays = max(1, rawDays)

        let totalWords = profile.targetLevel.standardLevelWordCount

        // 1) 10장 진단 정답률에 따른 초기 기저 어휘량 추정 (최대 55%까지 기저 지식으로 인정)
        let diagAccuracy = profile.diagnosticAccuracy
        let estimatedKnownRatio = min(diagAccuracy * 0.55, 0.55)
        let estimatedKnownCount = Int((Double(totalWords) * estimatedKnownRatio).rounded())

        // 2) 앱 내에서 실제로 졸업한 단어 수 집계
        let graduatedCount = snapshots.values.filter { $0.reps > 0 }.count

        // 3) 앞으로 외워야 할 남은 단어 수 산출
        let remainingWords = max(0, totalWords - estimatedKnownCount - graduatedCount)
        let requiredDaily = remainingWords == 0
            ? 0
            : max(1, Int(ceil(Double(remainingWords) / Double(remainingDays))))

        // 4) 초기 진단 속도 점수 + 추후 실제 학습 정답률/반응속도 동향 블렌딩
        //    초기 10개를 다 몰랐더라도 이후 학습 정답률이 높으면 소화 가능 속도가 상승합니다!
        let diagSpeedFactor = profile.diagnosticAverageSeconds <= 3.5 ? 1.15 : (profile.diagnosticAverageSeconds <= 6.5 ? 1.0 : 0.88)
        let initialPace = Double(15 + Int((diagAccuracy * 30.0).rounded())) * diagSpeedFactor

        let recentLogs = Array(reviewLogs.suffix(40))
        let hasLiveTrend = recentLogs.count >= 3
        let blendedAccuracy: Double
        let estimatedDailyCapacity: Int

        if hasLiveTrend {
            let liveSuccessCount = recentLogs.filter { $0.grade.isGraduating }.count
            let liveAccuracy = Double(liveSuccessCount) / Double(recentLogs.count)
            let avgLiveSeconds = recentLogs.reduce(0.0) { $0 + $1.reactionSeconds } / Double(recentLogs.count)
            let liveSpeedBonus = avgLiveSeconds <= 3.5 ? 1.18 : (avgLiveSeconds <= 6.0 ? 1.05 : 0.92)
            let livePace = Double(16 + Int((liveAccuracy * 34.0).rounded())) * liveSpeedBonus

            // 학습 기록이 쌓일수록 초기 10문항 진단보다 실제 학습 동향 가중치를 최대 75%까지 확대
            let liveWeight = min(Double(recentLogs.count) / 20.0, 0.75)
            let combinedPace = initialPace * (1.0 - liveWeight) + livePace * liveWeight
            estimatedDailyCapacity = max(10, Int(combinedPace.rounded()))
            blendedAccuracy = diagAccuracy * (1.0 - liveWeight) + liveAccuracy * liveWeight
        } else {
            estimatedDailyCapacity = max(10, Int(initialPace.rounded()))
            blendedAccuracy = diagAccuracy
        }

        let expectedDaysAtCurrentPace = remainingWords == 0
            ? 0
            : max(1, Int(ceil(Double(remainingWords) / Double(max(1, estimatedDailyCapacity)))))

        // 5) 남은 시험일 내 완주 가능 여부 판정
        let feasibility: ExamCompletionFeasibility
        let headline: String
        let detail: String

        if remainingWords == 0 {
            feasibility = .comfortable
            headline = "\(profile.targetLevel.rawValue) 목표 어휘를 모두 마스터했습니다!"
            detail = "시험일까지 복습 큐를 가볍게 유지하며 기억 인출률 90%를 지켜보세요."
        } else if requiredDaily <= estimatedDailyCapacity {
            feasibility = .comfortable
            headline = "현재 속도라면 시험일 전까지 충분히 전부 암기할 수 있어요!"
            detail = hasLiveTrend
                ? "최근 학습 정답률(\(Int((blendedAccuracy * 100).rounded()))%)이 반영되어 하루 \(estimatedDailyCapacity)단어 속도로 순항 중입니다. 하루 \(requiredDaily)단어씩만 외우면 \(expectedDaysAtCurrentPace)일 만에 완주합니다."
                : "10문항 진단 결과(\(profile.diagnosticCorrectCount)/\(profile.diagnosticTestedCount) 정답) 기준 하루 \(estimatedDailyCapacity)단어 소화가 가능해, 일일 목표 \(requiredDaily)단어를 여유 있게 달성할 수 있습니다."
        } else if Double(requiredDaily) <= Double(estimatedDailyCapacity) * 1.35 {
            feasibility = .achievable
            headline = "조금만 페이스를 높이면 시험일까지 완주할 수 있어요"
            detail = "남은 \(remainingDays)일 동안 하루 \(requiredDaily)단어 암기가 필요합니다 (현재 예상 소화량 일 \(estimatedDailyCapacity)단어). 향후 학습 정답률이 올라가면 예상 완주 속도도 함께 빨라집니다."
        } else {
            feasibility = .tight
            headline = "현재 속도로는 시험일까지 전체 암기가 다소 빠듯해요"
            detail = "남은 \(remainingDays)일 안에 \(remainingWords)단어를 끝내려면 하루 \(requiredDaily)단어가 필요하지만, 현재 예상 속도는 일 \(estimatedDailyCapacity)단어(완주 예상 \(expectedDaysAtCurrentPace)일)입니다. 다만 앞으로 학습 정답률이 좋아지면 예상 진도 속도가 자동으로 상향 조정됩니다!"
        }

        return StudyPlanProjection(
            targetLevel: profile.targetLevel,
            examDate: profile.examDate,
            remainingDays: remainingDays,
            totalLevelWords: totalWords,
            estimatedKnownWordsFromTest: estimatedKnownCount,
            graduatedWordsInApp: graduatedCount,
            remainingWordsToLearn: remainingWords,
            requiredDailyNewWords: requiredDaily,
            estimatedDailyPaceCapacity: estimatedDailyCapacity,
            blendedRetentionAccuracy: blendedAccuracy,
            isUsingLiveLearningTrend: hasLiveTrend,
            expectedDaysAtCurrentPace: expectedDaysAtCurrentPace,
            feasibility: feasibility,
            statusHeadline: headline,
            statusDetail: detail
        )
    }
}
