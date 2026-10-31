import Foundation
import SwiftData

// MARK: - 단어 기억 상태 스냅샷 (값 타입, SwiftData 레코드와 1:1 매핑)
public struct WordMemorySnapshot: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let wordId: String
    public var stability: Double
    public var difficulty: Double
    public var reps: Int
    public var lapses: Int
    public var lastReviewedAt: Date?
    public var dueAt: Date

    // 당일 세션 조우·침식 추적 (날짜 변경 시 자동 초기화)
    public var lastEncounterDayKey: String?
    public var todayEncounterCount: Int
    public var todayErosionCount: Int
    public var hadInterDayLapseToday: Bool

    // 서로 다른 날 8회 캡 보류 이력 & 손글씨 처방 노트 상태 (SPEC.md §1.3, §3.2)
    public var deferredDayKeys: [String]
    public var isLeechPrescribed: Bool
    public var handwritingCompletedCount: Int
    public var comebackCount: Int

    public var id: String { wordId }

    public init(
        wordId: String,
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        reps: Int = 0,
        lapses: Int = 0,
        lastReviewedAt: Date? = nil,
        dueAt: Date = .distantPast,
        lastEncounterDayKey: String? = nil,
        todayEncounterCount: Int = 0,
        todayErosionCount: Int = 0,
        hadInterDayLapseToday: Bool = false,
        deferredDayKeys: [String] = [],
        isLeechPrescribed: Bool = false,
        handwritingCompletedCount: Int = 0,
        comebackCount: Int = 0
    ) {
        self.wordId = wordId
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
        self.dueAt = dueAt
        self.lastEncounterDayKey = lastEncounterDayKey
        self.todayEncounterCount = todayEncounterCount
        self.todayErosionCount = todayErosionCount
        self.hadInterDayLapseToday = hadInterDayLapseToday
        self.deferredDayKeys = Array(Set(deferredDayKeys)).sorted()
        self.isLeechPrescribed = isLeechPrescribed
        self.handwritingCompletedCount = handwritingCompletedCount
        self.comebackCount = comebackCount
    }

    public var memoryState: MemoryState? {
        guard reps > 0 else { return nil }
        return MemoryState(
            stability: stability,
            difficulty: difficulty,
            reps: reps,
            lapses: lapses,
            lastReviewedAt: lastReviewedAt,
            dueAt: dueAt
        )
    }

    /// 서로 다른 날 누적 보류 횟수
    public var distinctDeferredDayCount: Int {
        deferredDayKeys.count
    }

    /// 기준 날짜(`dayKey`)가 바뀌었으면 당일 조우·침식 카운터를 0으로 리셋한 복사본 반환
    public func normalized(forDayKey dayKey: String) -> WordMemorySnapshot {
        guard lastEncounterDayKey != dayKey else { return self }
        var copy = self
        copy.lastEncounterDayKey = dayKey
        copy.todayEncounterCount = 0
        copy.todayErosionCount = 0
        copy.hadInterDayLapseToday = false
        return copy
    }
}

// MARK: - 개별 평가 로그 스냅샷 (통계 · 반응시간 분석용)
public struct ReviewLogEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let wordId: String
    public let reviewedAt: Date
    public let button: ReviewButton
    public let grade: EvaluationGrade
    public let reactionSeconds: Double
    public let didGraduate: Bool
    public let didHitDailyCap: Bool

    public init(
        id: String = UUID().uuidString,
        wordId: String,
        reviewedAt: Date,
        button: ReviewButton,
        grade: EvaluationGrade,
        reactionSeconds: Double,
        didGraduate: Bool,
        didHitDailyCap: Bool
    ) {
        self.id = id
        self.wordId = wordId
        self.reviewedAt = reviewedAt
        self.button = button
        self.grade = grade
        self.reactionSeconds = reactionSeconds
        self.didGraduate = didGraduate
        self.didHitDailyCap = didHitDailyCap
    }
}

// MARK: - 탭 2 SMS 미션 게임 티켓 (졸업 보상 연결, SPEC.md §1.1, §1.2)
public struct GameTicket: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let voiceId: String             // 함께 대화할 상대 성우 캐릭터 ID
    public let targetWordIds: [String]     // 미션에 등장할 오늘 졸업 단어 ID 목록
    public let earnedAt: Date
    public var isConsumed: Bool

    public init(
        id: String = UUID().uuidString,
        voiceId: String,
        targetWordIds: [String],
        earnedAt: Date,
        isConsumed: Bool = false
    ) {
        self.id = id
        self.voiceId = voiceId
        self.targetWordIds = targetWordIds
        self.earnedAt = earnedAt
        self.isConsumed = isConsumed
    }
}

// MARK: - SwiftData 영구 저장 모델 (@Model)

@Model
public final class WordMemoryRecord {
    @Attribute(.unique) public var wordId: String
    public var stability: Double
    public var difficulty: Double
    public var reps: Int
    public var lapses: Int
    public var lastReviewedAt: Date?
    public var dueAt: Date

