import Foundation
import Observation
import SwiftUI

// MARK: - 세션 순환 큐 운영 설정 (SPEC.md §1.2, §3.1, §3.2)
public struct SessionConfiguration: Codable, Equatable, Sendable {
    public let maxDailyEncounters: Int            // 당일 최대 조우 한도 (기본 8회)
    public let leechDistinctDayThreshold: Int     // 손글씨 처방 노트 분류 기준 일수 (기본 3일)
    public let graduationsPerGameTicket: Int      // 탭 2 SMS 게임 티켓 발급 기준 졸업 단어 수 (기본 5개)
    public let newCardLimit: Int                  // 세션당 신규 단어 최대 편성 수
    public let againReinsertOffset: Int           // '1. 어려움' 재투입 간격 (앞쪽 빠른 복습)
    public let hardReinsertOffset: Int            // '3. 애매함' 재투입 간격 (중간 거리 재확인)
    public let requireConfirmationAfterErosion: Bool // 당일 침식된 단어 첫 정답 시 최종 확인 1회 요구 여부
    public let excludePrescribedLeeches: Bool     // 손글씨 처방 노트 대상 단어 일반 큐 제외 여부

    public init(
        maxDailyEncounters: Int = 8,
        leechDistinctDayThreshold: Int = 3,
        graduationsPerGameTicket: Int = 5,
        newCardLimit: Int = 20,
        againReinsertOffset: Int = 2,
        hardReinsertOffset: Int = 4,
        requireConfirmationAfterErosion: Bool = true,
        excludePrescribedLeeches: Bool = true
    ) {
        self.maxDailyEncounters = max(1, maxDailyEncounters)
        self.leechDistinctDayThreshold = max(1, leechDistinctDayThreshold)
        self.graduationsPerGameTicket = max(1, graduationsPerGameTicket)
        self.newCardLimit = max(0, newCardLimit)
        self.againReinsertOffset = max(1, againReinsertOffset)
        self.hardReinsertOffset = max(1, hardReinsertOffset)
        self.requireConfirmationAfterErosion = requireConfirmationAfterErosion
        self.excludePrescribedLeeches = excludePrescribedLeeches
    }

    public static let standard = SessionConfiguration()
}

// MARK: - 순환 큐 개별 카드 아이템 상태
public struct SessionQueueItem: Identifiable, Equatable, Sendable {
    public let word: Word
    public var snapshot: WordMemorySnapshot

    public var id: String { word.id }

    public init(word: Word, snapshot: WordMemorySnapshot) {
        self.word = word
        self.snapshot = snapshot
    }

    public var isReviewCard: Bool {
        snapshot.reps > 0
    }

    public var todayEncounterCount: Int {
        snapshot.todayEncounterCount
    }

    public var todayErosionCount: Int {
        snapshot.todayErosionCount
    }

    public var isAwaitingFinalConfirmation: Bool {
        snapshot.awaitingFinalConfirmation
    }

    /// 현재 회차(`reps`)에서 앞면 문제로 출제할 의미 (초회는 뜻 1, 복습은 뜻 2~4 라운드로빈 순환)
    public var presentedSense: WordSense {
        word.activeSense(forReps: snapshot.reps)
    }

    /// 정답 공개 시 하단에 추가로 펼쳐 보여줄 보조 의미 목록
    public var supplementarySenses: [WordSense] {
        word.supplementarySenses(excluding: presentedSense.id)
    }

    /// 현재 실패 누적에 따른 침식 진행도 (0.0 = 고유 퍼스널 컬러, 1.0 = 칠흑+딥크림슨 완전 침식)
    public func erosionProgress(maxDailyEncounters: Int = 8) -> Double {
        ThemePalette.erosionProgress(
            forFailureCount: snapshot.todayErosionCount,
            maxFailuresBeforeCap: max(1, maxDailyEncounters - 1)
        )
    }

    /// 출제 의미의 퍼스널 팔레트와 침식도를 반영한 실시간 카드 배경 3색 배열
    public func activeColors(maxDailyEncounters: Int = 8) -> [Color] {
        word.colors(
            for: presentedSense,
            sessionFailures: snapshot.todayErosionCount,
            maxFailuresBeforeCap: max(1, maxDailyEncounters - 1)
        )
    }
}

