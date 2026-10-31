import XCTest
import SwiftData
@testable import Hareru

final class HareruCoreTests: XCTestCase {

    private var fixedCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)! // Asia/Seoul 고정
        return cal
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) -> Date {
        let comps = DateComponents(
            calendar: fixedCalendar,
            timeZone: fixedCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: 0
        )
        return comps.date!
    }

    // MARK: - 1. 번들 카탈로그 로드 & 무결성 검증

    func testBundledCatalogLoadsAndValidatesCleanly() throws {
        let repo = try CatalogRepository.loadBundled()
        XCTAssertEqual(repo.words.count, 8)
        XCTAssertTrue(repo.validationIssues().isEmpty)

        let beer = try XCTUnwrap(repo.word(forId: "n5_food_beer"))
        XCTAssertFalse(beer.hasKanji)
        XCTAssertEqual(beer.nonKanjiNote?.displayBadge, "Dutch / English: bier / beer")

        let toriaezu = try XCTUnwrap(repo.word(forId: "n4_adv_toriaezu"))
        XCTAssertFalse(toriaezu.hasKanji)
        XCTAssertEqual(toriaezu.nonKanjiNote?.originTerm, "取り敢えず")
    }

    // MARK: - 2. 다의어 1단어 1카드 & 복습 회차별 예문 순환 출제 검증

    func testPolysemyOneWordOneCardAndReviewRotation() throws {
        let repo = try CatalogRepository.loadBundled()
        let amai = try XCTUnwrap(repo.word(forId: "n5_adj_amai"))

        XCTAssertTrue(amai.isPolysemous)
        XCTAssertEqual(amai.senses.count, 3)

        // 초회 학습(reps == 0): 대표 의미(뜻 1 · 디저트 점원) 출제
        XCTAssertEqual(amai.activeSense(forReps: 0).senseNumber, 1)
        XCTAssertEqual(amai.activeSense(forReps: 0).voice.id, "cafe_staff")

        // 1차 복습(reps == 1): 서브 의미 2(벽 외 조사단장) 출제
        XCTAssertEqual(amai.activeSense(forReps: 1).senseNumber, 2)
        XCTAssertEqual(amai.activeSense(forReps: 1).voice.id, "expedition_captain")

        // 2차 복습(reps == 2): 서브 의미 3(음성변조 명탐정) 출제
        XCTAssertEqual(amai.activeSense(forReps: 2).senseNumber, 3)
        XCTAssertEqual(amai.activeSense(forReps: 2).voice.id, "modulated_detective")

        // 3차 복습(reps == 3): 다시 뜻 1로 라운드로빈 순환
        XCTAssertEqual(amai.activeSense(forReps: 3).senseNumber, 1)

        // 출제 의미를 제외한 나머지 보조 의미가 하단 해설용으로 반환되는지 검증
        let restWhenSense2 = amai.supplementarySenses(excluding: amai.senses[1].id)
        XCTAssertEqual(restWhenSense2.map(\.senseNumber), [1, 3])
    }

    // MARK: - 3. 한자 글자 분리 · 발음 하이라이트 · 연관 단어 역인덱스 검증

    func testKanjiGlyphSegmentationHighlightAndInvertedIndex() throws {
        let repo = try CatalogRepository.loadBundled()

        let uketamawaru = try XCTUnwrap(repo.word(forId: "n3_biz_uketamawaru"))
        let glyphs = uketamawaru.termGlyphs
        XCTAssertEqual(glyphs.count, 2)
        XCTAssertEqual(glyphs[0], TermGlyph(index: 0, character: "承", isKanji: true))
        XCTAssertEqual(glyphs[1], TermGlyph(index: 1, character: "る", isKanji: false))

        let kanpai = try XCTUnwrap(repo.word(forId: "n4_social_kanpai"))
        let kanUsage = try XCTUnwrap(kanpai.kanjiUsage(for: "乾"))
        let haiUsage = try XCTUnwrap(kanpai.kanjiUsage(for: "杯"))

        XCTAssertTrue(kanUsage.isHighlighted(candidate: "カン", type: .onyomi))
        XCTAssertFalse(kanUsage.isHighlighted(candidate: "ケン", type: .onyomi))
        XCTAssertFalse(kanUsage.isHighlighted(candidate: "かわ.く", type: .kunyomi))
        XCTAssertTrue(haiUsage.isHighlighted(candidate: "ハイ", type: .onyomi))

        let autoRendakuUsage = WordKanjiUsage(kanji: "杯", activeReading: "ぱい", readingType: .onyomi)
        XCTAssertTrue(autoRendakuUsage.isHighlighted(candidate: "ハイ", type: .onyomi))

        let kanInfo = try XCTUnwrap(repo.kanjiInfo(for: "乾"))
        XCTAssertEqual(kanInfo.koreanHunEum, "마를 건")
        XCTAssertEqual(kanInfo.relatedWords.map(\.term), ["乾杯", "乾燥"])

        let shouInfo = try XCTUnwrap(repo.kanjiInfo(for: "承"))
        XCTAssertEqual(shouInfo.relatedWords.map(\.term), ["承る", "承認"])
    }

    // MARK: - 4. 어절 박스 묶음 후리가나 & 표제어 발음 스포일러 잠금 검증

    func testPhraseBoxFuriganaAndTargetWordSpoilerProtection() throws {
        let explicit = FuriganaParser.parsePhraseBoxes("ご{予約|よやく}を{承ります|うけたまわ}。", targetTerm: "承る")
        let implicit = FuriganaParser.parsePhraseBoxes("ご{予約|よやく}を{承|うけたまわ}ります。", targetTerm: "承る")

        XCTAssertEqual(explicit, implicit)
        XCTAssertEqual(explicit.map(\.surfaceText).joined(), "ご予約を承ります。")

        // 주변 문맥 한자('予約')는 파도 2에서 열리지만(isTargetWord == false),
        // 표제어 어절('承ります')은 정답 공개 전까지 잠금(isTargetWord == true)!
        let yoyakuBox = try XCTUnwrap(explicit.first { $0.baseText == "予約" })
        let uketamawaruBox = try XCTUnwrap(explicit.first { $0.baseText == "承" })
        XCTAssertFalse(yoyakuBox.isTargetWord)
        XCTAssertTrue(uketamawaruBox.isTargetWord)
        XCTAssertEqual(uketamawaruBox.surfaceText, "承ります")
        XCTAssertEqual(uketamawaruBox.reading, "うけたまわ")

        // 'ビール' 카드에서는 예문 속 '{乾杯|かんぱい}'가 주변 문맥이므로 정상 오픈(isTargetWord == false)
        let beerSegments = Word.beer.segments(for: Word.beer.primarySense)
        let kanpaiInBeer = try XCTUnwrap(beerSegments.first { $0.baseText == "乾杯" })
        XCTAssertFalse(kanpaiInBeer.isTargetWord)

        // 반면 '乾杯' 카드에서는 예문 속 '{乾杯|かんぱい}'가 표제어이므로 스포일러 잠금(isTargetWord == true)
        let kanpaiSegments = Word.kanpai.segments(for: Word.kanpai.primarySense)
        let kanpaiInKanpai = try XCTUnwrap(kanpaiSegments.first { $0.baseText == "乾杯" })
        XCTAssertTrue(kanpaiInKanpai.isTargetWord)
    }

    // MARK: - 5. 10초 3단 등속 파도 타이밍 설정(`CardTimingConfig`) 검증

    func testCardTimingConfigThreeStageWaves() {
        let timing = CardTimingConfig.standard

        // t = 1.5초: 파도 1(예문) 진행 중, 파도 2(후리가나)·파도 3(한국어 문맥)은 아직 0.0
        XCTAssertGreaterThan(timing.wave1Progress(at: 1.5), 0.0)
        XCTAssertEqual(timing.wave2Progress(at: 1.5), 0.0, accuracy: 1e-9)
        XCTAssertEqual(timing.wave3Progress(at: 1.5), 0.0, accuracy: 1e-9)

        // t = 3.0초: 캐릭터 태그 완료(1.0), 파도 2 출발, 파도 3은 아직 0.0
        XCTAssertEqual(timing.voiceTagProgress(at: 3.0), 1.0, accuracy: 1e-9)
        XCTAssertGreaterThan(timing.wave2Progress(at: 3.0), 0.0)
        XCTAssertEqual(timing.wave3Progress(at: 3.0), 0.0, accuracy: 1e-9)

        // 각 파도는 정확히 출발 + 6.0초 시점에 1.0 도달
        XCTAssertEqual(timing.wave1Progress(at: 6.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(timing.wave2Progress(at: 8.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(timing.wave3Progress(at: 10.0), 1.0, accuracy: 1e-9)
    }

    // MARK: - 6. 실패 침식(Red+Black) 및 졸업 정화 팔레트 검증

    func testThemePaletteErosionAndPurification() {
        let ramenPalette = Word.ramen.palette
        let original = ramenPalette.erodedRGBAColors(erosionProgress: 0.0)
        let midEroded = ramenPalette.erodedRGBAColors(erosionProgress: 0.5)
        let fullEroded = ramenPalette.erodedRGBAColors(erosionProgress: 1.0)

        XCTAssertEqual(fullEroded, ThemePalette.erosionTargets)
        let brightness0 = original[1].red + original[1].green + original[1].blue
        let brightnessMid = midEroded[1].red + midEroded[1].green + midEroded[1].blue
        let brightnessFull = fullEroded[1].red + fullEroded[1].green + fullEroded[1].blue
        XCTAssertGreaterThan(brightness0, brightnessMid)
        XCTAssertGreaterThan(brightnessMid, brightnessFull)
    }

    // MARK: - 7. FSRS 6단계 히든 등급 판정 매트릭스 검증

    func testSixTierGradeClassificationMatrix() {
        let engine = FSRSEngine()

        XCTAssertEqual(engine.classifyGrade(button: .again, elapsedSeconds: 0.5), .again)
        XCTAssertEqual(engine.classifyGrade(button: .again, elapsedSeconds: 11.2), .again)

        XCTAssertEqual(engine.classifyGrade(button: .hard, elapsedSeconds: 3.4), .hard)
        XCTAssertEqual(engine.classifyGrade(button: .hard, elapsedSeconds: 7.8), .hiddenHintAssisted)
        XCTAssertEqual(engine.classifyGrade(button: .hard, elapsedSeconds: 10.2), .again)

        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 1.9), .hiddenNearEasy)
        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 4.1), .good)
        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 6.5), .hiddenHintAssisted)
        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 10.5), .hiddenHintAssisted)

        XCTAssertEqual(engine.classifyGrade(button: .easy, elapsedSeconds: 2.0), .easy)
        XCTAssertEqual(engine.classifyGrade(button: .easy, elapsedSeconds: 3.7), .hiddenNearEasy) // 3.5~4.0s 경계 포함 검증
        XCTAssertEqual(engine.classifyGrade(button: .easy, elapsedSeconds: 5.2), .hiddenNearEasy)
        XCTAssertEqual(engine.classifyGrade(button: .easy, elapsedSeconds: 9.8), .good)
    }

    // MARK: - 8. FSRS 망각 곡선(R) · 초기 복습 주기 · 장기 안정성 성장 검증

    func testFSRSMathAndRetentionCurve() {
        let engine = FSRSEngine(desiredRetention: 0.90)
        let day1 = makeDate(2026, 11, 1)

        XCTAssertEqual(engine.retrievability(elapsedDays: 0.0, stability: 4.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(engine.retrievability(elapsedDays: 4.0, stability: 4.0), 0.90, accuracy: 1e-9)

        let g4 = engine.evaluateGraduation(previousState: nil, grade: .good, hadInterDayLapseToday: false, now: day1, calendar: fixedCalendar)
        let g5 = engine.evaluateGraduation(previousState: nil, grade: .hiddenNearEasy, hadInterDayLapseToday: false, now: day1, calendar: fixedCalendar)
        let g6 = engine.evaluateGraduation(previousState: nil, grade: .easy, hadInterDayLapseToday: false, now: day1, calendar: fixedCalendar)

        XCTAssertEqual(g4.scheduledIntervalDays, 1)
        XCTAssertEqual(g5.scheduledIntervalDays, 2)
        XCTAssertGreaterThanOrEqual(g6.scheduledIntervalDays, 4)

        let day2 = makeDate(2026, 11, 2)
        let nextReview = engine.evaluateGraduation(
            previousState: g4.updatedState,
            grade: .good,
            hadInterDayLapseToday: false,
            now: day2,
            calendar: fixedCalendar
        )
        XCTAssertGreaterThan(nextReview.updatedState.stability, g4.updatedState.stability)
        XCTAssertGreaterThanOrEqual(nextReview.scheduledIntervalDays, 2)
    }

    // MARK: - 9. 침식 단어 최종 확인 1회(`Confirmation Lap`) & 상한 캡 난이도 보정(Ease Hell 차단) 검증

    func testErodedCardRequiresConfirmationLapAndCapsDifficulty() {
        let store = InMemoryMemoryStore()
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.beer, .ramen], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: .standard,
            calendar: fixedCalendar
        )
        let today = makeDate(2026, 11, 1)
        session.startSession(words: [.beer, .ramen], now: today)

        // 1) 'ビール': 첫 시도에 바로 '앎(4등급)' → 확인 사살 없이 즉시 졸업 (D = 5.0)
        let outBeer = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.5, now: today)
        guard case .graduated(let beerSchedule, _, _, _) = outBeer?.status else {
            return XCTFail("Expected immediate graduation for first-try beer")
        }
        XCTAssertEqual(beerSchedule.updatedState.difficulty, 5.0, accuracy: 1e-9)

        // 2) 'ラーメン': 5번 연속 '어려움(1등급)'으로 침식 후 6번째에 '앎(4등급)' 달성
        for _ in 1...5 {
            _ = session.submitEvaluation(button: .again, overrideElapsedSeconds: 8.0, now: today)
        }

        // 6번째에 맞혔을 때 바로 졸업하지 않고 컬러만 정화한 뒤 최종 확인(`confirmationQueued`) 대기!
        let firstPass = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.5, now: today)
        XCTAssertEqual(
            firstPass?.status,
            .confirmationQueued(insertionIndex: 0, todayEncounters: 6, didPurifyColor: true)
        )
        XCTAssertEqual(session.currentItem?.isAwaitingFinalConfirmation, true)
        XCTAssertEqual(session.currentItem?.todayErosionCount, 0)

        // 7번째(최종 확인 라운드)에서 연속 통과해야 최종 졸업!
        let finalGrad = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.0, now: today)
        guard case .graduated(let ramenSchedule, _, let isComeback, _) = finalGrad?.status else {
            return XCTFail("Expected graduation after passing confirmation lap")
        }

        // 난이도(D)는 첫 시도 단어(5.0)보다는 높되, 상한선(6.2) 이하로 캡이 씌워져 Ease Hell 완벽 방지
        XCTAssertGreaterThan(ramenSchedule.updatedState.difficulty, beerSchedule.updatedState.difficulty)
        XCTAssertEqual(ramenSchedule.updatedState.difficulty, 6.2, accuracy: 1e-9)
        XCTAssertEqual(ramenSchedule.updatedState.lapses, 0)
        XCTAssertTrue(isComeback)
    }

    // MARK: - 10. 순환 큐 스마트 재투입 간격 검증

    func testCircularQueueSmartOffsets() throws {
        let repo = try CatalogRepository.loadBundled()
        let store = InMemoryMemoryStore()
        let config = SessionConfiguration(againReinsertOffset: 2, hardReinsertOffset: 4)
        let session = StudySessionEngine(
            catalog: repo,
            store: store,
            configuration: config,
            calendar: fixedCalendar
        )
        let today = makeDate(2026, 11, 1)
        session.startSession(now: today)
        XCTAssertEqual(session.queue.count, 8)

        let firstId = session.queue[0].word.id
        let hintOutcome = try XCTUnwrap(
            session.submitEvaluation(button: .good, overrideElapsedSeconds: 6.8, now: today)
        )
        XCTAssertEqual(hintOutcome.grade, .hiddenHintAssisted)
        XCTAssertEqual(session.queue.last?.word.id, firstId)

        let secondId = session.queue[0].word.id
        let againOutcome = try XCTUnwrap(
            session.submitEvaluation(button: .again, overrideElapsedSeconds: 4.0, now: today)
        )
        XCTAssertEqual(againOutcome.grade, .again)
        XCTAssertEqual(session.queue[2].word.id, secondId)
        XCTAssertEqual(session.queue[2].todayErosionCount, 1)

        let thirdId = session.queue[0].word.id
        let hardOutcome = try XCTUnwrap(
            session.submitEvaluation(button: .hard, overrideElapsedSeconds: 3.0, now: today)
        )
        XCTAssertEqual(hardOutcome.grade, .hard)
        XCTAssertEqual(session.queue[4].word.id, thirdId)
        XCTAssertEqual(session.queue[4].todayErosionCount, 0)
    }

    // MARK: - 11. 당일 8회 조우 캡 & 서로 다른 날 3회 누적 보류 → 손글씨 처방 노트 분류 및 해금 검증

    func testEightStrikeCapAndThreeDistinctDayLeechPrescription() {
        let store = InMemoryMemoryStore()
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.uketamawaru], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: .standard,
            calendar: fixedCalendar
        )

        let day1 = makeDate(2026, 11, 1)
        session.startSession(words: [.uketamawaru], now: day1)
        for attempt in 1...8 {
            let out = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day1)
            if attempt < 8 {
                guard case .requeued = out?.status else {
                    return XCTFail("Attempt \(attempt) should requeue")
                }
            } else {
                XCTAssertEqual(
                    out?.status,
                    .deferredByDailyCap(distinctDeferredDays: 1, prescribedToHandwritingNote: false)
                )
            }
        }
        XCTAssertTrue(session.queue.isEmpty)

        session.startSession(words: [.uketamawaru], now: day1.addingTimeInterval(3600))
        XCTAssertTrue(session.queue.isEmpty)

        let day2 = makeDate(2026, 11, 2)
        session.startSession(words: [.uketamawaru], now: day2)
        for _ in 1...7 {
            _ = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day2)
        }
        let day2Cap = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day2)
        XCTAssertEqual(
            day2Cap?.status,
            .deferredByDailyCap(distinctDeferredDays: 2, prescribedToHandwritingNote: false)
        )

        let day3 = makeDate(2026, 11, 3)
        session.startSession(words: [.uketamawaru], now: day3)
        for _ in 1...7 {
            _ = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day3)
        }
        let day3Cap = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day3)
        XCTAssertEqual(
            day3Cap?.status,
            .deferredByDailyCap(distinctDeferredDays: 3, prescribedToHandwritingNote: true)
        )
        XCTAssertEqual(session.prescribedLeechWords().map(\.id), ["n3_biz_uketamawaru"])

        let day4 = makeDate(2026, 11, 4)
        session.startSession(words: [.uketamawaru], now: day4)
        XCTAssertTrue(session.queue.isEmpty)

        let unlocked = session.completeHandwritingPrescription(for: "n3_biz_uketamawaru", now: day4)
        XCTAssertEqual(unlocked?.isLeechPrescribed, false)
        XCTAssertEqual(unlocked?.handwritingCompletedCount, 1)

        session.startSession(words: [.uketamawaru], now: day4)
        XCTAssertEqual(session.queue.count, 1)
    }

    // MARK: - 12. 졸업 보상 → 탭 2 SMS 미션 게임 티켓 발급 및 소비 검증

    func testGraduationMintsAndConsumesSMSGameTicket() {
        let store = InMemoryMemoryStore()
        let config = SessionConfiguration(graduationsPerGameTicket: 2)
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.beer, .kanpai], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: config,
            calendar: fixedCalendar
        )
        let today = makeDate(2026, 11, 1)
        session.startSession(words: [.beer, .kanpai], now: today)

        _ = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.0, now: today)
        let second = session.submitEvaluation(button: .easy, overrideElapsedSeconds: 2.0, now: today)

        guard case .graduated(_, _, _, let ticket2) = second?.status,
              let earnedTicket = ticket2 else {
            return XCTFail("Expected SMS game ticket on 2nd graduation")
        }

        XCTAssertEqual(earnedTicket.voiceId, "buchou")
        XCTAssertEqual(earnedTicket.targetWordIds, ["n5_food_beer", "n4_social_kanpai"])
        XCTAssertEqual(session.unconsumedGameTickets().count, 1)

        let consumed = session.consumeGameTicket(id: earnedTicket.id)
        XCTAssertEqual(consumed?.isConsumed, true)
        XCTAssertTrue(session.unconsumedGameTickets().isEmpty)
    }

    // MARK: - 13. SwiftData 영속성 & 원시 이벤트 텔레메트리(`ReviewLogEntry`) 검증

    func testSwiftDataMemoryStoreAndRawTelemetryRoundTrip() throws {
        let container = try SwiftDataMemoryStore.makeContainer(inMemory: true)
        let store = SwiftDataMemoryStore(container: container)

        // 이미 1회 졸업한 다의어('甘い', reps=1)를 복습할 때 뜻 2번이 출제되고 로그에 기록되는지 확인
        store.saveSnapshot(
            WordMemorySnapshot(
                wordId: "n5_adj_amai",
                stability: 2.0,
                difficulty: 4.5,
                reps: 1,
                lapses: 0,
                lastReviewedAt: makeDate(2026, 10, 30),
                dueAt: makeDate(2026, 11, 1)
            )
        )

        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.amai], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: SessionConfiguration(graduationsPerGameTicket: 1),
            calendar: fixedCalendar
        )

        let reviewDay = makeDate(2026, 11, 1)
        session.startSession(words: [.amai], now: reviewDay)
        XCTAssertEqual(session.currentItem?.presentedSense.senseNumber, 2) // 서브 의미 2 출제!

        _ = session.submitEvaluation(button: .good, overrideElapsedSeconds: 2.1, now: reviewDay)

        let logs = store.allReviewLogs()
        XCTAssertEqual(logs.count, 1)
        let log = try XCTUnwrap(logs.first)
        XCTAssertEqual(log.grade, .hiddenNearEasy)
        XCTAssertEqual(log.encounterIndexToday, 1)
        XCTAssertEqual(log.priorStability, 2.0, accuracy: 1e-9)
        XCTAssertEqual(log.priorDifficulty, 4.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(log.elapsedDaysSinceLastReview), 2.0, accuracy: 1e-9)
        XCTAssertEqual(log.presentedSenseNumber, 2)
        XCTAssertTrue(log.didGraduate)
    }

    // MARK: - 14. 일간 복습 카드 재학습 시 단일 망각 카운트 & 상한 캡 난이도 보호 검증

    func testInterDayReviewLapseCountsOnceAndCapsDifficulty() {
        let initialSnapshot = WordMemorySnapshot(
            wordId: "n5_food_beer",
            stability: 8.0,
            difficulty: 5.2,
            reps: 3,
            lapses: 0,
            lastReviewedAt: makeDate(2026, 10, 24),
            dueAt: makeDate(2026, 11, 1)
        )
        let store = InMemoryMemoryStore(initialSnapshots: [initialSnapshot])
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.beer], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: .standard,
            calendar: fixedCalendar
        )

        let reviewDay = makeDate(2026, 11, 1)
        session.startSession(words: [.beer], now: reviewDay)

        // 4번 틀린 뒤 5번째에 1차 통과(컬러 정화 + 최종 확인 대기) → 6번째에 최종 재졸업
        for _ in 1...4 {
            _ = session.submitEvaluation(button: .again, overrideElapsedSeconds: 6.0, now: reviewDay)
        }
        let confirmOut = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.2, now: reviewDay)
        guard case .confirmationQueued = confirmOut?.status else {
            return XCTFail("Expected confirmation lap after erosion")
        }

        let gradOut = session.submitEvaluation(button: .good, overrideElapsedSeconds: 2.8, now: reviewDay)
        guard case .graduated(let schedule, _, let isComeback, _) = gradOut?.status else {
            return XCTFail("Expected final graduation")
        }

        XCTAssertEqual(schedule.updatedState.lapses, 1) // 4번 틀려도 일간 망각은 단 1회!
        XCTAssertLessThanOrEqual(schedule.updatedState.difficulty, 6.0) // 상한 캡+평균 회귀로 폭등 차단
        XCTAssertTrue(isComeback)
    }

    // MARK: - 15. ContinuousClock 반응 타이머 일시정지 · 재개 · 정답 공개 잠금 검증

    func testContinuousClockReactionTimerPauseResumeAndLock() async throws {
        let store = InMemoryMemoryStore()
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.beer], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: .standard,
            calendar: fixedCalendar
        )

        session.startSession(words: [.beer], now: makeDate(2026, 11, 1))
        try await Task.sleep(for: .milliseconds(35))

        session.pauseReactionTimer()
        let pausedElapsed = session.currentElapsedSeconds()
        try await Task.sleep(for: .milliseconds(45))
        XCTAssertEqual(session.currentElapsedSeconds(), pausedElapsed, accuracy: 0.005)

        session.resumeReactionTimer()
        try await Task.sleep(for: .milliseconds(25))
        let locked = session.markAnswerRevealed()
        XCTAssertGreaterThan(locked, pausedElapsed)

        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(session.currentElapsedSeconds(), locked, accuracy: 1e-9)
    }
}
