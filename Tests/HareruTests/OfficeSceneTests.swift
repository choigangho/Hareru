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
        // 방은 Pixellab으로 격자를 되찾은 그림 한 장 (그림 1픽셀 = 아트 픽셀 1칸), 시설은 에셋 밀도(방 픽셀 1칸 = 2칸)
        let density = CGFloat(OfficePixelArt.assetDensity)
        XCTAssertTrue(OfficePixelArt.usesStageRoom, "room_stage1.png가 번들에 있어야 함")
        XCTAssertEqual(room.size(), CGSize(width: 381, height: 244))
        XCTAssertEqual(room.size(), CGSize(width: CGFloat(OfficePixelArt.roomSize.width), height: CGFloat(OfficePixelArt.roomSize.height)))

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
        XCTAssertEqual(scene.pixelScale, 2, "기본은 확대 2배율")
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
        let near = PlacedFacility(kind: .serverRack, position: GridPosition(column: 4, row: 4))
        let far = PlacedFacility(kind: .kanjiArchive, position: GridPosition(column: 1, row: 3))
        state.facilities += [near, far]
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)

        XCTAssertEqual(scene.facilityNodeCount, 4, "책상 2개 + 시설 2개")
        XCTAssertGreaterThan(scene.zPosition(ofFacility: near.id)!, scene.zPosition(ofFacility: far.id)!,
                             "앞쪽(행+열이 큰) 시설이 뒤쪽 시설을 가려야 함")

        state.facilities.removeAll { $0.id == far.id }
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        XCTAssertEqual(scene.facilityNodeCount, 3)
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

    func testCastSpritesAreBundledForEveryVoiceCharacterButRin() {
        // 카자마 린(courier_rin)은 시트를 아직 받지 못함 — 들어오면 이 예외를 지울 것
        for id in OfficePixelArt.castVoiceIDs where id != "courier_rin" {
            XCTAssertNotNil(OfficePixelArt.characterFrames(voiceID: id), "\(id) 스프라이트 4장이 번들에 있어야 함")
        }
        XCTAssertTrue(Set(OfficePixelArt.castVoiceIDs).isSubset(of: Set(VoiceProfile.gameCast.map(\.id))))
    }

    func testStageRoomHidesTheBuiltInDeskAndBlocksFixedFurniture() throws {
        let state = InstituteState()
        let scene = makeScene(facilities: state.facilities)
        scene.apply(state: state, comboMemberIDs: [], selectedCell: nil, isPlacing: false)
        let desk = try XCTUnwrap(state.facilities.first { $0.kind == .researcherDesk })
        XCTAssertEqual(scene.isFacilityHidden(desk.id), true, "큰 책상은 방 그림 속에 이미 그려져 있음")
        let trainee = try XCTUnwrap(state.facilities.first { $0.kind == .traineeDesk })
        XCTAssertEqual(scene.isFacilityHidden(trainee.id), false)
        XCTAssertFalse(InstituteState.fixedCells.contains(trainee.position))
        XCTAssertTrue(InstituteState.fixedCells.contains(desk.position))
        XCTAssertTrue(OfficePixelArt.decorPlacements.isEmpty, "소품은 방 그림에 포함됨")
    }

    func testZoomSnapsToIntegerLevelsAndKeepsTheAnchorPoint() throws {
        let scene = makeScene(facilities: InstituteState().facilities)
        XCTAssertEqual(scene.zoomLevel, OfficeScene.defaultZoom)
        let anchor = CGPoint(x: 120, y: 160)
        let before = try XCTUnwrap(scene.grid)
        let artX = (anchor.x - before.origin.x) / before.pixelScale
        scene.setZoom(3, anchor: anchor)
        let after = try XCTUnwrap(scene.grid)
        XCTAssertEqual(after.pixelScale, 3)
        XCTAssertEqual((anchor.x - after.origin.x) / after.pixelScale, artX, accuracy: 0.01, "손가락 아래 그림 지점이 그대로")

        scene.setZoom(99)
        XCTAssertEqual(scene.zoomLevel, OfficeScene.zoomLevels.upperBound)
        scene.setZoom(-5)
        XCTAssertEqual(scene.zoomLevel, OfficeScene.zoomLevels.lowerBound)
        scene.resetView()
        XCTAssertEqual(scene.zoomLevel, OfficeScene.defaultZoom)
    }

    func testPanIsClampedSoTheRoomNeverLeavesTheScreen() throws {
        let scene = makeScene(facilities: InstituteState().facilities)
        scene.setZoom(4)
        scene.pan(by: CGPoint(x: 9_999, y: 9_999))
        let topLeft = try XCTUnwrap(scene.grid).origin
        let art = OfficePixelArt.roomSize
        let origin = OfficePixelArt.roomGridOrigin
        XCTAssertLessThanOrEqual(topLeft.x - origin.x * 4, 0.001, "왼쪽/위 가장자리가 화면 안으로 들어오지 않음")
        XCTAssertLessThanOrEqual(topLeft.y - origin.y * 4, 0.001)
        scene.pan(by: CGPoint(x: -99_999, y: -99_999))
        let moved = try XCTUnwrap(scene.grid).origin
        XCTAssertGreaterThanOrEqual(moved.x - origin.x * 4 + CGFloat(art.width) * 4, scene.size.width - 0.001)
        XCTAssertGreaterThanOrEqual(moved.y - origin.y * 4 + CGFloat(art.height) * 4, scene.size.height - 0.001)
    }

    func testOldSavesAreMigratedOffFixedFurniture() throws {
        // 예전 저장: 주임 책상이 옮겨져 있고, 시설이 그림 속 고정 가구 칸(0,0)에 있음
        var old = InstituteState()
        old.facilities = [PlacedFacility(kind: .researcherDesk, position: GridPosition(column: 0, row: 0)),
                          PlacedFacility(kind: .kanjiArchive, position: GridPosition(column: 0, row: 0))]
        let data = try JSONEncoder().encode(old)
        let loaded = try JSONDecoder().decode(InstituteState.self, from: data)
        XCTAssertEqual(loaded.facilities.first { $0.kind == .researcherDesk }?.position, InstituteState.deskPosition)
        let archive = try XCTUnwrap(loaded.facilities.first { $0.kind == .kanjiArchive })
        XCTAssertFalse(InstituteState.fixedCells.contains(archive.position))
        XCTAssertTrue(loaded.facilities.contains { $0.kind == .traineeDesk })
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
        state.facilities += [PlacedFacility(kind: .kanjiArchive, position: GridPosition(column: 1, row: 4)),
                             PlacedFacility(kind: .serverRack, position: GridPosition(column: 4, row: 4))]
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
