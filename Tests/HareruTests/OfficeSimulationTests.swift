import XCTest
@testable import Hareru

final class OfficeSimulationTests: XCTestCase {

    private func facilities(_ items: [(FacilityKind, Int, Int)]) -> [PlacedFacility] {
        [PlacedFacility(kind: .researcherDesk, position: InstituteState.deskPosition)]
            + items.map { PlacedFacility(kind: $0.0, position: GridPosition(column: $0.1, row: $0.2)) }
    }

    // MARK: - 길찾기

    func testPathfinderWalksAroundFacilities() throws {
        // 책상 앞 빈 바닥(행 3~5)에서, 가운데 시설 하나(3,3)를 돌아가는 길
        let placed = facilities([(.kanjiArchive, 3, 3)])
        let start = GridPosition(column: 2, row: 3)
        let goal = GridPosition(column: 4, row: 3)
        let route = try XCTUnwrap(OfficePathfinder.path(from: start, toAnyOf: [goal], facilities: placed))

        XCTAssertEqual(route.last, goal)
        XCTAssertTrue(route.allSatisfy { OfficePathfinder.isWalkable($0, facilities: placed) }, "시설 칸을 지나면 안 됨")
        var previous = start
        for step in route {
            XCTAssertTrue(step.isAdjacent(to: previous), "한 칸씩 이동")
            previous = step
        }
        // 시설을 아래로 돌아가는 최단 경로: (2,4) → (3,4) → (4,4) → (4,3)  (위쪽 행 2는 방 그림의 큰 책상이라 못 지남)
        XCTAssertEqual(route.count, 4)
    }

    func testPathfinderReturnsNilWhenBlockedAndEmptyWhenAlreadyThere() {
        let placed = facilities([])
        let here = GridPosition(column: 0, row: 0)
        XCTAssertEqual(OfficePathfinder.path(from: here, toAnyOf: [here], facilities: placed), [])
        XCTAssertNil(OfficePathfinder.path(from: here, toAnyOf: [InstituteState.deskPosition], facilities: placed),
                     "시설 칸 자체는 목적지가 될 수 없음")
    }

    func testDeskSpotFallsBackWhenFrontIsBlocked() {
        let front = GridPosition(column: InstituteState.deskPosition.column, row: InstituteState.deskPosition.row + 1)
        XCTAssertEqual(OfficePathfinder.deskSpot(facilities: facilities([])), front)
        let blocked = facilities([(.serverRack, front.column, front.row)])
        let spot = OfficePathfinder.deskSpot(facilities: blocked)
        XCTAssertNotNil(spot)
        XCTAssertNotEqual(spot, front)
        XCTAssertTrue(OfficePathfinder.isWalkable(spot!, facilities: blocked), "책상 둘레가 다 막히면 가장 가까운 빈 칸")
    }

    // MARK: - 연구원 자율 행동

    func testAgentVisitsFacilitiesAndNeverStandsOnOne() {
        let placed = facilities([(.kanjiArchive, 1, 3), (.recordingBooth, 3, 5), (.copyRoom, 4, 4)])
        var agent = ResearcherAgent(tile: OfficePathfinder.deskSpot(facilities: placed)!, idleSeconds: 0.1)
        var rng = SeededRandom(seed: 42)
        var visited = Set<FacilityKind>()
        for _ in 0..<6_000 {   // 1/30초 × 6000 = 200초
            if let kind = agent.step(dt: 1.0 / 30, facilities: placed, rng: &rng) {
                visited.insert(kind)
            }
            XCTAssertTrue(OfficePathfinder.isWalkable(agent.tile, facilities: placed), "시설 위에 서면 안 됨: \(agent.tile)")
        }
        XCTAssertEqual(visited, [.kanjiArchive, .recordingBooth, .copyRoom])
    }

    func testAgentStaysAtDeskWhenNoOtherFacilities() {
        let placed = facilities([])
        let desk = OfficePathfinder.deskSpot(facilities: placed)!
        var agent = ResearcherAgent(tile: desk, idleSeconds: 0.1)
        var rng = SeededRandom(seed: 1)
        for _ in 0..<600 { agent.step(dt: 0.1, facilities: placed, rng: &rng) }
        XCTAssertEqual(agent.tile, desk)
    }

    func testAgentRecoversWhenFacilityIsPlacedOnItsTile() {
        let desk = OfficePathfinder.deskSpot(facilities: facilities([]))!
        var agent = ResearcherAgent(tile: desk)
        let blocked = facilities([(.serverRack, desk.column, desk.row)])
        agent.recover(facilities: blocked)
        XCTAssertTrue(OfficePathfinder.isWalkable(agent.tile, facilities: blocked))
    }

    // MARK: - 복원 연출: 결과는 엔진에서 즉시 확정, 연출은 보여 주기만

