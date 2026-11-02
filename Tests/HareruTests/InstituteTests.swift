import XCTest
@testable import Hareru

final class InstituteTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return cal
    }

    private func date(_ day: Int, hour: Int = 10) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone,
                       year: 2026, month: 11, day: day, hour: hour).date!
    }

    private func log(
        _ wordId: String, day: Int, hour: Int = 10, grade: EvaluationGrade = .good,
        graduated: Bool = true, priorStability: Double = 0, elapsedDays: Double? = nil
    ) -> ReviewLogEntry {
        ReviewLogEntry(
            wordId: wordId, reviewedAt: date(day, hour: hour), button: .good, grade: grade,
            reactionSeconds: 3, priorStability: priorStability,
            elapsedDaysSinceLastReview: elapsedDays, didGraduate: graduated, didHitDailyCap: false)
    }

    // MARK: - 연구 포인트 정산 규칙

    func testRewardsScoreMemoryQualityAndOnlyGraduatedRecalls() {
        // 처음 외움 10P
        XCTAssertEqual(ResearchRewardCalculator.points(for: log("a", day: 1))?.points, 10)
        // 외움 완료가 아니면 0 (보상 없음)
        XCTAssertNil(ResearchRewardCalculator.points(for: log("a", day: 1, grade: .again, graduated: false)))
        // 복습: 기본 6 + 안정도 7일 → +3 + 하루 이상 간격 → +2 = 11
        let review = ResearchRewardCalculator.points(for: log("a", day: 9, priorStability: 7, elapsedDays: 8))
        XCTAssertEqual(review?.kind, .review)
        XCTAssertEqual(review?.points, 11)
        // 오래 기억한 단어일수록 더 큼
        let longer = ResearchRewardCalculator.points(for: log("a", day: 9, priorStability: 30, elapsedDays: 8))!.points
        XCTAssertGreaterThan(longer, review!.points)
        // 빠르고 확실한 인출 +2
        XCTAssertEqual(ResearchRewardCalculator.points(for: log("b", day: 1, grade: .easy))?.points, 12)
    }

    func testSameWordSameDayIsRewardedOnceAndSettlingTwiceDoesNotPayAgain() {
        let logs = [
            log("a", day: 1, hour: 9),
            log("a", day: 1, hour: 15, grade: .easy),   // 같은 날 같은 단어 → 더 좋은 한 건만
            log("b", day: 1),
            log("a", day: 2, priorStability: 1, elapsedDays: 1)
        ]
        let engine = InstituteEngine()
        let first = engine.settle(logs: logs, now: date(2), calendar: calendar)
        XCTAssertEqual(first.rewards.count, 3)
        XCTAssertEqual(first.basePoints, 12 + 10 + (6 + 1 + 2))
        XCTAssertEqual(engine.state.researchPoints, first.gainedPoints)

        let second = engine.settle(logs: logs, now: date(2, hour: 20), calendar: calendar)
        XCTAssertTrue(second.rewards.isEmpty)
        XCTAssertEqual(second.budgetGranted, 0, "예산은 하루 한 번")
        XCTAssertEqual(engine.state.researchPoints, first.gainedPoints)
    }

    func testDailyBudgetGrowsWithInfluence() {
        let engine = InstituteEngine(store: InMemoryInstituteStore(state: InstituteState(restoredKanji: ["日", "本"])))
        let settlement = engine.settle(logs: [], now: date(3), calendar: calendar)
        XCTAssertEqual(settlement.budgetGranted, 50 + 10 * 2)
        XCTAssertEqual(engine.state.budget, InstituteState.startingBudget + 70)
    }

    // MARK: - 시설 배치 · 인접 콤보

    func testPlacementRulesAndAdjacentCombosOnly() {
        let engine = InstituteEngine(store: InMemoryInstituteStore(state: InstituteState(budget: 1_000)))
        let desk = InstituteState.deskPosition

        XCTAssertFalse(engine.canPlace(.researcherDesk, at: GridPosition(column: 4, row: 4)), "책상은 하나만")
        XCTAssertFalse(engine.canPlace(.kanjiArchive, at: desk), "이미 차 있는 칸")
        XCTAssertFalse(engine.canPlace(.kanjiArchive, at: GridPosition(column: 9, row: 0)), "격자 밖")
        XCTAssertFalse(engine.canPlace(.kanjiArchive, at: GridPosition(column: 3, row: 0)), "방 그림 속 고정 가구 칸")

        // 떨어뜨려 놓으면 콤보 없음
        XCTAssertTrue(engine.place(.kanjiArchive, at: GridPosition(column: 4, row: 4)))
        XCTAssertTrue(engine.activeCombos.isEmpty)
        XCTAssertEqual(engine.researchBonusPercent, 5)

        // 책상 바로 옆 서고 → 研究デスク, 서고 옆 필사실 → 写本工房
        XCTAssertTrue(engine.place(.kanjiArchive, at: GridPosition(column: desk.column, row: desk.row + 1)))
        XCTAssertTrue(engine.place(.copyRoom, at: GridPosition(column: desk.column, row: desk.row + 2)))
        XCTAssertEqual(Set(engine.activeCombos), [.researchCorner, .copyWorkshop])
        // 떨어져 있는 (4,4) 서고는 같은 종류여도 콤보 강조 대상이 아님
        let farArchive = engine.facility(at: GridPosition(column: 4, row: 4))!
        XCTAssertFalse(engine.comboMemberIDs.contains(farArchive.id))
        XCTAssertEqual(engine.comboMemberIDs.count, 3, "책상 · 옆 서고 · 필사실")
        XCTAssertEqual(engine.researchBonusPercent, 5 + 5 + 10)
        XCTAssertEqual(engine.restoreDiscountPercent, 10 + 20)
        XCTAssertEqual(engine.restoreCost, 21)

        XCTAssertFalse(engine.remove(at: desk), "책상은 철거 불가")
        let budgetBefore = engine.state.budget
        XCTAssertTrue(engine.remove(at: GridPosition(column: desk.column, row: desk.row + 2)))
        XCTAssertEqual(engine.state.budget, budgetBefore + FacilityKind.copyRoom.budgetCost / 2)
    }

    func testCannotPlaceWithoutBudget() {
        let engine = InstituteEngine(store: InMemoryInstituteStore(state: InstituteState(budget: 100)))
        XCTAssertFalse(engine.canPlace(.serverRack, at: GridPosition(column: 4, row: 4)))
        XCTAssertTrue(engine.place(.copyRoom, at: GridPosition(column: 4, row: 4)))
        XCTAssertEqual(engine.state.budget, 0)
    }

    // MARK: - 한자 복원

    func testOnlyKanjiFromLearnedWordsCanBeRestored() throws {
        let catalog = try CatalogRepository.loadBundled()
        let learned = try XCTUnwrap(catalog.words.first { $0.term == "現実" })
        var snapshot = WordMemorySnapshot(wordId: learned.id)
        snapshot.reps = 1

        let engine = InstituteEngine(store: InMemoryInstituteStore(state: InstituteState(researchPoints: 100)))
        XCTAssertTrue(engine.restorableKanji(catalog: catalog, snapshots: [:]).isEmpty, "외운 단어가 없으면 복원 불가")

        let restorable = engine.restorableKanji(catalog: catalog, snapshots: [learned.id: snapshot])
        XCTAssertEqual(restorable, ["現", "実"])
        XCTAssertFalse(engine.restore(kanji: "甘", catalog: catalog, snapshots: [learned.id: snapshot]))
        XCTAssertTrue(engine.restore(kanji: "現", catalog: catalog, snapshots: [learned.id: snapshot]))
        XCTAssertEqual(engine.state.researchPoints, 100 - InstituteEngine.baseRestoreCost)
        XCTAssertEqual(engine.restorableKanji(catalog: catalog, snapshots: [learned.id: snapshot]), ["実"])
        XCTAssertEqual(engine.state.influence, 1)
    }

    // MARK: - 저장소 분리

    func testStatePersistsInItsOwnFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("institute.json")
        let first = InstituteEngine(store: JSONFileInstituteStore(fileURL: url))
        XCTAssertTrue(first.place(.copyRoom, at: GridPosition(column: 4, row: 4)))
        first.markIntroSeen()

        let reloaded = InstituteEngine(store: JSONFileInstituteStore(fileURL: url))
        XCTAssertEqual(reloaded.state, first.state)
        XCTAssertTrue(reloaded.state.hasSeenIntro)
    }

    // MARK: - 아이소메트릭 격자 변환

    func testIsoGridRoundTripsEveryCellCenter() {
        let grid = IsoGrid(pixelScale: 3.7, origin: CGPoint(x: 200, y: 40))
        XCTAssertEqual(grid.pixelScale, 3, "정수 배율로 내림")
        XCTAssertEqual(grid.tileWidth, 96)
        XCTAssertEqual(grid.tileHeight, 48)
        for column in 0..<InstituteState.gridColumns {
            for row in 0..<InstituteState.gridRows {
                let hit = grid.cell(at: grid.center(column: column, row: row))
                XCTAssertEqual(hit.column, column)
                XCTAssertEqual(hit.row, row)
            }
        }
        // 격자 위쪽 바깥은 음수 칸
        XCTAssertLessThan(grid.cell(at: CGPoint(x: 200, y: 0)).row, 0)
    }

    // MARK: - 원내 방송 문구

    func testBroadcastReflectsSettlementRestorationAndSky() {
        let settlement = InstituteSettlement(rewards: [], basePoints: 20, bonusPercent: 10, gainedPoints: 22, budgetGranted: 50)
        let lines = InstituteBroadcast.lines(
            state: InstituteState(restoredKanji: ["甘"]),
            settlement: settlement, restorableCount: 3,
            activeCombos: [.researchCorner], realWeather: "서울 · 맑음 18°")

        XCTAssertTrue(lines.contains { $0.contains("+22") })
        XCTAssertTrue(lines.contains { $0.contains("+50") })
        XCTAssertTrue(lines.contains { $0.contains("복원 대기 문자 3자") })
        XCTAssertTrue(lines.contains { $0.contains("「甘」") })
        XCTAssertTrue(lines.contains { $0.contains(FacilityCombo.researchCorner.title) })
        XCTAssertTrue(lines.contains { $0.contains("강우") }, "영향력 1 → 연구소 하늘 비")
        XCTAssertTrue(lines.last?.contains("서울") == true)

        let quiet = InstituteBroadcast.lines(state: InstituteState(), settlement: nil, restorableCount: 0,
                                             activeCombos: [], realWeather: "서울")
        XCTAssertFalse(quiet.contains { $0.contains("研究P +") }, "정산이 없으면 정산 문구 없음")
        XCTAssertTrue(quiet.contains { $0.contains("복원 대기 문자가 없습니다") })
    }
}