// MARK: - 단일 카드 평가 처리 결과
public struct SessionEvaluationOutcome: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        /// 미졸업(`1~3등급`): 순환 큐 내 지정 위치로 재투입
        case requeued(insertionIndex: Int, todayEncounters: Int, erosionCount: Int)
        /// 침식 이력 단어 1차 인출 통과: 컬러 정화 즉시 적용 + 세션 말미 최종 확인 1회 대기
        case confirmationQueued(insertionIndex: Int, todayEncounters: Int, didPurifyColor: Bool)
        /// 최종 졸업(`4~6등급`): 큐에서 제거 + FSRS 주기 산출 + 조건 충족 시 게임 티켓 획득
        case graduated(
            schedule: FSRSScheduleResult,
            didPurifyColor: Bool,
            isComeback: Bool,
            earnedTicket: GameTicket?
        )
        /// 당일 8회 조우 캡 도달: 수면 공고화를 위해 내일로 이관 (누적 3일 시 손글씨 처방 노트 분류)
        case deferredByDailyCap(
            distinctDeferredDays: Int,
            prescribedToHandwritingNote: Bool
        )
    }

    public let wordId: String
    public let button: ReviewButton
    public let grade: EvaluationGrade
    public let reactionSeconds: Double
    public let status: Status
}

// MARK: - 순환 학습 세션 엔진 & ContinuousClock 반응 타이머 (SPEC.md §2.3, §3.1, §3.2)
@Observable
public final class StudySessionEngine {
    public let catalog: CatalogRepository
    public let store: MemoryStoreProtocol
    public let fsrs: FSRSEngine
    public let configuration: SessionConfiguration
    public var calendar: Calendar

    // 실시간 세션 상태
    public private(set) var queue: [SessionQueueItem] = []
    public private(set) var initialCardCount: Int = 0
    public private(set) var graduatedWordIds: [String] = []
    public private(set) var deferredTodayWordIds: [String] = []
    public private(set) var earnedTicketsInSession: [GameTicket] = []
    public private(set) var lastOutcome: SessionEvaluationOutcome?
    public private(set) var stateRevision: Int = 0

    // ContinuousClock 기반 반응 시간 측정 상태 (카드 등장 ~ '정답 보기' 클릭)
    private let clock = ContinuousClock()
    private var activeSegmentStartedAt: ContinuousClock.Instant?
    private var accumulatedDuration: Duration = .zero
    public private(set) var lockedRevealSeconds: Double?
    public private(set) var isTimerPaused: Bool = false

    // SMS 게임 티켓 발급을 위한 졸업 단어 배치 버퍼
    private var pendingTicketWords: [Word] = []

    public init(
        catalog: CatalogRepository = .shared,
        store: MemoryStoreProtocol,
        fsrs: FSRSEngine = FSRSEngine(),
        configuration: SessionConfiguration = .standard,
        calendar: Calendar = .current
    ) {
        self.catalog = catalog
        self.store = store
        self.fsrs = fsrs
        self.configuration = configuration
        self.calendar = calendar
    }

    // MARK: - 현재 세션 조회 프로퍼티

    public var currentItem: SessionQueueItem? {
        queue.first
    }

    public var currentWord: Word? {
        queue.first?.word
    }

    public var isSessionCompleted: Bool {
        queue.isEmpty && initialCardCount > 0
    }

    /// 전체 세션 진행률 (졸업 + 수면 보류 종결 비율, 0.0 ~ 1.0)
    public var completionProgress: Double {
        guard initialCardCount > 0 else { return 0.0 }
        let resolved = initialCardCount - queue.count
        return min(max(Double(resolved) / Double(initialCardCount), 0.0), 1.0)
    }

    // MARK: - 1) 세션 시작 및 순환 큐 편성

