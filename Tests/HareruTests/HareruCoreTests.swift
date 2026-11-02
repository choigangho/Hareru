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
        // 견본 30 + N5 705 이상 — N4~N1 뜻 초안이 들어올수록 늘어남 (Tools/export_levels.sh)
        XCTAssertGreaterThanOrEqual(repo.words.count, 735)
        XCTAssertGreaterThanOrEqual(repo.kanjiByCharacter.count, 465)
        XCTAssertTrue(repo.validationIssues().isEmpty, "Issues: \(repo.validationIssues())")

        // 10명의 시그니처 성우 캐릭터가 모두 30단어 스타터 팩에 등장하는지 검증
        let representedVoiceIds = Set(repo.words.flatMap { $0.senses.map(\.voice.id) })
        for preset in VoiceProfile.allPresets {
            XCTAssertTrue(representedVoiceIds.contains(preset.id), "Missing voice preset in 30-word catalog: \(preset.id)")
        }

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

        // t = 3.0초: 파도 2 출발, 파도 3은 아직 0.0
        XCTAssertGreaterThan(timing.wave2Progress(at: 3.0), 0.0)
        XCTAssertEqual(timing.wave3Progress(at: 3.0), 0.0, accuracy: 1e-9)

        // 음성 캐릭터 별명은 6.5초, 앞면 예문은 그보다 느린 10.0초에 완전히 선명
        XCTAssertLessThan(timing.voiceTagProgress(at: 6.0), 1.0)
        XCTAssertEqual(timing.voiceTagProgress(at: 6.5), 1.0, accuracy: 1e-9)
        XCTAssertLessThan(timing.wave1Progress(at: 9.0), 1.0)
        XCTAssertEqual(timing.wave1Progress(at: 10.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(timing.exampleFadeDuration, FSRSEngine().thresholds.hintWindowUpperBound, accuracy: 1e-9)

        // 파도 2·3은 출발 + 6.0초 시점에 1.0 도달
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
        let config = SessionConfiguration(newCardLimit: 30, againReinsertOffset: 2, hardReinsertOffset: 4)
        let session = StudySessionEngine(
            catalog: repo,
            store: store,
            configuration: config,
            calendar: fixedCalendar
        )
        let today = makeDate(2026, 11, 1)
        session.startSession(now: today)
        XCTAssertEqual(session.queue.count, 30)

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

    // MARK: - 16. 한글 발음 → 일본어 자동 변환기 유사 발음 보정 & 문장 변환 검증

    func testHangulKanaConverterPhoneticFuzzyMatchingAndSentenceConversion() {
        let converter = HangulKanaConverter()

        // 1) 평음/격음/경음/받침 유사 발음('칸파이', '간파이', '캄파이', '깐파이')이 모두 '乾杯'로 매칭되는지 검증
        for variant in ["칸파이", "간파이", "캄파이", "깐파이"] {
            let candidates = converter.suggestCandidates(for: variant)
            XCTAssertEqual(candidates.first?.entry.surface, "乾杯", "Failed variant: \(variant)")
        }

        // 2) 장음 유무('비루' vs '비이루', '시마쇼' vs '시마쇼우') 동일 매칭 검증
        XCTAssertEqual(converter.suggestCandidates(for: "비루").first?.entry.surface, "ビール")
        XCTAssertEqual(converter.suggestCandidates(for: "비이루").first?.entry.surface, "ビール")
        XCTAssertEqual(converter.suggestCandidates(for: "시마쇼").first?.entry.surface, "しましょう")
        XCTAssertEqual(converter.suggestCandidates(for: "시마쇼우").first?.entry.surface, "しましょう")

        // 3) 전체 한글 발음 문장 → 일본어 문장 자동 변환 검증
        let fullSentence = converter.convertFullInput("토리아에즈 비루데 칸파이 시마쇼")
        XCTAssertEqual(fullSentence, "とりあえず、ビールで乾杯しましょう")

        let noisySentence = converter.convertFullInput("도리아에즈 삐루데 간파이 시마쇼우")
        XCTAssertEqual(noisySentence, "とりあえず、ビールで乾杯しましょう")
    }

    // MARK: - 17. 분기형 SMS 에피소드 3턴 진행 & 호감도·재시도 판정 검증

    func testSMSEpisodeEngineBranchingProgressionAndClear() {
        let engine = SMSEpisodeEngine(episode: .buchouIzakaya)
        XCTAssertEqual(engine.currentTurnIndex, 0)
        XCTAssertEqual(engine.affectionScore, 20)
        XCTAssertFalse(engine.isEpisodeCleared)

        // 1) 엉뚱한 입력 시 턴이 넘어가지 않고 힌트 유도(.retryHint) 분기 반환
        let retryBranch = engine.submitReplyImmediately("모르겠어요")
        XCTAssertEqual(retryBranch?.tier, .retryHint)
        XCTAssertEqual(engine.currentTurnIndex, 0)
        XCTAssertEqual(engine.affectionScore, 20)

        // 2) Turn 1: 한글 발음으로 건배 제안 전송 → 대성공(.greatSuccess, 호감도 +40) & Turn 2 진급
        let turn1Branch = engine.submitReplyImmediately("토리아에즈 비루데 칸파이 시마쇼")
        XCTAssertEqual(turn1Branch?.tier, .greatSuccess)
        XCTAssertEqual(turn1Branch?.stamp, .cheers)
        XCTAssertEqual(engine.currentTurnIndex, 1)
        XCTAssertEqual(engine.affectionScore, 60)

        // 3) Turn 2: 디저트 맛 칭찬 → 대성공 & Turn 3 진급
        let turn2Branch = engine.submitReplyImmediately("아마쿠테 오이시이 데스네")
        XCTAssertEqual(turn2Branch?.tier, .greatSuccess)
        XCTAssertEqual(engine.currentTurnIndex, 2)
        XCTAssertEqual(engine.affectionScore, 100)

        // 4) Turn 3: 마무리 돈코츠 라멘 제안 → 에피소드 클리어!
        let turn3Branch = engine.submitReplyImmediately("시메와 돈코츠 라멘 데스네")
        XCTAssertEqual(turn3Branch?.tier, .greatSuccess)
        XCTAssertTrue(engine.isEpisodeCleared)
    }

    // MARK: - 18. 탭 3 처방 노트 시뮬레이션 및 해금 연동 검증

    func testSimulateLeechPrescriptionAndUnlockFlow() throws {
        let repo = try CatalogRepository.loadBundled()
        let store = InMemoryMemoryStore()
        let session = StudySessionEngine(
            catalog: repo,
            store: store,
            configuration: SessionConfiguration(newCardLimit: 30),
            calendar: fixedCalendar
        )
        let today = makeDate(2026, 11, 1)
        session.startSession(now: today)
        XCTAssertEqual(session.queue.count, 30)

        // '承る'를 손글씨 처방 노트 대상으로 시뮬레이션 지정 → 일반 큐에서 즉시 분리
        let prescribed = session.simulateLeechPrescription(for: "n3_biz_uketamawaru", now: today)
        XCTAssertTrue(prescribed.isLeechPrescribed)
        XCTAssertEqual(session.prescribedLeechWords().map(\.id), ["n3_biz_uketamawaru"])
        XCTAssertEqual(session.queue.count, 29)

        // 종이 노트 3회 필기 완료 처리 → 처방 해제
        let unlocked = session.completeHandwritingPrescription(for: "n3_biz_uketamawaru", now: today)
        XCTAssertEqual(unlocked?.isLeechPrescribed, false)
        XCTAssertEqual(unlocked?.handwritingCompletedCount, 1)
        XCTAssertTrue(session.prescribedLeechWords().isEmpty)
    }

    // MARK: - 19. 카테고리 기반 테마 팔레트 통일 & 미분류 기본 색상 폴백 검증

    func testCategoryThemeGroupAndDefaultPaletteFallback() {
        // 같은 식음료 카테고리인 'ビール'와 'ラーメン'은 단어별 무작위 색이 아니라 동일한 카테고리 테마를 공유
        XCTAssertEqual(Word.beer.categoryThemeGroup, .daily)
        XCTAssertEqual(Word.ramen.categoryThemeGroup, .daily)
        XCTAssertEqual(Word.beer.categoryPalette, Word.ramen.categoryPalette)

        // 카테고리가 애매하거나 비어 있는 단어는 디폴트 테마(.fieldless)로 깔끔하게 귀속
        XCTAssertEqual(CategoryThemeGroup.resolve(for: "기타 미분류 어휘"), .fieldless)
        XCTAssertEqual(ThemePalette.forCategory("기타 미분류 어휘"), ThemePalette.defaultPalette)
    }

    // MARK: - 20. 10문항 진단 기반 일일 암기 계획 & 추후 학습 정답률에 따른 동적 진도 변화 검증

    func testDiagnosticPlanAndLiveLearningTrendAdaptation() throws {
        let repo = try CatalogRepository.loadBundled()
        let questions = StudyPlanCalculator.makeDiagnosticQuestions(for: .n2, catalog: repo, count: 10)
        XCTAssertEqual(questions.count, 10)
        for q in questions {
            XCTAssertEqual(q.choices.count, 4)
            XCTAssertEqual(q.choices[q.correctIndex], q.word.meaning)
        }

        let today = makeDate(2026, 11, 1)
        let examDate = makeDate(2026, 12, 31) // 60일 뒤 시험

        // Case 1: N2 10문항 테스트에서 0개 맞힌 초심자 vs 9개 맞힌 숙련자 비교
        let beginnerProfile = UserStudyProfile(
            email: "beginner@hareru.app",
            displayName: "초심자",
            passwordHash: UserStudyProfile.hashPassword("pass1234"),
            targetLevel: .n2,
            examDate: examDate,
            diagnosticTestedCount: 10,
            diagnosticCorrectCount: 0,
            diagnosticAverageSeconds: 7.5,
            createdAt: today
        )
        let advancedProfile = UserStudyProfile(
            email: "advanced@hareru.app",
            displayName: "숙련자",
            passwordHash: UserStudyProfile.hashPassword("pass1234"),
            targetLevel: .n2,
            examDate: examDate,
            diagnosticTestedCount: 10,
            diagnosticCorrectCount: 9,
            diagnosticAverageSeconds: 2.5,
            createdAt: today
        )

        let beginnerInitialPlan = StudyPlanCalculator.evaluatePlan(
            profile: beginnerProfile,
            snapshots: [:],
            reviewLogs: [],
            now: today,
            calendar: fixedCalendar
        )
        let advancedInitialPlan = StudyPlanCalculator.evaluatePlan(
            profile: advancedProfile,
            snapshots: [:],
            reviewLogs: [],
            now: today,
            calendar: fixedCalendar
        )

        // 숙련자는 기저 아는 단어가 많아 남은 암기량이 적고, 일일 소화 가능 속도도 훨씬 높음
        XCTAssertGreaterThan(beginnerInitialPlan.remainingWordsToLearn, advancedInitialPlan.remainingWordsToLearn)
        XCTAssertGreaterThan(advancedInitialPlan.estimatedDailyPaceCapacity, beginnerInitialPlan.estimatedDailyPaceCapacity)
        XCTAssertEqual(beginnerInitialPlan.feasibility, .tight)
        XCTAssertEqual(advancedInitialPlan.feasibility, .comfortable)

        // Case 2: 처음 10장은 다 틀렸던 초심자라도, 이후 실제 학습(20회)에서 높은 정답률·빠른 반응 속도를 보이면
        //         예상 일일 소화 가능 속도가 상승하고 완주 예상 일수가 단축되는지 검증!
        let strongLiveLogs: [ReviewLogEntry] = (1...20).map { idx in
            ReviewLogEntry(
                id: "live_\(idx)",
                wordId: "n5_food_beer",
                reviewedAt: today,
                button: .easy,
                grade: .easy,
                reactionSeconds: 2.1,
                didGraduate: true,
                didHitDailyCap: false
            )
        }
        let beginnerUpdatedPlan = StudyPlanCalculator.evaluatePlan(
            profile: beginnerProfile,
            snapshots: [:],
            reviewLogs: strongLiveLogs,
            now: today,
            calendar: fixedCalendar
        )

        XCTAssertTrue(beginnerUpdatedPlan.isUsingLiveLearningTrend)
        XCTAssertGreaterThan(beginnerUpdatedPlan.estimatedDailyPaceCapacity, beginnerInitialPlan.estimatedDailyPaceCapacity)
        XCTAssertLessThan(beginnerUpdatedPlan.expectedDaysAtCurrentPace, beginnerInitialPlan.expectedDaysAtCurrentPace)
    }

    // MARK: - 통계 탭: 3D 글라스 잔디 & 4버튼 분포

    private func makeLog(_ wordId: String, _ date: Date, _ button: ReviewButton) -> ReviewLogEntry {
        ReviewLogEntry(
            wordId: wordId,
            reviewedAt: date,
            button: button,
            grade: .good,
            reactionSeconds: 3.0,
            didGraduate: button != .again,
            didHitDailyCap: false
        )
    }

    func testHeatmapBuildsFourteenSundayStartWeeksWithUniqueWordCounts() {
        let now = makeDate(2026, 11, 4) // 수요일
        let logs = [
            makeLog("a", makeDate(2026, 11, 4, hour: 9), .good),
            makeLog("a", makeDate(2026, 11, 4, hour: 21), .again),
            makeLog("b", makeDate(2026, 11, 4, hour: 22), .easy),
            makeLog("c", makeDate(2026, 11, 2), .hard)
        ]

        let columns = StudyHeatmapCalculator.weeklyColumns(logs: logs, weeks: 14, now: now, calendar: fixedCalendar)
        XCTAssertEqual(columns.count, 14)
        XCTAssertTrue(columns.allSatisfy { $0.count == 7 })

        let lastWeek = columns[13]
        XCTAssertEqual(lastWeek[0].dayKey, "2026-11-01") // 일요일 시작
        XCTAssertEqual(lastWeek[3].dayKey, "2026-11-04")
        XCTAssertEqual(lastWeek[3].studiedWordCount, 2)   // 같은 단어 중복 제외
        XCTAssertEqual(lastWeek[3].reviewCount, 3)
        XCTAssertEqual(lastWeek[3].intensityLevel, 1)
        XCTAssertEqual(lastWeek[1].studiedWordCount, 1)
        XCTAssertFalse(lastWeek[3].isFuture)
        XCTAssertTrue(lastWeek[4].isFuture)
        XCTAssertEqual(columns[0][0].dayKey, "2026-08-02")

        XCTAssertEqual(StudyHeatmapCalculator.intensityLevel(forWordCount: 0), 0)
        XCTAssertEqual(StudyHeatmapCalculator.intensityLevel(forWordCount: 9), 2)
        XCTAssertEqual(StudyHeatmapCalculator.intensityLevel(forWordCount: 25), 4)
    }

    func testStreakAndButtonDistributionUseOnlyFourVisibleButtons() {
        let now = makeDate(2026, 11, 4, hour: 8)
        let logs = [
            makeLog("a", makeDate(2026, 11, 3), .good),
            makeLog("b", makeDate(2026, 11, 2), .again),
            makeLog("c", makeDate(2026, 11, 1), .easy),
            makeLog("d", makeDate(2026, 10, 30), .good)
        ]

        // 오늘은 아직 학습 전이므로 어제부터 3일 연속
        XCTAssertEqual(StudyHeatmapCalculator.currentStreak(logs: logs, now: now, calendar: fixedCalendar), 3)
        XCTAssertEqual(StudyHeatmapCalculator.currentStreak(logs: [], now: now, calendar: fixedCalendar), 0)

        let distribution = StudyHeatmapCalculator.buttonDistribution(logs: logs)
        XCTAssertEqual(distribution.map(\.button), [.again, .hard, .good, .easy])
        XCTAssertEqual(distribution.map(\.count), [1, 0, 2, 1])
    }

    // MARK: - 4버튼 OKLCH 색상 세트

    func testOKLCHConversionAndSkyDerivedEvaluationButtonTints() {
        let white = RGBAColor.oklch(lightness: 1.0, chroma: 0, hueDegrees: 0)
        XCTAssertEqual(white.red, 1.0, accuracy: 0.002)
        XCTAssertEqual(white.green, 1.0, accuracy: 0.002)
        XCTAssertEqual(white.blue, 1.0, accuracy: 0.002)

        let gray = RGBAColor.oklch(lightness: 0.6, chroma: 0, hueDegrees: 120)
        XCTAssertEqual(gray.red, gray.green, accuracy: 0.002)
        XCTAssertEqual(gray.green, gray.blue, accuracy: 0.002)

        for isDarkCase in [(WeatherCondition.rain, SkyTimeOfDay.night), (.snow, .morning)] {
            let palette = WeatherSkyPalette.resolve(condition: isDarkCase.0, timeOfDay: isDarkCase.1)
            let tints = [palette.buttonAgainTint, palette.buttonHardTint, palette.buttonGoodTint, palette.buttonEasyTint]
            XCTAssertEqual(Set(tints).count, 4)

            // 네 버튼은 하늘 색상각 주변(±30°)의 저채도 인접색이고, 모르겠음 → 쉬움으로 갈수록 밝아짐
            let skyHue = palette.skyGradient[1].oklchComponents.hueDegrees
            let components = tints.map(\.oklchComponents)
            for c in components {
                let diff = abs(((c.hueDegrees - skyHue) + 540).truncatingRemainder(dividingBy: 360) - 180)
                XCTAssertLessThanOrEqual(diff, 30)
                XCTAssertLessThan(c.chroma, 0.08)
            }
            XCTAssertEqual(components.map(\.lightness), components.map(\.lightness).sorted())
            // 흰 글씨가 읽히도록 네 버튼 모두 상대 휘도가 충분히 낮아야 함 (흰색 대비 3:1 이상)
            for tint in tints {
                func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
                let luminance = 0.2126 * linear(tint.red) + 0.7152 * linear(tint.green) + 0.0722 * linear(tint.blue)
                XCTAssertGreaterThanOrEqual(1.05 / (luminance + 0.05), 3.0)
            }
        }
    }

    // MARK: - 표제어 루비: 한자별 / 숙자훈 묶음 배치

    func testTermRubyRunsPlaceReadingOverEachKanjiOrJukujikunGroup() throws {
        let repo = try CatalogRepository.loadBundled()
        func runs(_ term: String) throws -> [(String, String?)] {
            let word = try XCTUnwrap(repo.words.first { $0.term == term }, term)
            return word.termRubyRuns.map { ($0.text, $0.reading) }
        }

        // 한자별 발음이 단어 읽기와 맞으면 한자마다 따로
        XCTAssertEqual(try runs("現実").map(\.0), ["現", "実"])
        XCTAssertEqual(try runs("現実").map(\.1), ["げん", "じつ"])
        // 오쿠리가나는 루비 없이 뒤에 이어 붙음
        XCTAssertEqual(try runs("甘い").map(\.1), ["あま", nil])
        // 숙자훈(美味 = おい)은 두 한자 묶음 위에 한 번에
        XCTAssertEqual(try runs("美味しい").map(\.0), ["美味", "しい"])
        XCTAssertEqual(try runs("美味しい").map(\.1), ["おい", nil])

        // 모든 단어에서 루비를 이어 붙이면(가나는 그대로) 단어 읽기가 복원되어야 함
        for word in repo.words {
            let rebuilt = word.termRubyRuns.map { $0.reading ?? JapaneseScript.toHiragana($0.text) }.joined()
            XCTAssertEqual(rebuilt, JapaneseScript.toHiragana(word.reading), word.term)
        }
    }

    // MARK: - 데이터 파이프라인: 시험 배치(Tools/build/pilot)가 앱 무결성 검사를 통과하는지

    func testPilotCatalogExportPassesAppValidation() throws {
        // Tools/build 아래 words.json + kanji.json이 있는 모든 내보내기 묶음(pilot, n5 …)을 검사
        let buildDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tools/build")
        let exportDirectories = ((try? FileManager.default.contentsOfDirectory(
            at: buildDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("words.json").path) }
        guard !exportDirectories.isEmpty else {
            throw XCTSkip("Tools/build 내보내기 결과가 없음 (export_catalog.py 실행 전)")
        }
        for directory in exportDirectories {
            try assertExportPassesAppValidation(directory)
        }
    }

    private func assertExportPassesAppValidation(_ directory: URL) throws {
        let wordsURL = directory.appendingPathComponent("words.json")
        let kanjiURL = directory.appendingPathComponent("kanji.json")
        let decoder = JSONDecoder()
        let words = try decoder.decode([Word].self, from: Data(contentsOf: wordsURL))
        let kanji = try decoder.decode([KanjiInfo].self, from: Data(contentsOf: kanjiURL))
        let repo = CatalogRepository(words: words, kanjiEntries: kanji)

        XCTAssertTrue(repo.validationIssues().isEmpty, "\(directory.lastPathComponent) Issues: \(repo.validationIssues())")
        XCTAssertEqual(Set(words.map(\.id)).count, words.count, "\(directory.lastPathComponent) 중복 ID")

        for word in words {
            // 표제어 루비를 이어 붙이면 단어 읽기가 복원되어야 함
            let rebuilt = word.termRubyRuns.map { $0.reading ?? JapaneseScript.toHiragana($0.text) }.joined()
            XCTAssertEqual(rebuilt, JapaneseScript.toHiragana(word.reading), word.term)

            for sense in word.senses where sense.hasExample {  // 예문 없는 의미(추후 추가)는 뜻만 검사 대상
                XCTAssertFalse(sense.translation.answer.isEmpty, "\(word.term) 해석 정답 조각 비어 있음")
                // 한자 단어는 예문 안에서 정답 어절이 감지되어야 정답 공개 전 후리가나가 잠김
                if word.termGlyphs.contains(where: \.isKanji) {
                    let segments = word.segments(for: sense)
                    XCTAssertTrue(segments.contains(where: \.isTargetWord), "\(word.term) 예문에서 정답 어절을 못 찾음: \(sense.example)")
                } else {
                    // 가나 단어는 활용형(かける → かけて)도 인정: 끝 글자를 뗀 어간이 예문에 있으면 통과
                    let stem = word.term.count > 2 ? String(word.term.dropLast()) : word.term
                    XCTAssertTrue(sense.example.contains(stem), "\(word.term) 예문에 표제어가 없음: \(sense.example)")
                }
            }
        }
    }

    // MARK: - 게임 음성 캐릭터 10인

    func testGameCastIsTenUniqueResolvableVoices() {
        let cast = VoiceProfile.gameCast
        XCTAssertEqual(cast.count, 10)
        XCTAssertEqual(Set(cast.map(\.id)).count, 10)
        for voice in cast {
            XCTAssertTrue(voice.isAssigned)
            XCTAssertEqual(VoiceProfile.preset(forId: voice.id), voice)
            XCTAssertFalse(voice.id.contains(" "), "voiceId에 공백: '\(voice.id)'")
        }
        // 주임 연구원은 이름 읽기를 엔딩까지 숨기므로 표시 이름에 이름이 들어가면 안 됨
        XCTAssertEqual(VoiceProfile.guideResearcher.label, "주임 연구원")
        XCTAssertEqual(VoiceProfile.preset(forId: "unassigned"), .unassigned)
    }
}
