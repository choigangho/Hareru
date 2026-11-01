import XCTest
import SpriteKit
@testable import Hareru

final class OfficeSceneTests: XCTestCase {

    private func makeScene(size: CGSize = CGSize(width: 402, height: 420), facilities: [PlacedFacility]) -> OfficeScene {
        let runtime = OfficeSimulationRuntime(facilities: facilities, seed: 1)
        let scene = OfficeScene(runtime: runtime)
        scene.size = size
        return scene
    }

    func testTexturesArePixelCrispAtArtResolution() {
        let room = OfficePixelArt.makeRoom()
        XCTAssertEqual(room.filteringMode, .nearest)
        // 방·시설 텍스처는 에셋 밀도(방 픽셀 1칸 = 2칸)로 그림
        let density = CGFloat(OfficePixelArt.assetDensity)
        XCTAssertEqual(room.size(), CGSize(width: CGFloat(OfficePixelArt.roomSize.width) * density,
                                           height: CGFloat(OfficePixelArt.roomSize.height) * density))

        for kind in FacilityKind.allCases {
            let texture = OfficePixelArt.makeFacility(kind, highlighted: true)
            let expected = OfficePixelArt.facilitySize(kind)
            XCTAssertEqual(texture.filteringMode, .nearest)
            XCTAssertEqual(texture.size(), CGSize(width: CGFloat(expected.width) * density, height: CGFloat(expected.height) * density),
                           "\(kind) 시설 에셋을 번들에서 못 찾았거나 크기가 어긋남")
        }
        XCTAssertEqual(OfficePixelArt.makeGuide(frame: 1).size(), CGSize(width: 8, height: 14))

        // 두 사람의 캐릭터 에셋이 번들에 들어 있고, 48×48 아트 해상도 + 최근접 필터링
        for role in [ResearcherAgent.Role.chief, .newcomer] {
            let frames = OfficePixelArt.characterFrames(role)
            XCTAssertEqual(frames.artSize, CGSize(width: 48, height: 48), "\(role) 에셋을 번들에서 못 찾음")
            for texture in [frames.idleFront, frames.back] + frames.walkFront {
                XCTAssertEqual(texture.size(), CGSize(width: 48, height: 48))
                XCTAssertEqual(texture.filteringMode, .nearest)
            }
        }
        XCTAssertEqual(OfficePixelArt.guidePortrait()?.width, 64, "대화 초상화는 64×64 에셋")
    }

    func testLayoutUsesIntegerScaleAndTapsMapToCells() throws {
        let scene = makeScene(facilities: InstituteState().facilities)
        let grid = try XCTUnwrap(scene.grid)
        XCTAssertEqual(scene.pixelScale, 2, "402pt 폭 → 정수 2배율")
        XCTAssertEqual(grid.pixelScale.truncatingRemainder(dividingBy: 1), 0)

        for column in 0..<InstituteState.gridColumns {
            for row in 0..<InstituteState.gridRows {
                XCTAssertEqual(scene.cell(atViewPoint: grid.center(column: column, row: row)),
                               GridPosition(column: column, row: row))
            }
        }
        XCTAssertNil(scene.cell(atViewPoint: CGPoint(x: 2, y: 2)), "격자 밖")
    }

    func testFacilityNodesFollowStateAndDepthOrder() {
        var state = InstituteState(budget: 1_000)
        let scene = makeScene(facilities: state.facilities)
        let near = PlacedFacility(kind: .serverRack, position: GridPosition(column: 5, row: 5))
        let far = PlacedFacility(kind: .kanjiArchive, position: GridPosition(column: 0, row: 0))
        state.facilities += [near, far]
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)

        XCTAssertEqual(scene.facilityNodeCount, 3)
        XCTAssertGreaterThan(scene.zPosition(ofFacility: near.id)!, scene.zPosition(ofFacility: far.id)!,
                             "앞쪽(행+열이 큰) 시설이 뒤쪽 시설을 가려야 함")