    public var lastEncounterDayKey: String?
    public var todayEncounterCount: Int
    public var todayErosionCount: Int
    public var hadInterDayLapseToday: Bool

    public var deferredDayKeysRaw: String
    public var isLeechPrescribed: Bool
    public var handwritingCompletedCount: Int
    public var comebackCount: Int

    public init(snapshot: WordMemorySnapshot) {
        self.wordId = snapshot.wordId
        self.stability = snapshot.stability
        self.difficulty = snapshot.difficulty
        self.reps = snapshot.reps
        self.lapses = snapshot.lapses
        self.lastReviewedAt = snapshot.lastReviewedAt
        self.dueAt = snapshot.dueAt
        self.lastEncounterDayKey = snapshot.lastEncounterDayKey
        self.todayEncounterCount = snapshot.todayEncounterCount
        self.todayErosionCount = snapshot.todayErosionCount
        self.hadInterDayLapseToday = snapshot.hadInterDayLapseToday
        self.deferredDayKeysRaw = snapshot.deferredDayKeys.joined(separator: ",")
        self.isLeechPrescribed = snapshot.isLeechPrescribed
        self.handwritingCompletedCount = snapshot.handwritingCompletedCount
        self.comebackCount = snapshot.comebackCount
    }

    public func apply(_ snapshot: WordMemorySnapshot) {
        self.stability = snapshot.stability
        self.difficulty = snapshot.difficulty
        self.reps = snapshot.reps
        self.lapses = snapshot.lapses
        self.lastReviewedAt = snapshot.lastReviewedAt
        self.dueAt = snapshot.dueAt
        self.lastEncounterDayKey = snapshot.lastEncounterDayKey
        self.todayEncounterCount = snapshot.todayEncounterCount
        self.todayErosionCount = snapshot.todayErosionCount
        self.hadInterDayLapseToday = snapshot.hadInterDayLapseToday
        self.deferredDayKeysRaw = snapshot.deferredDayKeys.joined(separator: ",")
        self.isLeechPrescribed = snapshot.isLeechPrescribed
        self.handwritingCompletedCount = snapshot.handwritingCompletedCount
        self.comebackCount = snapshot.comebackCount
    }

    public var snapshot: WordMemorySnapshot {
        let dayKeys = deferredDayKeysRaw
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }

        return WordMemorySnapshot(
            wordId: wordId,
            stability: stability,
            difficulty: difficulty,
            reps: reps,
            lapses: lapses,
            lastReviewedAt: lastReviewedAt,
            dueAt: dueAt,
            lastEncounterDayKey: lastEncounterDayKey,
            todayEncounterCount: todayEncounterCount,
            todayErosionCount: todayErosionCount,
            hadInterDayLapseToday: hadInterDayLapseToday,
            deferredDayKeys: dayKeys,
            isLeechPrescribed: isLeechPrescribed,
            handwritingCompletedCount: handwritingCompletedCount,
            comebackCount: comebackCount
        )
    }
}

@Model
public final class ReviewLogRecord {
    @Attribute(.unique) public var logId: String
    public var wordId: String
    public var reviewedAt: Date
    public var buttonRaw: String
    public var gradeRaw: Int
    public var reactionSeconds: Double
    public var didGraduate: Bool
    public var didHitDailyCap: Bool

    public init(entry: ReviewLogEntry) {
        self.logId = entry.id
        self.wordId = entry.wordId
        self.reviewedAt = entry.reviewedAt
        self.buttonRaw = entry.button.rawValue
        self.gradeRaw = entry.grade.rawValue
        self.reactionSeconds = entry.reactionSeconds
        self.didGraduate = entry.didGraduate
        self.didHitDailyCap = entry.didHitDailyCap
    }

    public var entry: ReviewLogEntry {
        ReviewLogEntry(
            id: logId,
            wordId: wordId,
            reviewedAt: reviewedAt,
            button: ReviewButton(rawValue: buttonRaw) ?? .good,
            grade: EvaluationGrade(rawValue: gradeRaw) ?? .good,
            reactionSeconds: reactionSeconds,
            didGraduate: didGraduate,
            didHitDailyCap: didHitDailyCap
        )
    }
}

@Model
public final class GameTicketRecord {
    @Attribute(.unique) public var ticketId: String
    public var voiceId: String
    public var targetWordIdsRaw: String
    public var earnedAt: Date
    public var isConsumed: Bool

    public init(ticket: GameTicket) {
        self.ticketId = ticket.id
        self.voiceId = ticket.voiceId
        self.targetWordIdsRaw = ticket.targetWordIds.joined(separator: ",")
        self.earnedAt = ticket.earnedAt
        self.isConsumed = ticket.isConsumed
    }

    public var ticket: GameTicket {
        let wordIds = targetWordIdsRaw
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
        return GameTicket(
            id: ticketId,
            voiceId: voiceId,
            targetWordIds: wordIds,
            earnedAt: earnedAt,
            isConsumed: isConsumed
        )
    }
}