    public func startSession(
        words sourceWords: [Word]? = nil,
        level: JLPTLevel? = nil,
        now: Date = Date()
    ) {
        let todayKey = DayKeyFormatter.dayKey(for: now, calendar: calendar)
        let pool: [Word]
        if let sourceWords {
            pool = sourceWords
        } else if let level {
            pool = catalog.words(for: level)
        } else {
            pool = catalog.words
        }

        let storedMap = store.allSnapshots()
        var deferredCarryover: [SessionQueueItem] = []
        var dueReviews: [(item: SessionQueueItem, retrievability: Double)] = []
        var newCandidates: [SessionQueueItem] = []

        for word in pool {
            let rawSnapshot = storedMap[word.id] ?? WordMemorySnapshot(wordId: word.id)
            let normalized = rawSnapshot.normalized(forDayKey: todayKey)

            if normalized != rawSnapshot {
                store.saveSnapshot(normalized)
            }

            if configuration.excludePrescribedLeeches && normalized.isLeechPrescribed {
                continue
            }

            if normalized.todayEncounterCount >= configuration.maxDailyEncounters {
                continue
            }

            if normalized.reps > 0 {
                if normalized.dueAt <= now {
                    let r = normalized.memoryState.map {
                        fsrs.currentRetrievability(for: $0, now: now)
                    } ?? 0.0
                    dueReviews.append((SessionQueueItem(word: word, snapshot: normalized), r))
                }
            } else if !normalized.deferredDayKeys.isEmpty {
                if normalized.dueAt <= now {
                    deferredCarryover.append(SessionQueueItem(word: word, snapshot: normalized))
                }
            } else {
                newCandidates.append(SessionQueueItem(word: word, snapshot: normalized))
            }
        }

        dueReviews.sort { lhs, rhs in
            if abs(lhs.retrievability - rhs.retrievability) > 0.0001 {
                return lhs.retrievability < rhs.retrievability
            }
            return lhs.item.snapshot.dueAt < rhs.item.snapshot.dueAt
        }

        let selectedNew = Array(newCandidates.prefix(configuration.newCardLimit))
        self.queue = deferredCarryover + dueReviews.map(\.item) + selectedNew
        self.initialCardCount = queue.count
        self.graduatedWordIds = []
        self.deferredTodayWordIds = []
        self.earnedTicketsInSession = []
        self.pendingTicketWords = []
        self.lastOutcome = nil
        self.stateRevision += 1

        if !queue.isEmpty {
            beginCardPresentation()
        } else {
            resetReactionTimer()
        }
    }

    // MARK: - 2) ContinuousClock 반응 타이머 제어

    public func beginCardPresentation() {
        accumulatedDuration = .zero
        lockedRevealSeconds = nil
        isTimerPaused = false
        activeSegmentStartedAt = clock.now
    }

    public func pauseReactionTimer() {
        guard !isTimerPaused, lockedRevealSeconds == nil else { return }
        if let started = activeSegmentStartedAt {
            accumulatedDuration += started.duration(to: clock.now)
        }
        activeSegmentStartedAt = nil
        isTimerPaused = true
    }

    public func resumeReactionTimer() {
        guard isTimerPaused, lockedRevealSeconds == nil else { return }
        activeSegmentStartedAt = clock.now
        isTimerPaused = false
    }

    @discardableResult
    public func markAnswerRevealed() -> Double {
        if let locked = lockedRevealSeconds {
            return locked
        }
        let elapsed = currentElapsedSeconds()
        lockedRevealSeconds = elapsed
        activeSegmentStartedAt = nil
        isTimerPaused = false
        return elapsed
    }

    public func currentElapsedSeconds() -> Double {
        if let locked = lockedRevealSeconds {
            return locked
        }
        var total = accumulatedDuration
        if !isTimerPaused, let started = activeSegmentStartedAt {
            total += started.duration(to: clock.now)
        }
        let comps = total.components
        let seconds = Double(comps.seconds) + Double(comps.attoseconds) / 1e18
        return max(0.0, seconds)
    }

    private func resetReactionTimer() {
        activeSegmentStartedAt = nil
        accumulatedDuration = .zero
        lockedRevealSeconds = nil
        isTimerPaused = false
    }

    // MARK: - 3) 사용자 4버튼 평가 제출 → 6등급 판정 · 최종 확인 · 순환 큐 · 8회 캡 · 티켓 처리