        state.facilities.removeAll { $0.id == far.id }
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        XCTAssertEqual(scene.facilityNodeCount, 2)
        XCTAssertNil(scene.zPosition(ofFacility: far.id))
    }

    func testResearcherIsDrawnInFrontOfTheDeskWhileStandingAtIt() {
        let state = InstituteState()
        let scene = makeScene(facilities: state.facilities)
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        scene.update(0)
        let desk = state.facilities.first { $0.kind == .researcherDesk }!
        XCTAssertGreaterThan(scene.agentZPosition, scene.zPosition(ofFacility: desk.id)!)
    }

    func testInstituteStartsWithTwoPeopleAtSeparateSpots() {
        let state = InstituteState()
        let scene = makeScene(facilities: state.facilities)
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        scene.update(0)
        XCTAssertTrue(scene.isNewcomerVisible, "신입(플레이어)도 처음부터 사무실에 있어야 함")
        XCTAssertNotEqual(scene.runtime.agent.tile, scene.runtime.newcomer.tile, "두 사람은 다른 칸에서 시작")
        XCTAssertEqual(scene.runtime.newcomer.role, .newcomer)
        let desk = state.facilities.first { $0.kind == .researcherDesk }!
        XCTAssertGreaterThan(scene.newcomerZPosition, scene.zPosition(ofFacility: desk.id)!)
    }

    func testDecorPropsHideUnderPlacedFacilities() {
        var state = InstituteState()
        let scene = makeScene(facilities: state.facilities)
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        XCTAssertEqual(scene.visibleDecorCells.count, OfficePixelArt.decorPlacements.count, "소품 에셋 5종이 번들에 있어야 함")
        let spot = OfficePixelArt.decorPlacements[0].cell
        state.facilities.append(PlacedFacility(kind: .kanjiArchive, position: spot))
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        XCTAssertFalse(scene.visibleDecorCells.contains(spot), "시설이 놓인 칸의 소품은 숨김")
    }

    func testInWorldCalendarKeepsYearSecret() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let date = DateComponents(calendar: calendar, year: 2026, month: 11, day: 1, hour: 12).date!
        XCTAssertEqual(InstituteView.inWorldDate(date, calendar: calendar), "2XXX年 11月 1日 (日)")
    }

    func testSpritesAreScaledExactlyOnceEvenWhenMirrored() {
        var state = InstituteState()
        // 양쪽 끝에 시설을 둬서 연구원이 좌우로 오가며 반전되게 함
        state.facilities += [PlacedFacility(kind: .kanjiArchive, position: GridPosition(column: 0, row: 4)),
                             PlacedFacility(kind: .serverRack, position: GridPosition(column: 5, row: 0))]
        let scene = makeScene(facilities: state.facilities)
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        let side = 48 * OfficePixelArt.characterPixelRatio * scene.pixelScale
        let expectedAgent = CGSize(width: side, height: side)

        // 실제 시간으로 흐르는 런타임을 앞당기기 위해 프레임마다 잠깐씩 기다리는 대신, 런타임을 직접 진행
        var facings = Set<Bool>()
        let start = Date().timeIntervalSinceReferenceDate
        for frame in 0..<3_000 {
            scene.runtime.update(time: start + Double(frame) / 30, facilities: state.facilities)
            scene.update(0)
            facings.insert(scene.runtime.agent.facingRight)
            XCTAssertEqual(scene.agentRenderedSize, expectedAgent)
            XCTAssertEqual(scene.newcomerRenderedSize, expectedAgent)
        }
        XCTAssertEqual(facings, [true, false], "좌우 반전이 실제로 일어나야 의미 있는 검사")
        let desk = state.facilities[0]
        let art = OfficePixelArt.facilitySize(.researcherDesk)
        XCTAssertEqual(scene.facilityRenderedSize(desk.id),
                       CGSize(width: CGFloat(art.width) * scene.pixelScale, height: CGFloat(art.height) * scene.pixelScale))
    }
}
