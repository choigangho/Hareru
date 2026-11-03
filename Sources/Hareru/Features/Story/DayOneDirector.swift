import Foundation
import Observation
import UserNotifications

// MARK: - 1일차 진행 (Docs/Story/lines/N5_D1.md)
// 대사표를 한 줄씩 넘기면서, 비고 칸의 지시 중 앱이 해야 하는 일(탭 이동 · 입력 · 분기 · 학습 대기)을
// 줄 ID에 묶어 처리합니다. 대사 문구는 전부 데이터(story_n5.json)에서 오고, 여기에는 진행 규칙만 둡니다.

/// 튜토리얼 카드 5장 (T-2). 학습 기록(FSRS)에는 남기지 않는 연습 카드
public struct TutorialCard: Equatable, Sendable {
    public let term: String
    public let reading: String
    public let meaning: String
    /// 공개 뒤 안다/모른다를 고르는 카드 (1번 はい는 공개만)
    public let asksAnswer: Bool

    static let dayOne: [TutorialCard] = [
        TutorialCard(term: "はい", reading: "はい", meaning: "네", asksAnswer: false),
        TutorialCard(term: "いいえ", reading: "いいえ", meaning: "아니요", asksAnswer: true),
        TutorialCard(term: "分かる", reading: "わかる", meaning: "알다", asksAnswer: true),
        TutorialCard(term: "見る", reading: "みる", meaning: "보다", asksAnswer: true),
        TutorialCard(term: "名前", reading: "なまえ", meaning: "이름", asksAnswer: true),
    ]
}

@MainActor
@Observable
public final class DayOneDirector {
    public enum Step: Equatable {
        case line
        case voicePick          // D1-029 목소리 고르기
        case nameInput          // D1-141 이름 입력
        case card(Int)          // 카드 공개 (· 안다/모른다)
        case quest(String)      // 퀘스트 버튼 (D1-312 · D1-704)
        case commuteInput       // D1-509 출근 시간
        case weatherSync        // D1-519 날씨 맞추기
        case talkChoice         // D1-609 스몰톡 선택지
        case studyGate          // T-8 학습 탭에서 15장
        case finished
    }

    public static let studyGoal = 15

    public private(set) var step: Step = .line
    public private(set) var index = 0
    /// 지금 화면에 올라와 있는 튜토리얼 카드 (0~4)
    public private(set) var activeCard: Int?
    public private(set) var tab: HareruMainTab = .game
    public private(set) var studiedInGate = 0

    public private(set) var playerName = ""
    public private(set) var voice: StoryVoice = .a
    public private(set) var commuteTime: Date?

    public let lines: [StoryLine]
    private let introEnd: Int
    private let defaults: UserDefaults
    private var resolvedGates: Set<String> = []
    private var answers: [Int: Bool] = [:]   // 카드 번호 → 안다
    private var weatherSynced = false
    private var talkChoice = 0
    private var profile: UserStudyProfile?

    public init(lines: [StoryLine]? = nil, defaults: UserDefaults = .standard) {
        let all = lines ?? StoryScript.chapter("D1").flatMap(\.lines)
        self.lines = all
        self.introEnd = all.firstIndex { $0.id == "D1-100" } ?? 0
        self.defaults = defaults
        restore()
    }

    // MARK: 상태

    /// 1일차를 끝냈는지 저장하는 키 (메인 화면이 @AppStorage로 지켜봄)
    public static let doneKey = Key.done

