import Foundation

// MARK: - 한자 발음 유형 (음독 / 훈독 / 숙자훈)
public enum KanjiReadingType: String, Codable, Equatable, Hashable, Sendable {
    case onyomi = "onyomi"
    case kunyomi = "kunyomi"
    case special = "special"

    public var displayTitle: String {
        switch self {
        case .onyomi: return "음독"
        case .kunyomi: return "훈독"
        case .special: return "숙자훈·특수"
        }
    }
}

// MARK: - 동일 한자 연관 단어 요약 (한자 2단계 상세 시트용)
public struct RelatedWordSummary: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let wordId: String
    public let term: String
    public let reading: String
    public let primaryMeaning: String
    public let jlptLevel: JLPTLevel

    public var id: String { wordId }

    public init(
        wordId: String,
        term: String,
        reading: String,
        primaryMeaning: String,
        jlptLevel: JLPTLevel
    ) {
        self.wordId = wordId
        self.term = term
        self.reading = reading
        self.primaryMeaning = primaryMeaning
        self.jlptLevel = jlptLevel
    }
}

// MARK: - 한자 마스터 사전 모델 (SPEC.md §2.4)
public struct KanjiInfo: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let character: String
    public let koreanHunEum: String        // 대표 훈음 (예: "마를 건", "달 감")
    public let meanings: [String]          // 세부 뜻풀이
    public let onyomi: [String]            // 음독 목록 (예: ["カン", "ケン"])
    public let kunyomi: [String]           // 훈독 목록 (예: ["かわ.く", "かわ.かす"])
    public let strokeCount: Int            // 총 획수
    public let radical: String?            // 부수 안내
    public let jlptLevel: JLPTLevel?
    public var relatedWords: [RelatedWordSummary]

    public var id: String { character }

    enum CodingKeys: String, CodingKey {
        case character
        case koreanHunEum
        case meanings
        case onyomi
        case kunyomi
        case strokeCount
        case radical
        case jlptLevel
        case relatedWords
    }

    public init(
        character: String,
        koreanHunEum: String,
        meanings: [String],
        onyomi: [String],
        kunyomi: [String],
        strokeCount: Int,
        radical: String? = nil,
        jlptLevel: JLPTLevel? = nil,
        relatedWords: [RelatedWordSummary] = []
    ) {
        self.character = character
        self.koreanHunEum = koreanHunEum
        self.meanings = meanings
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.strokeCount = strokeCount
        self.radical = radical
        self.jlptLevel = jlptLevel
        self.relatedWords = relatedWords
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.character = try container.decode(String.self, forKey: .character)
        self.koreanHunEum = try container.decode(String.self, forKey: .koreanHunEum)
        self.meanings = try container.decodeIfPresent([String].self, forKey: .meanings) ?? []
        self.onyomi = try container.decodeIfPresent([String].self, forKey: .onyomi) ?? []
        self.kunyomi = try container.decodeIfPresent([String].self, forKey: .kunyomi) ?? []
        self.strokeCount = try container.decode(Int.self, forKey: .strokeCount)
        self.radical = try container.decodeIfPresent(String.self, forKey: .radical)
        self.jlptLevel = try container.decodeIfPresent(JLPTLevel.self, forKey: .jlptLevel)
        self.relatedWords = try container.decodeIfPresent([RelatedWordSummary].self, forKey: .relatedWords) ?? []
    }
}

// MARK: - 현재 단어 내 개별 한자 발음 매핑 (1단계 말풍선 발음 하이라이트용)
public struct WordKanjiUsage: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let kanji: String
    public let activeReading: String       // 현재 단어에서 실제 소리 나는 발음 (예: "ぱい", "あま.い")
    public let dictionaryReading: String?  // 연탁·촉음 변형 전 사전 기본 발음 (예: "ハイ")
    public let readingType: KanjiReadingType

    public var id: String { kanji }

    public init(
        kanji: String,
        activeReading: String,
        dictionaryReading: String? = nil,
        readingType: KanjiReadingType
    ) {
        self.kanji = kanji
        self.activeReading = activeReading
        self.dictionaryReading = dictionaryReading
        self.readingType = readingType
    }

    /// 한자 사전(`KanjiInfo`)의 특정 음독/훈독 항목이 현재 단어에서 쓰인 발음인지 판별
    public func isHighlighted(candidate: String, type: KanjiReadingType) -> Bool {
        guard readingType == type else { return false }

        let targetRaw = dictionaryReading ?? activeReading
        let candidateFull = JapaneseScript.normalizeReading(candidate, stripOkuriganaSuffix: false)
        let candidateStem = JapaneseScript.normalizeReading(candidate, stripOkuriganaSuffix: true)

        let targetFull = JapaneseScript.normalizeReading(targetRaw, stripOkuriganaSuffix: false)
        let targetStem = JapaneseScript.normalizeReading(targetRaw, stripOkuriganaSuffix: true)

        if candidateFull == targetFull || (!candidateStem.isEmpty && candidateStem == targetStem) {
            return true
        }

        // 연탁·반탁음·촉음 자동 보정 ('ぱい' ↔ 'ハイ')
        if dictionaryReading == nil {
            let voicelessCandidate = JapaneseScript.toVoicelessHiragana(candidateStem)
            let voicelessActive = JapaneseScript.toVoicelessHiragana(
                JapaneseScript.normalizeReading(activeReading, stripOkuriganaSuffix: true)
            )
            return !voicelessCandidate.isEmpty && voicelessCandidate == voicelessActive
        }

        return false
    }
}

// MARK: - 비한자 단어 어원·원어 안내 (외래어 · 순수 히라가나 예외 처리)
public struct NonKanjiNote: Codable, Equatable, Hashable, Sendable {
    public enum OriginKind: String, Codable, Equatable, Hashable, Sendable {
        case loanword = "loanword"
        case nativeKana = "native_kana"
        case onomatopoeia = "onomatopoeia"
    }

    public let kind: OriginKind
    public let originLanguage: String?  // 예: "English", "Dutch", "Chinese"
    public let originTerm: String?      // 예: "beer", "拉麺 (lāmiàn)"
    public let explanation: String      // 한 줄 어원/표기 설명

    public init(
        kind: OriginKind,
        originLanguage: String? = nil,
        originTerm: String? = nil,
        explanation: String
    ) {
        self.kind = kind
        self.originLanguage = originLanguage
        self.originTerm = originTerm
        self.explanation = explanation
    }

    /// 말풍선 상단에 표시할 원어 배지 문자열 (예: "English: beer")
    public var displayBadge: String {
        if let lang = originLanguage, let term = originTerm, !lang.isEmpty, !term.isEmpty {
            return "\(lang): \(term)"
        }
        if let term = originTerm, !term.isEmpty {
            return term
        }
        switch kind {
        case .loanword: return "외래어 표기"
        case .nativeKana: return "히라가나 상용 표기"
        case .onomatopoeia: return "의성어·의태어"
        }
    }
}
