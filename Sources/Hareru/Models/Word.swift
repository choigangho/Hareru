import SwiftUI

// MARK: - 오디오 파일명 정규화 (확장자 제외 스템 통일)
public enum AudioFileName {
    private static let knownExtensions = [".m4a", ".wav", ".mp3"]

    public static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        for ext in knownExtensions where lower.hasSuffix(ext) {
            return String(trimmed.dropLast(ext.count))
        }
        return trimmed
    }
}

// MARK: - 예문 한국어 3분할 해석 (앞 문맥 / 정답 키워드 / 뒤 문맥)
public struct SplitTranslation: Codable, Equatable, Hashable, Sendable {
    public let before: String
    public let answer: String
    public let after: String

    public init(before: String, answer: String, after: String) {
        self.before = before
        self.answer = answer
        self.after = after
    }

    public var fullText: String {
        before + answer + after
    }

    /// 정답 보호 영역(`answer`)이 비어 있지 않은지 검증
    public var isValid: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 파도 3(4~10초)에서 노출할 주변 문맥이 존재하는지 여부
    public var hasSurroundingContext: Bool {
        !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 단어 의미 단위 (다의어 1단어 1카드 구조: 대표 의미 1 + 서브 의미 2~4)
public struct WordSense: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let senseNumber: Int            // 1 = 대표 의미(메인 컬러·앞면 예문 담당), 2...4 = 서브 의미
    public let partOfSpeech: String?       // 예: "명사", "イ형용사", "동사 5단"
    public let meaning: String             // 뜻 (정답)
    public let exampleMarkup: String       // 어절 박스 후리가나 마크업 포함 예문
    public let example: String             // 마크업이 제거된 순수 일본어 예문
    public let translation: SplitTranslation
    public let voice: VoiceProfile         // 해당 의미의 대사를 연기하는 성우 캐릭터
    public let subPalette: ThemePalette?   // 서브 의미 전용 보조 컬러 팔레트 (선택)
    public let exampleAudioFile: String    // 256kbps 예문 오디오 파일 스템

    public var isPrimary: Bool {
        senseNumber == 1
    }

    /// 예문이 아직 없는 의미 (N4~N1은 뜻만 먼저 넣고 예문은 추후 추가) — 카드에 안내 문구를 대신 표시
    public var hasExample: Bool {
        !exampleMarkup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static let examplePendingNotice = "예문 추후 추가 예정"

    public var exampleSegments: [FuriganaSegment] {
        FuriganaParser.parsePhraseBoxes(exampleMarkup)
    }

    /// 표제어(`targetTerm`) 한자가 포함된 어절의 후리가나를 정답 공개 전까지 자동 잠금한 세그먼트 반환
    public func exampleSegments(forTargetTerm targetTerm: String) -> [FuriganaSegment] {
        FuriganaParser.parsePhraseBoxes(exampleMarkup, targetTerm: targetTerm)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case senseNumber
        case partOfSpeech
        case meaning
        case exampleMarkup
        case example
        case translation
        case voiceId
        case voice
        case subPalette
        case exampleAudioFile
    }

    public init(
        id: String,
        senseNumber: Int,
        partOfSpeech: String? = nil,
        meaning: String,
        exampleMarkup: String,
        translation: SplitTranslation,
        voice: VoiceProfile,
        subPalette: ThemePalette? = nil,
        exampleAudioFile: String
    ) {
        self.id = id
        self.senseNumber = senseNumber
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.exampleMarkup = exampleMarkup
        self.example = FuriganaParser.stripMarkup(exampleMarkup)
        self.translation = translation
        self.voice = voice
        self.subPalette = subPalette
        self.exampleAudioFile = AudioFileName.normalize(exampleAudioFile)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.senseNumber = try container.decode(Int.self, forKey: .senseNumber)
        self.partOfSpeech = try container.decodeIfPresent(String.self, forKey: .partOfSpeech)
        self.meaning = try container.decode(String.self, forKey: .meaning)

        if let markup = try container.decodeIfPresent(String.self, forKey: .exampleMarkup) {
            self.exampleMarkup = markup
            self.example = try container.decodeIfPresent(String.self, forKey: .example)
                ?? FuriganaParser.stripMarkup(markup)
        } else {
            let plain = try container.decode(String.self, forKey: .example)
            self.exampleMarkup = plain
            self.example = plain
        }

        self.translation = try container.decode(SplitTranslation.self, forKey: .translation)

        if let fullVoice = try container.decodeIfPresent(VoiceProfile.self, forKey: .voice) {
            self.voice = fullVoice
        } else {
            // 음성 캐릭터가 아직 배정되지 않은 데이터는 voiceId가 없거나 "unassigned"
            let voiceId = try container.decodeIfPresent(String.self, forKey: .voiceId) ?? VoiceProfile.unassigned.id
            self.voice = VoiceProfile.preset(forId: voiceId)
        }

        self.subPalette = try container.decodeIfPresent(ThemePalette.self, forKey: .subPalette)
        let rawAudio = try container.decode(String.self, forKey: .exampleAudioFile)
        self.exampleAudioFile = AudioFileName.normalize(rawAudio)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(senseNumber, forKey: .senseNumber)
        try container.encodeIfPresent(partOfSpeech, forKey: .partOfSpeech)
        try container.encode(meaning, forKey: .meaning)
        try container.encode(exampleMarkup, forKey: .exampleMarkup)
        try container.encode(translation, forKey: .translation)
        try container.encode(voice.id, forKey: .voiceId)
        try container.encodeIfPresent(subPalette, forKey: .subPalette)
        try container.encode(exampleAudioFile, forKey: .exampleAudioFile)
    }
}

// MARK: - 단어 마스터 도메인 모델 (SPEC.md §2, §4)
public struct Word: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String                  // 영구 불변 ID (예: "n5_food_beer")
    public let jlptLevel: JLPTLevel
    public let category: String            // 상단 카테고리 표시용 (예: "음식")
    public let term: String                // 메인 표제어 (일본어)
    public let reading: String             // 읽는 법 (히라가나)
    public let pitchAccent: Int?           // 악센트 핵 위치 (선택)
    public let palette: ThemePalette       // 카테고리 기반 3색 그라데이션 팔레트 (미지정 시 카테고리 자동 매핑)
    public let termAudioFile: String       // 256kbps 단어 오디오 파일 스템
    public let senses: [WordSense]         // [대표 의미 1, 서브 의미 2...4]
    public let kanjiUsages: [WordKanjiUsage]
    public let nonKanjiNote: NonKanjiNote?

    /// 단어가 속한 카테고리 컬러 테마 그룹 (`식음료·매장`, `비즈니스·업무`, ..., `기본`)
    public var categoryThemeGroup: CategoryThemeGroup {
        CategoryThemeGroup.resolve(for: category)
    }

    /// 화면 렌더링에 사용할 카테고리 기준 팔레트 (개별 단어마다 색이 튀지 않도록 카테고리 테마로 통일)
    public var categoryPalette: ThemePalette {
        ThemePalette.forCategory(category)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case jlptLevel
        case category
        case term
        case reading
        case pitchAccent
        case palette
        case termAudioFile
        case senses
        case kanjiUsages
        case nonKanjiNote
    }

    public init(
        id: String,
        jlptLevel: JLPTLevel,
        category: String,
        term: String,
        reading: String,
        pitchAccent: Int? = nil,
        palette: ThemePalette,
        termAudioFile: String,
        senses: [WordSense],
        kanjiUsages: [WordKanjiUsage] = [],
        nonKanjiNote: NonKanjiNote? = nil
    ) {
        precondition(!senses.isEmpty, "Word must have at least one primary WordSense.")
        self.id = id
        self.jlptLevel = jlptLevel
        self.category = category
        self.term = term
        self.reading = reading
        self.pitchAccent = pitchAccent
        self.palette = palette
        self.termAudioFile = AudioFileName.normalize(termAudioFile)
        self.senses = senses.sorted { $0.senseNumber < $1.senseNumber }
        self.kanjiUsages = kanjiUsages
        self.nonKanjiNote = nonKanjiNote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let jlptLevel = try container.decode(JLPTLevel.self, forKey: .jlptLevel)
        let category = try container.decode(String.self, forKey: .category)
        let term = try container.decode(String.self, forKey: .term)
        let reading = try container.decode(String.self, forKey: .reading)
        let pitchAccent = try container.decodeIfPresent(Int.self, forKey: .pitchAccent)
        let palette = try container.decodeIfPresent(ThemePalette.self, forKey: .palette)
            ?? ThemePalette.forCategory(category)
        let termAudioFile = try container.decode(String.self, forKey: .termAudioFile)
        let senses = try container.decode([WordSense].self, forKey: .senses)
        guard !senses.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .senses,
                in: container,
                debugDescription: "Word '\(id)' must contain at least one sense."
            )
        }
        let kanjiUsages = try container.decodeIfPresent([WordKanjiUsage].self, forKey: .kanjiUsages) ?? []
        let nonKanjiNote = try container.decodeIfPresent(NonKanjiNote.self, forKey: .nonKanjiNote)

