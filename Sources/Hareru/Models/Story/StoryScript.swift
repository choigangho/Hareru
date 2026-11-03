import Foundation

// MARK: - 대사 데이터 (Docs/Story/lines/N5_*.md → Tools/export_story.py → Resources/Data/story_n5.json)
// 한 줄 = 대사 한 줄. 화자 · 표정 · 일본어 · 한국어 · 비고는 대사표 열 그대로.

public struct StoryLine: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let speaker: String
    public let expression: String
    public let japanese: String
    public let korean: String
    public let note: String
    public let tone: String

    public var kind: StorySpeakerKind { StorySpeakerKind(speaker) }

    /// `D1-106` → `story_d1_106` (주인공 줄은 목소리 접미사 `_a` · `_b` · `_c`)
    public func audioFileName(voice: StoryVoice) -> String {
        let stem = "story_" + id.lowercased().replacingOccurrences(of: "-", with: "_")
        return kind == .protagonist ? "\(stem)_\(voice.rawValue)" : stem
    }

    /// 비고에 '확대'가 있으면 얼굴을 화면 가득 (개그 · 감정 정점)
    public var isCloseUp: Bool { note.contains("확대") }
}

public struct StoryScene: Codable, Equatable, Sendable {
    public let title: String
    public let lines: [StoryLine]
}

public enum StorySpeakerKind: Equatable, Sendable {
    case chief, protagonist, kuro, gen, mio
    case typewriter     // 타자 — 인트로 타이핑
    case monologue      // 독백 — 주인공 속마음, 음성 없음
    case direction      // 연출 — 대사 없는 컷
    case system         // 시스템 — UI 문구
    case input          // 입력 — 입력창
    case choice         // 선택 — 선택지
    case other(String)

    init(_ raw: String) {
        switch raw {
        case "주임": self = .chief
        case "주인공": self = .protagonist
        case "KURO": self = .kuro
        case "겐": self = .gen
        case "미오": self = .mio
        case "타자": self = .typewriter
        case "독백": self = .monologue
        case "연출": self = .direction
        case "시스템": self = .system
        case "입력": self = .input
        case "선택": self = .choice
        default: self = .other(raw)
        }
    }

    /// 초상이 있는 인물 (지금은 주임 · 주인공만 그림이 있음)
    public var portraitName: String? {
        switch self {
        case .chief: return "chief_researcher_portrait"
        case .protagonist: return "newcomer_portrait"
        default: return nil
        }
    }
}

/// 주인공 목소리 (남성 3종 — 1일차 문 앞에서 고름)
public enum StoryVoice: String, CaseIterable, Codable, Sendable {
    case a, b, c

    public var title: String { "목소리 \(rawValue.uppercased())" }
}

public enum StoryScript {
    /// 묶음 이름(`D1` · `B1` …) → 장면 목록
    public static func chapter(_ name: String, bundle: Bundle? = nil) -> [StoryScene] {
        struct File: Decodable { let chapters: [String: [StoryScene]] }
        let bundles = bundle.map { [$0] } ?? [Bundle.module, Bundle.main]
        for candidate in bundles {
            guard let url = candidate.url(forResource: "story_n5", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder().decode(File.self, from: data) else { continue }
            return file.chapters[name] ?? []
        }
        return []
    }
}

// MARK: - 일본어 대사의 `漢字(かな)` 표기 → 루비 조각

public struct StoryRubySegment: Equatable, Sendable {
    public let base: String
    public let ruby: String?
}

public enum StoryRuby {
    /// `本当(ほんとう)に` → [本当/ほんとう, に]. 괄호 바로 앞의 한자 묶음에만 루비를 얹음
    public static func segments(_ text: String) -> [StoryRubySegment] {
        var result: [StoryRubySegment] = []
        var plain = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if (ch == "(" || ch == "（"), let close = chars[i...].firstIndex(where: { $0 == ")" || $0 == "）" }) {
                let reading = String(chars[(i + 1)..<close])
                let kanjiRun = String(plain.reversed().prefix { JapaneseScript.isKanji($0) }.reversed())
                if !kanjiRun.isEmpty, !reading.isEmpty {
                    plain.removeLast(kanjiRun.count)
                    if !plain.isEmpty { result.append(StoryRubySegment(base: plain, ruby: nil)) }
                    plain = ""
                    result.append(StoryRubySegment(base: kanjiRun, ruby: reading))
                    i = close + 1
                    continue
                }
            }
            plain.append(ch)
            i += 1
        }
        if !plain.isEmpty { result.append(StoryRubySegment(base: plain, ruby: nil)) }
        return result
    }

    /// 루비를 뺀 본문 (`本当に`)
    public static func plain(_ text: String) -> String {
        segments(text).map(\.base).joined()
    }
}