    func testRestorationIsCommittedBeforeShowAndSurvivesLosingTheRuntime() throws {
        let catalog = try CatalogRepository.loadBundled()
        let word = try XCTUnwrap(catalog.words.first { $0.term == "現実" })
        var snapshot = WordMemorySnapshot(wordId: word.id)
        snapshot.reps = 1
        snapshot.stability = 5
        let snapshots = [word.id: snapshot]

        let store = InMemoryInstituteStore(state: InstituteState(researchPoints: 100))
        let engine = InstituteEngine(store: store)
        var runtime: OfficeSimulationRuntime? = OfficeSimulationRuntime(facilities: engine.state.facilities, seed: 7)

        XCTAssertTrue(engine.restore(kanji: "現", catalog: catalog, snapshots: snapshots))
        runtime?.startRestoration(RestorationInsight(kanji: "現", catalog: catalog, snapshots: snapshots), time: 0)
        runtime?.update(time: 0.05, facilities: engine.state.facilities)
        XCTAssertEqual(runtime?.isShowingRestoration, true)

        // 연출 도중 탭 이동 · 앱 종료 → 런타임이 사라져도
        runtime = nil
        let reloaded = InstituteEngine(store: store)
        XCTAssertEqual(reloaded.state.restoredKanji, ["現"])
        XCTAssertEqual(reloaded.state.researchPoints, 100 - InstituteEngine.baseRestoreCost)
    }

    func testRestorationShowEmitsBubblesFromRealLearningDataAndCanBeSkipped() throws {
        let catalog = try CatalogRepository.loadBundled()
        let word = try XCTUnwrap(catalog.words.first { $0.term == "現実" })   // 現 = 음독 げん
        var snapshot = WordMemorySnapshot(wordId: word.id)
        snapshot.reps = 1
        snapshot.stability = 5
        let insight = RestorationInsight(kanji: "現", catalog: catalog, snapshots: [word.id: snapshot])

        XCTAssertTrue(insight.knowsOnReading)
        XCTAssertFalse(insight.knowsKunReading)
        XCTAssertEqual(insight.learnedWordCount, 1)
        XCTAssertTrue(insight.isCritical)
        XCTAssertEqual(insight.bubbleTexts.first, "+音")
        XCTAssertFalse(insight.bubbleTexts.contains("+訓"), "외우지 않은 읽기는 버블로 나오지 않음")

        let runtime = OfficeSimulationRuntime(facilities: InstituteState().facilities, seed: 3)
        runtime.startRestoration(insight, time: 0)
        var time = 0.0
        while time < 2.0 {
            time += 1.0 / 30
            runtime.update(time: time, facilities: InstituteState().facilities)
        }
        XCTAssertTrue(runtime.bubbles.contains { $0.style == .stat })
        XCTAssertTrue(runtime.bubbles.contains { $0.style == .critical })

        runtime.skipRestoration(time: time)
        XCTAssertFalse(runtime.isShowingRestoration)
        XCTAssertTrue(runtime.bubbles.contains { $0.style == .done })
    }

    func testBubblesExpireAndAreCapped() {
        let runtime = OfficeSimulationRuntime(facilities: InstituteState().facilities, seed: 9)
        let settlement = InstituteSettlement(rewards: [], basePoints: 10, bonusPercent: 0, gainedPoints: 10, budgetGranted: 50)
        for i in 0..<40 {
            runtime.emitSettlement(settlement, time: Double(i) * 0.01)
        }
        XCTAssertLessThanOrEqual(runtime.bubbles.count, OfficeSimulationRuntime.maxBubbles)
        runtime.update(time: 10, facilities: InstituteState().facilities)
        XCTAssertTrue(runtime.bubbles.isEmpty)
    }

    func testHeadingFollowsIsometricScreenDirections() {
        let o = GridPosition(column: 2, row: 2)
        XCTAssertEqual(ResearcherAgent.Heading(from: o, to: GridPosition(column: 3, row: 2)), .southeast)
        XCTAssertEqual(ResearcherAgent.Heading(from: o, to: GridPosition(column: 1, row: 2)), .northwest)
        XCTAssertEqual(ResearcherAgent.Heading(from: o, to: GridPosition(column: 2, row: 3)), .southwest)
        XCTAssertEqual(ResearcherAgent.Heading(from: o, to: GridPosition(column: 2, row: 1)), .northeast)
        // 스프라이트는 남동(앞)·북서(뒤) 두 장 → 남서·북동만 반전
        XCTAssertTrue(ResearcherAgent.Heading.southwest.showsFront && ResearcherAgent.Heading.southwest.isMirrored)
        XCTAssertTrue(!ResearcherAgent.Heading.northeast.showsFront && ResearcherAgent.Heading.northeast.isMirrored)
    }

    func testNewcomerHasOwnHomeSpotEvenWhenPreferredIsBlocked() {
        let desk = InstituteState.deskPosition
        let base = [PlacedFacility(kind: .researcherDesk, position: desk)]
        let chief = OfficePathfinder.homeSpot(for: .chief, facilities: base)
        let newcomer = OfficePathfinder.homeSpot(for: .newcomer, facilities: base)
        XCTAssertEqual(chief, GridPosition(column: desk.column, row: desk.row + 1))
        XCTAssertNotNil(newcomer)
        XCTAssertNotEqual(chief, newcomer, "신입 책상이 없어도 두 사람은 다른 칸")

        let blocked = base + [PlacedFacility(kind: .serverRack, position: newcomer!)]
        let fallback = OfficePathfinder.homeSpot(for: .newcomer, facilities: blocked)
        XCTAssertNotNil(fallback)
        XCTAssertNotEqual(fallback, OfficePathfinder.homeSpot(for: .chief, facilities: blocked))
    }
}