    @discardableResult
    public func submitEvaluation(
        button: ReviewButton,
        overrideElapsedSeconds: Double? = nil,
        now: Date = Date()
    ) -> SessionEvaluationOutcome? {
        guard !queue.isEmpty else { return nil }

        var activeItem = queue.removeFirst()
        let todayKey = DayKeyFormatter.dayKey(for: now, calendar: calendar)
        var snapshot = activeItem.snapshot.normalized(forDayKey: todayKey)
        let quizzedSense = activeItem.presentedSense

        let measuredSeconds = overrideElapsedSeconds ?? markAnswerRevealed()
        let grade = fsrs.classifyGrade(button: button, elapsedSeconds: measuredSeconds)

        let priorEncountersToday = snapshot.todayEncounterCount
        let priorErosionCount = snapshot.todayErosionCount
        let priorStability = snapshot.stability
        let priorDifficulty = snapshot.difficulty
        let elapsedDaysSinceLast: Double? = snapshot.lastReviewedAt.map {
            max(0.0, now.timeIntervalSince($0) / 86_400.0)
        }

        snapshot.todayEncounterCount = priorEncountersToday + 1

        if snapshot.reps > 0 && priorEncountersToday == 0 && !grade.isGraduating {
            snapshot.hadInterDayLapseToday = true
        }

        let outcome: SessionEvaluationOutcome

        if grade.isGraduating {
            let needsConfirmationLap = configuration.requireConfirmationAfterErosion
                && priorErosionCount > 0
                && !snapshot.awaitingFinalConfirmation
                && snapshot.todayEncounterCount < configuration.maxDailyEncounters

            if needsConfirmationLap {
                // [침식 단어 1차 인출 성공] 컬러 침식은 즉시 정화하되, 세션 말미에 최종 확인 1회 배치
                snapshot.todayErosionCount = 0
                snapshot.awaitingFinalConfirmation = true

                store.saveSnapshot(snapshot)
                store.appendReviewLog(
                    ReviewLogEntry(
                        wordId: activeItem.word.id,
                        reviewedAt: now,
                        button: button,
                        grade: grade,
                        reactionSeconds: measuredSeconds,
                        encounterIndexToday: snapshot.todayEncounterCount,
                        priorStability: priorStability,
                        priorDifficulty: priorDifficulty,
                        elapsedDaysSinceLastReview: elapsedDaysSinceLast,
                        presentedSenseNumber: quizzedSense.senseNumber,
                        didGraduate: false,
                        didHitDailyCap: false
                    )
                )

                activeItem.snapshot = snapshot
                let tailIndex = queue.count
                queue.insert(activeItem, at: tailIndex)

                outcome = SessionEvaluationOutcome(
                    wordId: activeItem.word.id,
                    button: button,
                    grade: grade,
                    reactionSeconds: measuredSeconds,
                    status: .confirmationQueued(
                        insertionIndex: tailIndex,
                        todayEncounters: snapshot.todayEncounterCount,
                        didPurifyColor: true
                    )
                )
            } else {
                // [최종 졸업] 첫 시도에 바로 맞혔거나, 최종 확인(Confirmation Lap)까지 연속 통과!
                let schedule = fsrs.evaluateGraduation(
                    previousState: snapshot.memoryState,
                    grade: grade,
                    hadInterDayLapseToday: snapshot.hadInterDayLapseToday,
                    intraSessionFailureCount: snapshot.todayNonGraduatingCount,
                    now: now,
                    calendar: calendar
                )

                let didPurifyColor = priorErosionCount > 0
                let isComeback = snapshot.todayNonGraduatingCount >= 2
                    || snapshot.awaitingFinalConfirmation
                    || !snapshot.deferredDayKeys.isEmpty

                snapshot.stability = schedule.updatedState.stability
                snapshot.difficulty = schedule.updatedState.difficulty
                snapshot.reps = schedule.updatedState.reps
                snapshot.lapses = schedule.updatedState.lapses
                snapshot.lastReviewedAt = schedule.updatedState.lastReviewedAt
                snapshot.dueAt = schedule.updatedState.dueAt
                snapshot.todayErosionCount = 0
                snapshot.awaitingFinalConfirmation = false
                snapshot.hadInterDayLapseToday = false
                if isComeback {
                    snapshot.comebackCount += 1
                }

                store.saveSnapshot(snapshot)
                store.appendReviewLog(
                    ReviewLogEntry(
                        wordId: activeItem.word.id,
                        reviewedAt: now,
                        button: button,
                        grade: grade,
                        reactionSeconds: measuredSeconds,
                        encounterIndexToday: snapshot.todayEncounterCount,
                        priorStability: priorStability,
                        priorDifficulty: priorDifficulty,
                        elapsedDaysSinceLastReview: elapsedDaysSinceLast,
                        presentedSenseNumber: quizzedSense.senseNumber,
                        didGraduate: true,
                        didHitDailyCap: false
                    )
                )

                graduatedWordIds.append(activeItem.word.id)
                let earnedTicket = processGameTicketReward(forGraduatedWord: activeItem.word, now: now)

                outcome = SessionEvaluationOutcome(
                    wordId: activeItem.word.id,
                    button: button,
                    grade: grade,
                    reactionSeconds: measuredSeconds,
                    status: .graduated(
                        schedule: schedule,
                        didPurifyColor: didPurifyColor,
                        isComeback: isComeback,
                        earnedTicket: earnedTicket
                    )
                )
            }
        } else if snapshot.todayEncounterCount >= configuration.maxDailyEncounters {
            // [당일 8회 조우 캡 도달] 수면 후 기억 공고화를 위해 당일 종료 & 내일로 이관
            snapshot.todayNonGraduatingCount += 1
            snapshot.awaitingFinalConfirmation = false
            if grade.incrementsErosion {
                snapshot.todayErosionCount = priorErosionCount + 1
            }

            if !snapshot.deferredDayKeys.contains(todayKey) {
                snapshot.deferredDayKeys.append(todayKey)
                snapshot.deferredDayKeys.sort()
            }
            snapshot.dueAt = DayKeyFormatter.startOfNextDay(after: now, calendar: calendar, days: 1)

            if snapshot.distinctDeferredDayCount >= configuration.leechDistinctDayThreshold {
                snapshot.isLeechPrescribed = true
            }

            store.saveSnapshot(snapshot)
            store.appendReviewLog(
                ReviewLogEntry(
                    wordId: activeItem.word.id,
                    reviewedAt: now,
                    button: button,
                    grade: grade,
                    reactionSeconds: measuredSeconds,
                    encounterIndexToday: snapshot.todayEncounterCount,
                    priorStability: priorStability,
                    priorDifficulty: priorDifficulty,
                    elapsedDaysSinceLastReview: elapsedDaysSinceLast,
                    presentedSenseNumber: quizzedSense.senseNumber,
                    didGraduate: false,
                    didHitDailyCap: true
                )
            )

            deferredTodayWordIds.append(activeItem.word.id)
            outcome = SessionEvaluationOutcome(
                wordId: activeItem.word.id,
                button: button,
                grade: grade,
                reactionSeconds: measuredSeconds,
                status: .deferredByDailyCap(
                    distinctDeferredDays: snapshot.distinctDeferredDayCount,
                    prescribedToHandwritingNote: snapshot.isLeechPrescribed
                )
            )
        } else {
            // [순환 큐 재투입] 미졸업 & 8회 캡 미만
            snapshot.todayNonGraduatingCount += 1
            snapshot.awaitingFinalConfirmation = false
            if grade.incrementsErosion {
                snapshot.todayErosionCount = priorErosionCount + 1
            }

            store.saveSnapshot(snapshot)
            store.appendReviewLog(
                ReviewLogEntry(
                    wordId: activeItem.word.id,
                    reviewedAt: now,
                    button: button,
                    grade: grade,
                    reactionSeconds: measuredSeconds,
                    encounterIndexToday: snapshot.todayEncounterCount,
                    priorStability: priorStability,
                    priorDifficulty: priorDifficulty,
                    elapsedDaysSinceLastReview: elapsedDaysSinceLast,
                    presentedSenseNumber: quizzedSense.senseNumber,
                    didGraduate: false,
                    didHitDailyCap: false
                )
            )

            activeItem.snapshot = snapshot
            let insertionIndex = computeReinsertionIndex(for: grade, remainingQueueCount: queue.count)
            queue.insert(activeItem, at: insertionIndex)

            outcome = SessionEvaluationOutcome(
                wordId: activeItem.word.id,
                button: button,
                grade: grade,
                reactionSeconds: measuredSeconds,
                status: .requeued(
                    insertionIndex: insertionIndex,
                    todayEncounters: snapshot.todayEncounterCount,
                    erosionCount: snapshot.todayErosionCount
                )
            )
        }

        lastOutcome = outcome
        stateRevision += 1

        if !queue.isEmpty {
            beginCardPresentation()
        } else {
            resetReactionTimer()
        }

        return outcome
    }

