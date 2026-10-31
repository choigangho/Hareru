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

        // 비한자 외래어·히라가나 어원 안내 확인
        let beer = try XCTUnwrap(repo.word(forId: "n5_food_beer"))
        XCTAssertFalse(beer.hasKanji)
        XCTAssertEqual(beer.nonKanjiNote?.displayBadge, "Dutch / English: bier / beer")

        let toriaezu = try XCTUnwrap(repo.word(forId: "n4_adv_toriaezu"))
        XCTAssertFalse(toriaezu.hasKanji)
        XCTAssertEqual(toriaezu.nonKanjiNote?.originTerm, "取り敢えず")
    }

    // MARK: - 2. 다의어 1단어 1카드 구조 검증

    func testPolysemyOneWordOneCardStructure() throws {
        let repo = try CatalogRepository.loadBundled()
        let amai = try XCTUnwrap(repo.word(forId: "n5_adj_amai"))

        XCTAssertTrue(amai.isPolysemous)
        XCTAssertEqual(amai.senses.count, 3)
        XCTAssertEqual(amai.secondarySenses.count, 2)

        // 대표 의미(뜻 1)가 카드의 메인 뜻·성우·예문을 담당
        XCTAssertEqual(amai.meaning, "달다, 달콤하다")
        XCTAssertEqual(amai.voice.id, "cafe_staff")
        XCTAssertEqual(amai.transBefore + amai.transAnswer + amai.transAfter, "이 케이크, 적당히 달콤해서 맛있네요.")

        // 서브 의미(뜻 2, 3)는 서로 다른 성우 캐릭터와 보조 팔레트 보유
        XCTAssertEqual(amai.secondarySenses[0].voice.id, "expedition_captain")
        XCTAssertEqual(amai.secondarySenses[0].voice.archetype, .homage)
        XCTAssertNotNil(amai.secondarySenses[0].subPalette)

        XCTAssertEqual(amai.secondarySenses[1].voice.id, "modulated_detective")
        XCTAssertEqual(amai.secondarySenses[1].voice.archetype, .modulated)
        XCTAssertNotNil(amai.secondarySenses[1].subPalette)
    }

    // MARK: - 3. 한자 글자 분리 · 발음 하이라이트 · 연관 단어 역인덱스 검증

    func testKanjiGlyphSegmentationHighlightAndInvertedIndex() throws {
        let repo = try CatalogRepository.loadBundled()

        // '承る': '承'만 한자 터치 대상이고 오쿠리가나 'る'는 비한자
        let uketamawaru = try XCTUnwrap(repo.word(forId: "n3_biz_uketamawaru"))
        let glyphs = uketamawaru.termGlyphs
        XCTAssertEqual(glyphs.count, 2)
        XCTAssertEqual(glyphs[0], TermGlyph(index: 0, character: "承", isKanji: true))
        XCTAssertEqual(glyphs[1], TermGlyph(index: 1, character: "る", isKanji: false))

        // '乾杯': 연탁/반탁음 변형('ぱい' ← 원형 'ハイ') 하이라이트 정확도 검증
        let kanpai = try XCTUnwrap(repo.word(forId: "n4_social_kanpai"))
        let kanUsage = try XCTUnwrap(kanpai.kanjiUsage(for: "乾"))
        let haiUsage = try XCTUnwrap(kanpai.kanjiUsage(for: "杯"))

        XCTAssertTrue(kanUsage.isHighlighted(candidate: "カン", type: .onyomi))
        XCTAssertFalse(kanUsage.isHighlighted(candidate: "ケン", type: .onyomi))
        XCTAssertFalse(kanUsage.isHighlighted(candidate: "かわ.く", type: .kunyomi))
        XCTAssertTrue(haiUsage.isHighlighted(candidate: "ハイ", type: .onyomi))

        // dictionaryReading 생략 시에도 자동 청음 환원으로 'ぱい' ↔ 'ハイ' 매칭 확인
        let autoRendakuUsage = WordKanjiUsage(kanji: "杯", activeReading: "ぱい", readingType: .onyomi)
        XCTAssertTrue(autoRendakuUsage.isHighlighted(candidate: "ハイ", type: .onyomi))

        // 역인덱스 검증: '乾'을 공유하는 '乾杯(N4)'와 '乾燥(N3)' 자동 연결
        let kanInfo = try XCTUnwrap(repo.kanjiInfo(for: "乾"))
        XCTAssertEqual(kanInfo.koreanHunEum, "마를 건")
        XCTAssertEqual(kanInfo.relatedWords.map(\.term), ["乾杯", "乾燥"])

        let siblingsOfKanpai = repo.relatedWords(forKanji: "乾", excludingWordId: kanpai.id)
        XCTAssertEqual(siblingsOfKanpai.map(\.term), ["乾燥"])

        // '承'을 공유하는 훈독 단어('承る')와 음독 단어('承認') 양방향 연결
        let shouInfo = try XCTUnwrap(repo.kanjiInfo(for: "承"))
        XCTAssertEqual(shouInfo.relatedWords.map(\.term), ["承る", "承認"])
    }

    // MARK: - 4. 어절 박스 묶음 후리가나 조판 파서 검증

    func testPhraseBoxFuriganaPreventsGlyphSplitting() {
        // 명시적 어절 표기 및 한자 단독 표기 모두 동일한 어절 박스('承ります')로 병합되는지 검증
        let explicit = FuriganaParser.parsePhraseBoxes("ご{予約|よやく}を{承ります|うけたまわ}。")
        let implicit = FuriganaParser.parsePhraseBoxes("ご{予約|よやく}を{承|うけたまわ}ります。")

        XCTAssertEqual(explicit, implicit)
        XCTAssertEqual(explicit.map(\.surfaceText).joined(), "ご予約を承ります。")

        let uketamawaruBox = explicit.first { $0.baseText == "承" }
        XCTAssertNotNil(uketamawaruBox)
        XCTAssertEqual(uketamawaruBox?.okurigana, "ります")
        XCTAssertEqual(uketamawaruBox?.surfaceText, "承ります")
        XCTAssertEqual(uketamawaruBox?.reading, "うけたまわ")
    }

    // MARK: - 5. 실패 침식(Red+Black) 및 졸업 정화 팔레트 검증

    func testThemePaletteErosionAndPurification() {
        // 원래 붉은 계열인 라멘 카드도 침식 시 채도가 빠진 칠흑+딥크림슨으로 명확히 어두워지는지 확인
        let ramenPalette = Word.ramen.palette
        let original = ramenPalette.erodedRGBAColors(erosionProgress: 0.0)
        let midEroded = ramenPalette.erodedRGBAColors(erosionProgress: 0.5)
        let fullEroded = ramenPalette.erodedRGBAColors(erosionProgress: 1.0)

        XCTAssertEqual(fullEroded, ThemePalette.erosionTargets)
        // 중간 베이지(#F5E0B3)가 침식될수록 밝기(R+G+B)가 단조 감소
        let brightness0 = original[1].red + original[1].green + original[1].blue
        let brightnessMid = midEroded[1].red + midEroded[1].green + midEroded[1].blue
        let brightnessFull = fullEroded[1].red + fullEroded[1].green + fullEroded[1].blue
        XCTAssertGreaterThan(brightness0, brightnessMid)
        XCTAssertGreaterThan(brightnessMid, brightnessFull)

        // 졸업(failureCount = 0) 시 본연의 퍼스널 컬러로 100% 복원
        XCTAssertEqual(ThemePalette.erosionProgress(forFailureCount: 0), 0.0)
        XCTAssertEqual(ThemePalette.erosionProgress(forFailureCount: 7, maxFailuresBeforeCap: 7), 1.0)
    }

    // MARK: - 6. FSRS 6단계 히든 등급 판정 매트릭스 검증

    func testSixTierGradeClassificationMatrix() {
        let engine = FSRSEngine()

        // 1) 어려움 버튼: 시간 무관 1등급
        XCTAssertEqual(engine.classifyGrade(button: .again, elapsedSeconds: 0.5), .again)
        XCTAssertEqual(engine.classifyGrade(button: .again, elapsedSeconds: 11.2), .again)

        // 2) 애매함 버튼: <6s → 3등급, 6~10s → 2등급(히든1), >=10s → 1등급
        XCTAssertEqual(engine.classifyGrade(button: .hard, elapsedSeconds: 3.4), .hard)
        XCTAssertEqual(engine.classifyGrade(button: .hard, elapsedSeconds: 7.8), .hiddenHintAssisted)
        XCTAssertEqual(engine.classifyGrade(button: .hard, elapsedSeconds: 10.2), .again)

        // 3) 앎 버튼: <2.5s → 5등급(히든2), 2.5~6s → 4등급(졸업선), >=6s → 2등급(히든1)
        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 1.9), .hiddenNearEasy)
        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 4.1), .good)
        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 6.5), .hiddenHintAssisted)
        XCTAssertEqual(engine.classifyGrade(button: .good, elapsedSeconds: 10.5), .hiddenHintAssisted)

        // 4) 쉬움 버튼: <3.5s → 6등급, 3.5~7s → 5등급(히든2), >=7s → 4등급(완충 졸업 보장)
        XCTAssertEqual(engine.classifyGrade(button: .easy, elapsedSeconds: 2.0), .easy)
        XCTAssertEqual(engine.classifyGrade(button: .easy, elapsedSeconds: 5.2), .hiddenNearEasy)
        XCTAssertEqual(engine.classifyGrade(button: .easy, elapsedSeconds: 9.8), .good)

        // 졸업 기준선 확인
        XCTAssertFalse(EvaluationGrade.again.isGraduating)
        XCTAssertFalse(EvaluationGrade.hiddenHintAssisted.isGraduating)
        XCTAssertFalse(EvaluationGrade.hard.isGraduating)
        XCTAssertTrue(EvaluationGrade.good.isGraduating)
        XCTAssertTrue(EvaluationGrade.hiddenNearEasy.isGraduating)
        XCTAssertTrue(EvaluationGrade.easy.isGraduating)
    }

    // MARK: - 7. FSRS 망각 곡선(R) · 초기 복습 주기 · 장기 안정성 성장 검증

    func testFSRSMathAndRetentionCurve() {
        let engine = FSRSEngine(desiredRetention: 0.90)
        let day1 = makeDate(2026, 11, 1)

        // t = S 일 때 기억 유지율 R은 정확히 0.90
        XCTAssertEqual(engine.retrievability(elapsedDays: 0.0, stability: 4.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(engine.retrievability(elapsedDays: 4.0, stability: 4.0), 0.90, accuracy: 1e-9)

        // 신규 졸업 등급별 초기 간격: 앎(1일) < 히든2(2일) < 쉬움(4일 이상)
        let g4 = engine.evaluateGraduation(previousState: nil, grade: .good, hadInterDayLapseToday: false, now: day1, calendar: fixedCalendar)
        let g5 = engine.evaluateGraduation(previousState: nil, grade: .hiddenNearEasy, hadInterDayLapseToday: false, now: day1, calendar: fixedCalendar)
        let g6 = engine.evaluateGraduation(previousState: nil, grade: .easy, hadInterDayLapseToday: false, now: day1, calendar: fixedCalendar)

        XCTAssertEqual(g4.scheduledIntervalDays, 1)
        XCTAssertEqual(g5.scheduledIntervalDays, 2)
        XCTAssertGreaterThanOrEqual(g6.scheduledIntervalDays, 4)

        // 다음 복습 도래일에 정상 인출 성공 시 안정성(S) 증가 검증
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

    // MARK: - 8. 당일 실패 면책 (Ease Hell 방지) 검증

    func testIntraSessionFailureImmunityPreventsEaseHell() {
        let store = InMemoryMemoryStore()
        let config = SessionConfiguration(newCardLimit: 10)
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.beer, .ramen], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: config,
            calendar: fixedCalendar
        )
        let today = makeDate(2026, 11, 1)
        session.startSession(words: [.beer, .ramen], now: today)

        // 1) 'ビール'는 첫 시도에 바로 '앎(4등급)'으로 졸업
        let outBeer = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.5, now: today)
        guard case .graduated(let beerSchedule, let beerPurified, _, _) = outBeer?.status else {
            return XCTFail("Expected immediate graduation for beer")
        }
        XCTAssertFalse(beerPurified)

        // 2) 'ラーメン'은 세션 내 6번 연속 '어려움(1등급)' 실패 후 7번째에 '앎(4등급)' 졸업
        for _ in 1...6 {
            let retryOut = session.submitEvaluation(button: .again, overrideElapsedSeconds: 8.0, now: today)
            guard case .requeued = retryOut?.status else {
                return XCTFail("Expected requeue during warm-up retries")
            }
        }
        let outRamen = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.5, now: today)
        guard case .graduated(let ramenSchedule, let ramenPurified, let ramenComeback, _) = outRamen?.status else {
            return XCTFail("Expected comeback graduation for ramen")
        }

        // 당일 실패 면책 검증: 6번 실패 후 졸업한 라멘도 장기 난이도(D) 페널티가 전혀 없음!
        XCTAssertEqual(ramenSchedule.updatedState.difficulty, beerSchedule.updatedState.difficulty, accuracy: 1e-9)
        XCTAssertEqual(ramenSchedule.updatedState.lapses, 0)
        XCTAssertTrue(ramenPurified)
        XCTAssertTrue(ramenComeback)
    }

    // MARK: - 9. 순환 큐 스마트 재투입 간격 검증 (어려움 앞쪽 · 애매함 중간 · 히든1 세션 말미)

    func testCircularQueueSmartOffsetsAndColorPurification() throws {
        let repo = try CatalogRepository.loadBundled()
        let store = InMemoryMemoryStore()
        let config = SessionConfiguration(
            againReinsertOffset: 2,
            hardReinsertOffset: 4
        )
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
        // 6.8초 '앎' → 히든1(힌트의존, 2등급) → 큐 맨 끝(인덱스 7)으로 이동
        let hintOutcome = try XCTUnwrap(
            session.submitEvaluation(button: .good, overrideElapsedSeconds: 6.8, now: today)
        )
        XCTAssertEqual(hintOutcome.grade, .hiddenHintAssisted)
        XCTAssertEqual(session.queue.last?.word.id, firstId)

        let secondId = session.queue[0].word.id
        // '어려움(1등급)' → 앞쪽 인덱스 2로 재투입 + 침식도 1 상승
        let againOutcome = try XCTUnwrap(
            session.submitEvaluation(button: .again, overrideElapsedSeconds: 4.0, now: today)
        )
        XCTAssertEqual(againOutcome.grade, .again)
        XCTAssertEqual(session.queue[2].word.id, secondId)
        XCTAssertEqual(session.queue[2].todayErosionCount, 1)

        let thirdId = session.queue[0].word.id
        // 3.0초 '애매함(3등급)' → 중간 인덱스 4로 재투입 + 침식도 상승 없음(0 유지)
        let hardOutcome = try XCTUnwrap(
            session.submitEvaluation(button: .hard, overrideElapsedSeconds: 3.0, now: today)
        )
        XCTAssertEqual(hardOutcome.grade, .hard)
        XCTAssertEqual(session.queue[4].word.id, thirdId)
        XCTAssertEqual(session.queue[4].todayErosionCount, 0)
    }

    // MARK: - 10. 당일 8회 조우 캡 & 서로 다른 날 3회 누적 보류 → 손글씨 처방 노트 분류 및 해금 검증

    func testEightStrikeCapAndThreeDistinctDayLeechPrescription() {
        let store = InMemoryMemoryStore()
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.uketamawaru], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: .standard,
            calendar: fixedCalendar
        )

        // Day 1: 8회 실패 → 8번째에 당일 세션 강제 종료 및 내일로 이관 (누적 1일)
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

        // 같은 날(Day 1) 세션을 다시 열어도 8회 캡에 걸린 단어는 재투입되지 않음
        session.startSession(words: [.uketamawaru], now: day1.addingTimeInterval(3600))
        XCTAssertTrue(session.queue.isEmpty)

        // Day 2: 수면 후 다음 날에는 정상 재진입 → 다시 8회 실패 시 누적 2일
        let day2 = makeDate(2026, 11, 2)
        session.startSession(words: [.uketamawaru], now: day2)
        XCTAssertEqual(session.queue.count, 1)
        for _ in 1...7 {
            _ = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day2)
        }
        let day2Cap = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day2)
        XCTAssertEqual(
            day2Cap?.status,
            .deferredByDailyCap(distinctDeferredDays: 2, prescribedToHandwritingNote: false)
        )

        // Day 3: 세 번째 다른 날에도 8회 실패 → 오프라인 손글씨 처방 노트로 자동 분류!
        let day3 = makeDate(2026, 11, 3)
        session.startSession(words: [.uketamawaru], now: day3)
        XCTAssertEqual(session.queue.count, 1)
        for _ in 1...7 {
            _ = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day3)
        }
        let day3Cap = session.submitEvaluation(button: .again, overrideElapsedSeconds: 5.0, now: day3)
        XCTAssertEqual(
            day3Cap?.status,
            .deferredByDailyCap(distinctDeferredDays: 3, prescribedToHandwritingNote: true)
        )
        XCTAssertEqual(session.prescribedLeechWords().map(\.id), ["n3_biz_uketamawaru"])

        // Day 4: 손글씨 처방 전에는 일반 세션에서 자동 제외, 손글씨 완수 시 정상 복귀
        let day4 = makeDate(2026, 11, 4)
        session.startSession(words: [.uketamawaru], now: day4)
        XCTAssertTrue(session.queue.isEmpty)

        let unlocked = session.completeHandwritingPrescription(for: "n3_biz_uketamawaru", now: day4)
        XCTAssertEqual(unlocked?.isLeechPrescribed, false)
        XCTAssertEqual(unlocked?.handwritingCompletedCount, 1)

        session.startSession(words: [.uketamawaru], now: day4)
        XCTAssertEqual(session.queue.count, 1)
    }

    // MARK: - 11. 졸업 보상 → 탭 2 SMS 미션 게임 티켓 발급 및 소비 검증

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

        // 1번째 단어 졸업: 아직 티켓 기준(2개) 미달
        let first = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.0, now: today)
        if case .graduated(_, _, _, let ticket1) = first?.status {
            XCTAssertNil(ticket1)
        } else {
            XCTFail("Expected graduation")
        }

        // 2번째 단어('乾杯', 이자카야 부장님) 졸업: SMS 게임 티켓 즉시 발급!
        let second = session.submitEvaluation(button: .easy, overrideElapsedSeconds: 2.0, now: today)
        guard case .graduated(_, _, _, let ticket2) = second?.status,
              let earnedTicket = ticket2 else {
            return XCTFail("Expected SMS game ticket on 2nd graduation")
        }

        XCTAssertEqual(earnedTicket.voiceId, "buchou")
        XCTAssertEqual(earnedTicket.targetWordIds, ["n5_food_beer", "n4_social_kanpai"])
        XCTAssertEqual(session.unconsumedGameTickets().count, 1)

        // 티켓 사용 처리
        let consumed = session.consumeGameTicket(id: earnedTicket.id)
        XCTAssertEqual(consumed?.isConsumed, true)
        XCTAssertTrue(session.unconsumedGameTickets().isEmpty)
    }

    // MARK: - 12. SwiftData 영구 저장소 라운드트립 검증

    func testSwiftDataMemoryStorePersistenceRoundTrip() throws {
        let container = try SwiftDataMemoryStore.makeContainer(inMemory: true)
        let store = SwiftDataMemoryStore(container: container)
        let config = SessionConfiguration(graduationsPerGameTicket: 1)
        let session = StudySessionEngine(
            catalog: CatalogRepository(words: [.beer], kanjiEntries: KanjiInfo.samples),
            store: store,
            configuration: config,
            calendar: fixedCalendar
        )

        let today = makeDate(2026, 11, 1)
        session.startSession(words: [.beer], now: today)
        _ = session.submitEvaluation(button: .good, overrideElapsedSeconds: 2.0, now: today)

        let savedSnapshot = try XCTUnwrap(store.snapshot(for: "n5_food_beer"))
        XCTAssertEqual(savedSnapshot.reps, 1)
        XCTAssertEqual(savedSnapshot.stability, 2.0, accuracy: 1e-9) // 2.0초 번개 반응 '앎' → 히든2(준-쉬움, S=2.0)

        let logs = store.allReviewLogs()
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.grade, .hiddenNearEasy)

        let tickets = store.allGameTickets()
        XCTAssertEqual(tickets.count, 1)
        XCTAssertEqual(tickets.first?.voiceId, "buchou")
    }

    // MARK: - 13. 일간 복습 카드 재학습 시 단일 망각 카운트 & 난이도 면책 검증

    func testInterDayReviewLapseCountsOnceAndProtectsDifficulty() {
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

        // 복습 당일 4번 틀린 뒤 5번째에 '앎(4등급)'으로 재졸업
        for _ in 1...4 {
            _ = session.submitEvaluation(button: .again, overrideElapsedSeconds: 6.0, now: reviewDay)
        }
        let outcome = session.submitEvaluation(button: .good, overrideElapsedSeconds: 3.2, now: reviewDay)

        guard case .graduated(let schedule, let didPurify, let isComeback, _) = outcome?.status else {
            return XCTFail("Expected relearning graduation")
        }

        // 4번 틀렸더라도 일간 망각(lapses)은 1회만 증가하고 난이도(D)는 상승하지 않음
        XCTAssertEqual(schedule.updatedState.lapses, 1)
        XCTAssertEqual(schedule.updatedState.difficulty, 5.2, accuracy: 1e-9)
        XCTAssertTrue(didPurify)
        XCTAssertTrue(isComeback)
    }

    // MARK: - 14. ContinuousClock 반응 타이머 일시정지 · 재개 · 정답 공개 잠금 검증

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

        // 백그라운드 전환 시뮬레이션: 일시정지 동안에는 경과 시간이 증가하지 않아야 함
        session.pauseReactionTimer()
        let pausedElapsed = session.currentElapsedSeconds()
        try await Task.sleep(for: .milliseconds(45))
        XCTAssertEqual(session.currentElapsedSeconds(), pausedElapsed, accuracy: 0.005)

        // 재개 후 '정답 보기' 클릭 시 해당 시점의 반응 시간이 고정 잠금됨
        session.resumeReactionTimer()
        try await Task.sleep(for: .milliseconds(25))
        let locked = session.markAnswerRevealed()
        XCTAssertGreaterThan(locked, pausedElapsed)

        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(session.currentElapsedSeconds(), locked, accuracy: 1e-9)
    }
}