        self.init(
            id: id,
            jlptLevel: jlptLevel,
            category: category,
            term: term,
            reading: reading,
            pitchAccent: pitchAccent,
            palette: palette,
            termAudioFile: termAudioFile,
            senses: senses,
            kanjiUsages: kanjiUsages,
            nonKanjiNote: nonKanjiNote
        )
    }

    // MARK: - 대표 의미 & 다의어 편의 프로퍼티

    public var primarySense: WordSense {
        senses[0]
    }

    public var secondarySenses: [WordSense] {
        Array(senses.dropFirst())
    }

    public var isPolysemous: Bool {
        senses.count > 1
    }

    /// 복습 회차(`reps`)에 따라 출제할 의미를 순환 선택 (SPEC.md §4)
    /// - 초회 학습(`reps <= 0`): 대표 의미(뜻 1) 고정
    /// - 복습 회차(`reps >= 1`): `reps % senses.count` 라운드로빈으로 서브 의미(뜻 2~4)까지 능동 인출 유도
    public func activeSense(forReps reps: Int) -> WordSense {
        guard reps > 0, senses.count > 1 else { return primarySense }
        return senses[reps % senses.count]
    }

    /// 현재 앞면 문제로 출제된 의미를 제외한 나머지 보조 의미 목록 (정답 공개 시 하단 노출용)
    public func supplementarySenses(excluding senseId: String) -> [WordSense] {
        senses.filter { $0.id != senseId }
    }

    /// 특정 의미에 대응하는 테마 팔레트 (카테고리 테마를 기본으로 사용)
    public func activePalette(for sense: WordSense) -> ThemePalette {
        categoryPalette
    }

    /// 특정 의미 예문의 어절 박스 세그먼트 반환 (표제어 후리가나 스포일러 잠금 적용)
    public func segments(for sense: WordSense) -> [FuriganaSegment] {
        sense.exampleSegments(forTargetTerm: term)
    }

    /// 단어 표기(`term`)를 글자 단위로 분해하여 한자 터치 가능 여부를 반환
    public var termGlyphs: [TermGlyph] {
        FuriganaParser.segmentTermGlyphs(term)
    }

    public var hasKanji: Bool {
        termGlyphs.contains(where: \.isKanji)
    }

    /// 특정 한자 글자에 대한 현재 단어 발음 매핑 조회
    public func kanjiUsage(for kanjiCharacter: String) -> WordKanjiUsage? {
        kanjiUsages.first { $0.kanji == kanjiCharacter }
    }

    /// 세션 내 실패 횟수에 따라 침식(Red+Black)이 반영된 카테고리 3색 배열 반환
    public func colors(
        for sense: WordSense? = nil,
        sessionFailures failureCount: Int,
        maxFailuresBeforeCap: Int = 7
    ) -> [Color] {
        categoryPalette.colors(forFailureCount: failureCount, maxFailuresBeforeCap: maxFailuresBeforeCap)
    }

    public func colors(forSessionFailures failureCount: Int, maxFailuresBeforeCap: Int = 7) -> [Color] {
        categoryPalette.colors(forFailureCount: failureCount, maxFailuresBeforeCap: maxFailuresBeforeCap)
    }

    // MARK: - 기존 뷰 호환 & 직관적 접근용 프로퍼티 (대표 의미 위임)

    public var meaning: String { primarySense.meaning }
    public var example: String { primarySense.example }
    public var exampleMarkup: String { primarySense.exampleMarkup }
    public var exampleSegments: [FuriganaSegment] { primarySense.exampleSegments(forTargetTerm: term) }
    public var transBefore: String { primarySense.translation.before }
    public var transAnswer: String { primarySense.translation.answer }
    public var transAfter: String { primarySense.translation.after }
    public var colors: [Color] { categoryPalette.swiftUIColors }
    public var voice: VoiceProfile { primarySense.voice }
    public var exampleAudioFile: String { primarySense.exampleAudioFile }
}