    // MARK: - 4) 탭 2 SMS 게임 티켓 & 탭 3 오프라인 손글씨 처방 노트 연동 API

    public func prescribedLeechWords() -> [Word] {
        _ = stateRevision
        let snapshots = store.allSnapshots()
        return catalog.words.filter { snapshots[$0.id]?.isLeechPrescribed == true }
    }

    @discardableResult
    public func completeHandwritingPrescription(
        for wordId: String,
        now: Date = Date()
    ) -> WordMemorySnapshot? {
        guard var snapshot = store.snapshot(for: wordId) else { return nil }
        let todayKey = DayKeyFormatter.dayKey(for: now, calendar: calendar)
        snapshot = snapshot.normalized(forDayKey: todayKey)
        snapshot.isLeechPrescribed = false
        snapshot.deferredDayKeys = []
        snapshot.todayEncounterCount = 0
        snapshot.todayNonGraduatingCount = 0
        snapshot.todayErosionCount = 0
        snapshot.awaitingFinalConfirmation = false
        snapshot.dueAt = now
        snapshot.handwritingCompletedCount += 1
        store.saveSnapshot(snapshot)
        stateRevision += 1
        return snapshot
    }

    /// 테스트 및 시연용: 특정 단어를 3일 누적 보류(손글씨 처방 노트 대상) 상태로 즉시 지정합니다.
    @discardableResult
    public func simulateLeechPrescription(
        for wordId: String,
        now: Date = Date()
    ) -> WordMemorySnapshot {
        let todayKey = DayKeyFormatter.dayKey(for: now, calendar: calendar)
        var snapshot = store.snapshot(for: wordId) ?? WordMemorySnapshot(wordId: wordId)
        snapshot = snapshot.normalized(forDayKey: todayKey)
        snapshot.deferredDayKeys = ["2026-10-29", "2026-10-30", todayKey]
        snapshot.isLeechPrescribed = true
        snapshot.dueAt = DayKeyFormatter.startOfNextDay(after: now, calendar: calendar, days: 1)
        store.saveSnapshot(snapshot)
        if configuration.excludePrescribedLeeches {
            queue.removeAll { $0.word.id == wordId }
        }
        stateRevision += 1
        return snapshot
    }