// MARK: - 기억 저장소 추상 프로토콜 (SwiftData / InMemory 교체 가능)
public protocol MemoryStoreProtocol: AnyObject {
    func snapshot(for wordId: String) -> WordMemorySnapshot?
    func allSnapshots() -> [String: WordMemorySnapshot]
    func saveSnapshot(_ snapshot: WordMemorySnapshot)
    func appendReviewLog(_ log: ReviewLogEntry)
    func allReviewLogs() -> [ReviewLogEntry]
    func saveGameTicket(_ ticket: GameTicket)
    func allGameTickets() -> [GameTicket]
}

// MARK: - 인메모리 저장소 (프리뷰 · 고속 유닛 테스트용)
public final class InMemoryMemoryStore: MemoryStoreProtocol {
    private var snapshotsById: [String: WordMemorySnapshot]
    private var logs: [ReviewLogEntry]
    private var ticketsById: [String: GameTicket]

    public init(
        initialSnapshots: [WordMemorySnapshot] = [],
        initialLogs: [ReviewLogEntry] = [],
        initialTickets: [GameTicket] = []
    ) {
        var map: [String: WordMemorySnapshot] = [:]
        for item in initialSnapshots {
            map[item.wordId] = item
        }
        self.snapshotsById = map
        self.logs = initialLogs
        var ticketMap: [String: GameTicket] = [:]
        for ticket in initialTickets {
            ticketMap[ticket.id] = ticket
        }
        self.ticketsById = ticketMap
    }

    public func snapshot(for wordId: String) -> WordMemorySnapshot? {
        snapshotsById[wordId]
    }

    public func allSnapshots() -> [String: WordMemorySnapshot] {
        snapshotsById
    }

    public func saveSnapshot(_ snapshot: WordMemorySnapshot) {
        snapshotsById[snapshot.wordId] = snapshot
    }

    public func appendReviewLog(_ log: ReviewLogEntry) {
        logs.append(log)
    }

    public func allReviewLogs() -> [ReviewLogEntry] {
        logs
    }

    public func saveGameTicket(_ ticket: GameTicket) {
        ticketsById[ticket.id] = ticket
    }

    public func allGameTickets() -> [GameTicket] {
        ticketsById.values.sorted { $0.earnedAt < $1.earnedAt }
    }
}

// MARK: - SwiftData 기반 영구 저장소 (실기기 운영 & 영속성 검증용)
public final class SwiftDataMemoryStore: MemoryStoreProtocol {
    public let container: ModelContainer
    private let context: ModelContext

    public init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            WordMemoryRecord.self,
            ReviewLogRecord.self,
            GameTicketRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public func snapshot(for wordId: String) -> WordMemorySnapshot? {
        var descriptor = FetchDescriptor<WordMemoryRecord>(
            predicate: #Predicate { $0.wordId == wordId }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.snapshot
    }

    public func allSnapshots() -> [String: WordMemorySnapshot] {
        let records = (try? context.fetch(FetchDescriptor<WordMemoryRecord>())) ?? []
        var result: [String: WordMemorySnapshot] = [:]
        for record in records {
            result[record.wordId] = record.snapshot
        }
        return result
    }

    public func saveSnapshot(_ snapshot: WordMemorySnapshot) {
        let targetId = snapshot.wordId
        var descriptor = FetchDescriptor<WordMemoryRecord>(
            predicate: #Predicate { $0.wordId == targetId }
        )
        descriptor.fetchLimit = 1

        if let existing = (try? context.fetch(descriptor))?.first {
            existing.apply(snapshot)
        } else {
            context.insert(WordMemoryRecord(snapshot: snapshot))
        }
        try? context.save()
    }

    public func appendReviewLog(_ log: ReviewLogEntry) {
        context.insert(ReviewLogRecord(entry: log))
        try? context.save()
    }

    public func allReviewLogs() -> [ReviewLogEntry] {
        var descriptor = FetchDescriptor<ReviewLogRecord>(
            sortBy: [SortDescriptor(\.reviewedAt, order: .forward)]
        )
        descriptor.includePendingChanges = true
        return ((try? context.fetch(descriptor)) ?? []).map(\.entry)
    }

    public func saveGameTicket(_ ticket: GameTicket) {
        let targetId = ticket.id
        var descriptor = FetchDescriptor<GameTicketRecord>(
            predicate: #Predicate { $0.ticketId == targetId }
        )
        descriptor.fetchLimit = 1

        if let existing = (try? context.fetch(descriptor))?.first {
            existing.voiceId = ticket.voiceId
            existing.targetWordIdsRaw = ticket.targetWordIds.joined(separator: ",")
            existing.earnedAt = ticket.earnedAt
            existing.isConsumed = ticket.isConsumed
        } else {
            context.insert(GameTicketRecord(ticket: ticket))
        }
        try? context.save()
    }

    public func allGameTickets() -> [GameTicket] {
        let descriptor = FetchDescriptor<GameTicketRecord>(
            sortBy: [SortDescriptor(\.earnedAt, order: .forward)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(\.ticket)
    }
}