    public static func isFinished(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.done)
    }

    public var isFinished: Bool { step == .finished }
    public var current: StoryLine? { lines.indices.contains(index) ? lines[index] : nil }
    /// 인트로(T-0)는 검은 CRT 화면 위에서 진행
    public var isIntro: Bool { index < introEnd && step != .finished }
    public var card: TutorialCard? { activeCard.map { TutorialCard.dayOne[$0] } }
    /// 지금 카드를 이미 공개했는지 (공개 뒤 대사가 이어지는 동안 앞면 · 뒷면 유지)
    public var isCardRevealed: Bool {
        guard let activeCard else { return false }
        return resolvedGates.contains(Self.cardGateIDs[activeCard])
    }
    /// 그 카드에서 '안다'를 골랐는지 (見る → 「정답 보기」 자리에 글자가 스며듦)
    public var activeCardKnown: Bool { activeCard.flatMap { answers[$0] } ?? false }

    private static let cardGateIDs = ["D1-215", "D1-229", "D1-235", "D1-240", "D1-253"]
    public var sceneProgress: Double { lines.isEmpty ? 1 : Double(index) / Double(lines.count) }

    public func configure(profile: UserStudyProfile?) {
        self.profile = profile
    }

    // MARK: 진행

    public func start() {
        if lines.isEmpty { finish() }
    }

    public func advance() {
        guard step == .line else { return }
        move(to: index + 1)
    }

    public func skipIntro() {
        guard isIntro, let voiceLine = lines.firstIndex(where: { $0.id == "D1-027" }) else { return }
        move(to: voiceLine)
    }

    public func chooseVoice(_ picked: StoryVoice) {
        voice = picked
        continueAfterInteraction()
    }

    public func submitName(_ raw: String) {
        let name = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(8))
        guard !name.isEmpty else { return }
        playerName = name
        continueAfterInteraction()
    }

    /// 카드 공개 뒤 답 (1번 카드처럼 답이 없으면 nil)
    public func answerCard(knew: Bool?) {
        guard case let .card(number) = step else { return }
        if let knew { answers[number] = knew }
        if let id = current?.id { resolvedGates.insert(id) }
        move(to: index)
    }

    public func completeQuest() {
        continueAfterInteraction()
    }

    public func setCommute(_ time: Date?) {
        commuteTime = time
        if let time { Self.scheduleCommuteReminder(at: time) }
        continueAfterInteraction()
    }

    public func setWeatherSync(_ enabled: Bool) {
        weatherSynced = enabled
        continueAfterInteraction()
    }

    public func chooseTalk(_ option: Int) {
        talkChoice = option
        continueAfterInteraction()
    }

    /// 학습 탭에서 카드 하나를 평가할 때마다 (T-8)
    public func recordStudy(sessionCompleted: Bool) {
        guard step == .studyGate else { return }
        studiedInGate += 1
        save()
        if studiedInGate >= Self.studyGoal || sessionCompleted { move(to: index + 1) }
    }

    /// 오늘 카드가 15장보다 적어 먼저 끝난 경우
    public func studySessionEnded() {
        guard step == .studyGate else { return }
        move(to: index + 1)
    }

    /// 설정의 '1일차 다시 보기' — 저장된 진행을 지우면 메인 화면이 새 진행으로 다시 띄움
    public static func clearStoredProgress(defaults: UserDefaults = .standard) {
        for key in Key.all { defaults.removeObject(forKey: key) }
    }

    public func reset() {
        Self.clearStoredProgress(defaults: defaults)
        resolvedGates = []; answers = [:]; weatherSynced = false; talkChoice = 0
        studiedInGate = 0; activeCard = nil; commuteTime = nil; playerName = ""; voice = .a
        tab = .game; index = 0; step = .line
        move(to: 0)
    }

    // MARK: 문구

    /// `{이름}` 같은 변수 채우기
    public func fill(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "{이름}", with: playerName.isEmpty ? "신입" : playerName)
        if let profile {
            let calendar = Calendar.current
            let month = calendar.component(.month, from: profile.examDate)
            let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: profile.examDate)).day ?? 0)
            result = result
                .replacingOccurrences(of: "{시험}", with: "\(month)월")
                .replacingOccurrences(of: "{남은일}", with: "\(days)")
                .replacingOccurrences(of: "{목표}", with: profile.targetLevel.rawValue)
        }
        if let commuteTime {
            result = result.replacingOccurrences(of: "{출근}", with: commuteTime.formatted(date: .omitted, time: .shortened))
        }
        return result
    }

    /// 화자 칸에 보일 이름
    public func speakerTitle(_ line: StoryLine) -> String {
        switch line.kind {
        case .chief: return "주임 연구원"
        case .protagonist: return playerName.isEmpty ? "나" : playerName
        default: return line.speaker
        }
    }

    /// 시스템 줄 중 대사표에 문구가 없는 것은 화면 문구를 여기서 줌
    public func systemText(_ line: StoryLine) -> String {
        switch line.id {
        case "D1-163": return "NJL-OS 부팅 · 학습 단말 연결"
        case "D1-253": return "학습 종료 · 연구P +5"
        default: return fill(line.korean)
        }
    }

    // MARK: 진행 규칙

    private func continueAfterInteraction() {
        move(to: index + 1)
    }

    private func move(to target: Int) {
        var cursor = target
        while lines.indices.contains(cursor) {
            let line = lines[cursor]
            // 분기 줄(229 · 240)은 답을 알기 전엔 빠지는 줄이라, 포함 여부보다 먼저 카드를 세움
            if let number = cardGate(before: line.id), !resolvedGates.contains(line.id) {
                index = cursor
                step = .card(number)
                save()
                return
            }
            guard isIncluded(line) else { cursor += 1; continue }
            applyEffects(of: line)
            if let interaction = interaction(for: line) {
                index = cursor
                step = interaction
                save()
                return
            }
            if isSilent(line) { cursor += 1; continue }
            index = cursor
            step = .line
            save()
            return
        }
        finish()
    }

    private func finish() {
        index = lines.count
        step = .finished
        activeCard = nil
        defaults.set(true, forKey: Key.done)
        save()
    }

    private func number(_ id: String) -> Int {
        Int(id.split(separator: "-").last ?? "") ?? -1
    }

    /// 분기 (비고의 '〜한 경우' · 'N~M 대신')
    private func isIncluded(_ line: StoryLine) -> Bool {
        switch number(line.id) {
        case 229...231: return answers[1] == false
        case 232...233: return answers[1] == true
        case 240...245: return answers[3] == true
        case 328...333: return profile != nil
        case 510...512: return commuteTime != nil
        case 513...514: return commuteTime == nil
        case 520...522: return weatherSynced
        case 523: return !weatherSynced
        case 610...619: return talkChoice == 1
        case 620...628: return talkChoice == 2
        default: return true
        }
    }

    /// 카드를 공개해야 넘어갈 수 있는 줄 → 카드 번호
    private func cardGate(before id: String) -> Int? {
        Self.cardGateIDs.firstIndex(of: id)
    }

    private func applyEffects(of line: StoryLine) {
        switch line.id {
        case "D1-100", "D1-257", "D1-600", "D1-801": tab = .game
        case "D1-163": tab = .study
        case "D1-403": tab = .insights
        case "D1-500": tab = .settings
        case "D1-206": activeCard = 0
        case "D1-224": activeCard = 1
        case "D1-234": activeCard = 2
        case "D1-239": activeCard = 3
        case "D1-246": activeCard = 4
        case "D1-253": activeCard = nil
        case "D1-715": tab = .study
        default: break
        }
    }

    private func interaction(for line: StoryLine) -> Step? {
        switch line.id {
        case "D1-029": return .voicePick
        case "D1-141": return .nameInput
        case "D1-312": return .quest(line.korean)
        case "D1-509": return .commuteInput
        case "D1-519": return .weatherSync
        case "D1-609": return .talkChoice
        case "D1-704": return .quest(line.korean)
        case "D1-715": return .studyGate
        default: return nil
        }
    }

    /// 화면에 보일 문구가 없는 지시 줄 (탭 이동 · 카드 등장 등 — 효과만 적용하고 넘어감)
    private func isSilent(_ line: StoryLine) -> Bool {
        guard line.kind == .system else { return false }
        return systemText(line).isEmpty
    }

    // MARK: 알림

    private static func scheduleCommuteReminder(at time: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "国立言語遺産研究所"
            content.body = "출근 시간이에요. 주임 연구원이 기다리고 있어요."
            var parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            parts.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
            center.add(UNNotificationRequest(identifier: "hareru.commute", content: content, trigger: trigger))
        }
    }

    // MARK: 저장 (앱을 껐다 켜도 이어서)

    private enum Key {
        static let done = "story.d1.done"
        static let index = "story.d1.index"
        static let gates = "story.d1.gates"
        static let answers = "story.d1.answers"
        static let flags = "story.d1.flags"
        static let name = "story.playerName"
        static let voice = "story.voice"
        static let commute = "story.commute"
        static let studied = "story.d1.studied"
        static let all = [done, index, gates, answers, flags, name, voice, commute, studied]
    }

    private func save() {
        defaults.set(index, forKey: Key.index)
        defaults.set(Array(resolvedGates), forKey: Key.gates)
        defaults.set(Dictionary(uniqueKeysWithValues: answers.map { (String($0.key), $0.value) }), forKey: Key.answers)
        defaults.set([weatherSynced ? 1 : 0, talkChoice, activeCard ?? -1, tabCode], forKey: Key.flags)
        defaults.set(playerName, forKey: Key.name)
        defaults.set(voice.rawValue, forKey: Key.voice)
        defaults.set(commuteTime, forKey: Key.commute)
        defaults.set(studiedInGate, forKey: Key.studied)
    }

    private func restore() {
        if defaults.bool(forKey: Key.done) {
            index = lines.count
            step = .finished
            playerName = defaults.string(forKey: Key.name) ?? ""
            return
        }
        guard defaults.object(forKey: Key.index) != nil else { return }
        index = defaults.integer(forKey: Key.index)
        resolvedGates = Set(defaults.stringArray(forKey: Key.gates) ?? [])
        let stored = defaults.dictionary(forKey: Key.answers) as? [String: Bool] ?? [:]
        answers = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int(key).map { ($0, value) } })
        let flags = defaults.array(forKey: Key.flags) as? [Int] ?? []
        if flags.count == 4 {
            weatherSynced = flags[0] == 1
            talkChoice = flags[1]
            activeCard = flags[2] >= 0 ? flags[2] : nil
            tab = HareruMainTab.allCases.indices.contains(flags[3]) ? HareruMainTab.allCases[flags[3]] : .game
        }
        playerName = defaults.string(forKey: Key.name) ?? ""
        voice = StoryVoice(rawValue: defaults.string(forKey: Key.voice) ?? "a") ?? .a
        commuteTime = defaults.object(forKey: Key.commute) as? Date
        studiedInGate = defaults.integer(forKey: Key.studied)
        // 저장된 줄에서 단계(입력 · 카드 등)를 다시 계산
        move(to: index)
    }

    private var tabCode: Int { HareruMainTab.allCases.firstIndex(of: tab) ?? 1 }
}