    public func unconsumedGameTickets() -> [GameTicket] {
        _ = stateRevision
        return store.allGameTickets().filter { !$0.isConsumed }
    }

    public var userProfile: UserStudyProfile? {
        _ = stateRevision
        return store.currentUserProfile()
    }

    public func saveUserProfile(_ profile: UserStudyProfile) {
        store.saveUserProfile(profile)
        stateRevision += 1
    }

    public func clearUserProfile() {
        store.clearUserProfile()
        stateRevision += 1
    }

    public func currentStudyPlanProjection(now: Date = Date()) -> StudyPlanProjection? {
        _ = stateRevision
        guard let profile = store.currentUserProfile() else { return nil }
        return StudyPlanCalculator.evaluatePlan(
            profile: profile,
            snapshots: store.allSnapshots(),
            reviewLogs: store.allReviewLogs(),
            now: now,
            calendar: calendar
        )
    }

    @discardableResult
    public func consumeGameTicket(id: String) -> GameTicket? {
        guard var ticket = store.allGameTickets().first(where: { $0.id == id }) else {
            return nil
        }
        ticket.isConsumed = true
        store.saveGameTicket(ticket)
        stateRevision += 1
        return ticket
    }

    // MARK: - 내부 보조 계산

    private func computeReinsertionIndex(for grade: EvaluationGrade, remainingQueueCount: Int) -> Int {
        guard remainingQueueCount > 0 else { return 0 }
        switch grade {
        case .again:
            return min(configuration.againReinsertOffset, remainingQueueCount)
        case .hard:
            return min(configuration.hardReinsertOffset, remainingQueueCount)
        case .hiddenHintAssisted:
            return remainingQueueCount
        default:
            return remainingQueueCount
        }
    }

    private func processGameTicketReward(forGraduatedWord word: Word, now: Date) -> GameTicket? {
        pendingTicketWords.append(word)
        guard pendingTicketWords.count >= configuration.graduationsPerGameTicket else {
            return nil
        }

        let targetIds = pendingTicketWords.map(\.id)
        let ticket = GameTicket(
            voiceId: word.voice.id,
            targetWordIds: targetIds,
            earnedAt: now,
            isConsumed: false
        )
        pendingTicketWords.removeAll()
        store.saveGameTicket(ticket)
        earnedTicketsInSession.append(ticket)
        return ticket
    }
}
