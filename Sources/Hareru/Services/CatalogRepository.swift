import Foundation

// MARK: - 카탈로그 데이터 무결성 검증 오류
public enum CatalogValidationError: Error, Equatable, Sendable, CustomStringConvertible {
    case duplicateWordId(String)
    case invalidPrimarySense(wordId: String)
    case invalidSplitTranslation(wordId: String, senseId: String)
    case surfaceMismatch(wordId: String, senseId: String)
    case missingKanjiUsage(wordId: String, kanji: String)
    case missingKanjiMasterEntry(wordId: String, kanji: String)
    case missingNonKanjiNote(wordId: String)
    case unknownCategory(wordId: String, category: String)
    case resourceNotFound(String)

    public var description: String {
        switch self {
        case .duplicateWordId(let id):
            return "중복된 단어 ID가 감지되었습니다: \(id)"
        case .invalidPrimarySense(let wordId):
            return "단어 '\(wordId)'의 첫 번째 의미(senseNumber == 1)가 누락되었거나 순서가 올바르지 않습니다."
        case .invalidSplitTranslation(let wordId, let senseId):
            return "단어 '\(wordId)' 의미 '\(senseId)'의 한국어 정답 조각(answer)이 비어 있습니다."
        case .surfaceMismatch(let wordId, let senseId):
            return "단어 '\(wordId)' 의미 '\(senseId)'의 어절 박스 표면 텍스트와 원문 예문이 일치하지 않습니다."
        case .missingKanjiUsage(let wordId, let kanji):
            return "단어 '\(wordId)' 표제어 내 한자 '\(kanji)'의 발음 매핑(WordKanjiUsage)이 누락되었습니다."
        case .missingKanjiMasterEntry(let wordId, let kanji):
            return "단어 '\(wordId)'에 쓰인 한자 '\(kanji)'가 한자 사전(kanji.json)에 존재하지 않습니다."
        case .missingNonKanjiNote(let wordId):
            return "비한자 단어 '\(wordId)'의 어원·원어 안내(NonKanjiNote)가 누락되었습니다."
        case .unknownCategory(let wordId, let category):
            return "단어 '\(wordId)'의 대분류 '\(category)'가 대분류 목록(CategoryThemeGroup)에 없습니다."
        case .resourceNotFound(let file):
            return "번들 리소스 파일을 찾을 수 없습니다: \(file)"
        }
    }
}

// MARK: - 단어·다의어·한자 통합 카탈로그 저장소 & 한자 연관 단어 역인덱스
public final class CatalogRepository: Sendable {
    public static let shared: CatalogRepository = {
        if let loaded = try? CatalogRepository.loadBundled() {
            return loaded
        }
        return CatalogRepository(words: Word.samples, kanjiEntries: KanjiInfo.samples)
    }()

    public let words: [Word]
    public let wordsById: [String: Word]
    public let kanjiByCharacter: [String: KanjiInfo]

    public init(words: [Word], kanjiEntries: [KanjiInfo]) {
        self.words = words
        var wordMap: [String: Word] = [:]
        for word in words {
            wordMap[word.id] = word
        }
        self.wordsById = wordMap
        self.kanjiByCharacter = Self.buildKanjiInvertedIndex(words: words, kanjiEntries: kanjiEntries)
    }

    /// 번들(`words.json`, `kanji.json`)에서 카탈로그를 로드하여 역인덱스 구축
    public static func loadBundled() throws -> CatalogRepository {
        let wordsData = try loadResourceData(named: "words", withExtension: "json")
        let kanjiData = try loadResourceData(named: "kanji", withExtension: "json")

        let decoder = JSONDecoder()
        let decodedWords = try decoder.decode([Word].self, from: wordsData)
        let decodedKanji = try decoder.decode([KanjiInfo].self, from: kanjiData)

        let repository = CatalogRepository(words: decodedWords, kanjiEntries: decodedKanji)
        try repository.validate()
        return repository
    }

    // MARK: - 조회 인터페이스

    public func word(forId id: String) -> Word? {
        wordsById[id]
    }

    public func words(for level: JLPTLevel) -> [Word] {
        words.filter { $0.jlptLevel == level }
    }

    public func kanjiInfo(for character: String) -> KanjiInfo? {
        kanjiByCharacter[character]
    }

    /// 특정 한자를 포함하는 연관 단어 목록 조회 (현재 보고 있는 단어는 선택적으로 제외 가능)
    public func relatedWords(
        forKanji character: String,
        excludingWordId: String? = nil
    ) -> [RelatedWordSummary] {
        guard let info = kanjiByCharacter[character] else { return [] }
        guard let excludingWordId else { return info.relatedWords }
        return info.relatedWords.filter { $0.wordId != excludingWordId }
    }

