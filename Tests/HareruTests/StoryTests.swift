import XCTest
@testable import Hareru

@MainActor
final class StoryTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "story-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testDayOneLinesAreBundled() {
        let lines = StoryScript.chapter("D1").flatMap(\.lines)
        XCTAssertGreaterThan(lines.count, 300)
        XCTAssertEqual(lines.first?.id, "D1-000")
        XCTAssertEqual(lines.first { $0.id == "D1-106" }?.tone, "surprised")
    }

    func testRubySegments() {
        let segments = StoryRuby.segments("本当(ほんとう)に、来(き)たんですか?")
        XCTAssertEqual(segments.first, StoryRubySegment(base: "本当", ruby: "ほんとう"))
        XCTAssertEqual(StoryRuby.plain("お茶(ちゃ)、どうぞ。"), "お茶、どうぞ。")
    }

    /// 1일차를 끝까지 넘기며 분기 · 입력 · 학습 대기가 대사표 비고대로 작동하는지
    func testDayOnePlaysThroughWithBranches() {
        let defaults = freshDefaults()
        let director = DayOneDirector(defaults: defaults)
        var visited: [String] = []
        var tabs: [HareruMainTab] = []
        var guardCount = 0

        while !director.isFinished, guardCount < 2_000 {
            guardCount += 1
            if let id = director.current?.id, visited.last != id { visited.append(id) }
            if tabs.last != director.tab { tabs.append(director.tab) }
            switch director.step {
            case .line: director.advance()
            case .voicePick: director.chooseVoice(.b)
            case .nameInput: director.submitName("하루하루하루하루하루")
            case let .card(number): director.answerCard(knew: number == 0 ? nil : true)
            case .quest: director.completeQuest()
            case .commuteInput: director.setCommute(nil)
            case .weatherSync: director.setWeatherSync(false)
            case .talkChoice: director.chooseTalk(2)
            case .studyGate:
                for _ in 0..<DayOneDirector.studyGoal { director.recordStudy(sessionCompleted: false) }
            case .finished: break
            }
        }

        XCTAssertTrue(director.isFinished)
        XCTAssertTrue(DayOneDirector.isFinished(defaults: defaults))
        XCTAssertEqual(director.playerName, "하루하루하루하루", "이름은 8자까지")
        XCTAssertEqual(director.voice, .b)
        // '안다' 분기
        XCTAssertTrue(visited.contains("D1-232"))
        XCTAssertFalse(visited.contains("D1-230"))
        XCTAssertTrue(visited.contains("D1-241"))
        // 출근 '나중에' · 날씨 거절 · 스몰톡 ②
        XCTAssertTrue(visited.contains("D1-513"))
        XCTAssertFalse(visited.contains("D1-510"))
        XCTAssertTrue(visited.contains("D1-523"))
        XCTAssertTrue(visited.contains("D1-625"))
        XCTAssertFalse(visited.contains("D1-611"))
        // 프로필이 없으면 시험 이야기 생략
        XCTAssertFalse(visited.contains("D1-329"))
        // 탭: 연구소 → 학습 → 연구소 → 통계 → 설정 → 연구소 → 학습 → 연구소
        XCTAssertEqual(tabs, [.game, .study, .game, .insights, .settings, .game, .study, .game])
        XCTAssertTrue(visited.contains("D1-918"))
    }

    func testDayOneResumesAfterRelaunch() {
        let defaults = freshDefaults()
        let first = DayOneDirector(defaults: defaults)
        while first.step != .nameInput { first.step == .voicePick ? first.chooseVoice(.c) : first.advance() }
        first.submitName("하루")
        let resumeIndex = first.index

        let second = DayOneDirector(defaults: defaults)
        XCTAssertEqual(second.index, resumeIndex)
        XCTAssertEqual(second.playerName, "하루")
        XCTAssertEqual(second.voice, .c)
        XCTAssertEqual(second.fill("はじめまして。{이름}です。"), "はじめまして。하루です。")
    }

    func testSkipIntroAndClearProgress() {
        let defaults = freshDefaults()
        let director = DayOneDirector(defaults: defaults)
        director.skipIntro()
        XCTAssertEqual(director.current?.id, "D1-027")
        DayOneDirector.clearStoredProgress(defaults: defaults)
        XCTAssertFalse(DayOneDirector.isFinished(defaults: defaults))
    }
}