    // MARK: - 데이터 무결성 검증 (오프라인 생성 파이프라인 & 런타임 공통 검증)

    public func validationIssues() -> [CatalogValidationError] {
        var issues: [CatalogValidationError] = []
        var seenIds = Set<String>()

        for word in words {
            if !seenIds.insert(word.id).inserted {
                issues.append(.duplicateWordId(word.id))
            }

            if word.senses.first?.senseNumber != 1 {
                issues.append(.invalidPrimarySense(wordId: word.id))
            }

            if CategoryThemeGroup(rawValue: word.category) == nil {
                issues.append(.unknownCategory(wordId: word.id, category: word.category))
            }

            for sense in word.senses where sense.hasExample {
                if !sense.translation.isValid {
                    issues.append(.invalidSplitTranslation(wordId: word.id, senseId: sense.id))
                }
                let reconstructed = sense.exampleSegments.map(\.surfaceText).joined()
                if reconstructed != sense.example {
                    issues.append(.surfaceMismatch(wordId: word.id, senseId: sense.id))
                }
            }

            let kanjiGlyphs = word.termGlyphs.filter(\.isKanji)
            if kanjiGlyphs.isEmpty {
                if word.nonKanjiNote == nil {
                    issues.append(.missingNonKanjiNote(wordId: word.id))
                }
            } else {
                var checkedKanji = Set<String>()
                for glyph in kanjiGlyphs where checkedKanji.insert(glyph.character).inserted {
                    if word.kanjiUsage(for: glyph.character) == nil {
                        issues.append(.missingKanjiUsage(wordId: word.id, kanji: glyph.character))
                    }
                    if kanjiByCharacter[glyph.character] == nil {
                        issues.append(.missingKanjiMasterEntry(wordId: word.id, kanji: glyph.character))
                    }
                }
            }
        }

        return issues
    }

    public func validate() throws {
        if let firstIssue = validationIssues().first {
            throw firstIssue
        }
    }

    // MARK: - 한자 역인덱스 구축 & 리소스 로더

    private static func buildKanjiInvertedIndex(
        words: [Word],
        kanjiEntries: [KanjiInfo]
    ) -> [String: KanjiInfo] {
        var map: [String: KanjiInfo] = [:]
        for entry in kanjiEntries {
            map[entry.character] = entry
        }

        var reverseLinks: [String: [RelatedWordSummary]] = [:]
        for word in words {
            var uniqueKanjiInWord = Set<String>()
            for glyph in word.termGlyphs where glyph.isKanji {
                uniqueKanjiInWord.insert(glyph.character)
            }
            guard !uniqueKanjiInWord.isEmpty else { continue }

            let summary = RelatedWordSummary(
                wordId: word.id,
                term: word.term,
                reading: word.reading,
                primaryMeaning: word.meaning,
                jlptLevel: word.jlptLevel
            )
            for kanji in uniqueKanjiInWord {
                reverseLinks[kanji, default: []].append(summary)
            }
        }

        for (kanji, var info) in map {
            var combined = info.relatedWords
            var seenWordIds = Set(combined.map(\.wordId))
            for summary in reverseLinks[kanji] ?? [] {
                if seenWordIds.insert(summary.wordId).inserted {
                    combined.append(summary)
                }
            }
            combined.sort { lhs, rhs in
                if lhs.jlptLevel != rhs.jlptLevel {
                    return lhs.jlptLevel < rhs.jlptLevel
                }
                return lhs.wordId < rhs.wordId
            }
            info.relatedWords = combined
            map[kanji] = info
        }

        return map
    }

    private static func loadResourceData(named name: String, withExtension ext: String) throws -> Data {
        let bundles: [Bundle] = [Bundle.module, Bundle.main]
        let subdirectories: [String?] = [nil, "Data", "Resources/Data"]

        for bundle in bundles {
            for sub in subdirectories {
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: sub),
                   let data = try? Data(contentsOf: url) {
                    return data
                }
            }
        }

        let sourceDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // Sources/Hareru
        let fallbackURL = sourceDir
            .appendingPathComponent("Resources/Data", isDirectory: true)
            .appendingPathComponent("\(name).\(ext)")

        if let data = try? Data(contentsOf: fallbackURL) {
            return data
        }

        throw CatalogValidationError.resourceNotFound("\(name).\(ext)")
    }
}
