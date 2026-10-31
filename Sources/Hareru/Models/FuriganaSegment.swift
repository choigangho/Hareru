import Foundation

// MARK: - 일본어 문자 판별 & 발음 정규화 유틸리티
public enum JapaneseScript {
    /// CJK 통합 한자 여부 판별 (단어 내 한자 개별 터치 활성/비활성 기준)
    public static func isKanji(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF,   // CJK Unified Ideographs
             0x3400...0x4DBF,   // CJK Unified Ideographs Extension A
             0xF900...0xFAFF,   // CJK Compatibility Ideographs
             0x20000...0x2A6DF: // CJK Unified Ideographs Extension B
            return true
        default:
            return false
        }
    }

    public static func isKanji(_ character: Character) -> Bool {
        guard let first = character.unicodeScalars.first,
              character.unicodeScalars.count == 1 else {
            return character.unicodeScalars.contains(where: isKanji)
        }
        return isKanji(first)
    }

    public static func containsKanji(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isKanji)
    }

    /// 히라가나 여부 판별 (장음 부호 제외 순수 히라가나)
    public static func isHiragana(_ scalar: UnicodeScalar) -> Bool {
        (0x3041...0x3096).contains(scalar.value)
    }

    public static func isHiragana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(isHiragana)
    }

    /// 가타카나 여부 판별 (장음 부호 'ー' 포함)
    public static func isKatakana(_ scalar: UnicodeScalar) -> Bool {
        (0x30A1...0x30FA).contains(scalar.value) || scalar.value == 0x30FC
    }

    /// 가타카나 문자열을 히라가나로 변환 (음독 'カン' ↔ 'かん' 비교용)
    public static func toHiragana(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if (0x30A1...0x30F6).contains(scalar.value),
               let converted = UnicodeScalar(scalar.value - 0x60) {
                scalars.append(converted)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// 오쿠리가나 구분점('.', '-') 및 공백을 제거하고 히라가나로 통일
    public static func normalizeReading(_ raw: String, stripOkuriganaSuffix: Bool = false) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: String
        if stripOkuriganaSuffix, let dotIndex = trimmed.firstIndex(where: { $0 == "." || $0 == "・" }) {
            target = String(trimmed[..<dotIndex])
        } else {
            target = trimmed.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "・", with: "")
                .replacingOccurrences(of: "-", with: "")
        }
        return toHiragana(target)
    }

    /// 연탁(濁音)·반탁음(半濁音)·촉음(促音)을 청음 기본형으로 환원 ('ぱい' → 'はい')
    public static func toVoicelessHiragana(_ text: String) -> String {
        let hiragana = normalizeReading(text)
        let map: [Character: Character] = [
            "が": "か", "ぎ": "き", "ぐ": "く", "げ": "け", "ご": "こ",
            "ざ": "さ", "じ": "し", "ず": "す", "ぜ": "せ", "ぞ": "そ",
            "だ": "た", "ぢ": "ち", "づ": "つ", "で": "て", "ど": "と",
            "ば": "は", "び": "ひ", "ぶ": "ふ", "べ": "へ", "ぼ": "ほ",
            "ぱ": "は", "ぴ": "ひ", "ぷ": "ふ", "ぺ": "へ", "ぽ": "ほ",
            "ゔ": "う", "っ": "つ"
        ]
        return String(hiragana.map { map[$0] ?? $0 })
    }
}

// MARK: - 메인 단어 글자 단위 세그먼트 (한자만 개별 터치 가능)
public struct TermGlyph: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let index: Int
    public let character: String
    public let isKanji: Bool

    public var id: Int { index }

    public init(index: Int, character: String, isKanji: Bool) {
        self.index = index
        self.character = character
        self.isKanji = isKanji
    }
}

// MARK: - 어절 박스 묶음 후리가나 세그먼트 (SPEC.md §2.1)
/// `[한자 + 뒤 히라가나(오쿠리가나·조사)]`를 하나의 어절 박스로 묶어 글자 밀림을 방지하며,
/// `isTargetWord == true`인 정답 단어 어절의 후리가나는 파도 2(2~8초)에서 열지 않고 정답 보기 전까지 보호합니다.
public struct FuriganaSegment: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public let baseText: String
    public let okurigana: String
    public let reading: String?
    public let isTargetWord: Bool

    public init(
        id: Int,
        baseText: String,
        okurigana: String = "",
        reading: String? = nil,
        isTargetWord: Bool = false
    ) {
        self.id = id
        self.baseText = baseText
        self.okurigana = okurigana
        self.reading = (reading?.isEmpty == true) ? nil : reading
        self.isTargetWord = isTargetWord
    }

    /// 어절 박스 상단에 끊김 없이 렌더링할 일본어 본문 문자열 (`baseText + okurigana`)
    public var surfaceText: String {
        baseText + okurigana
    }

    public var hasFurigana: Bool {
        reading != nil
    }
}

// MARK: - 어절 박스 후리가나 파서
public enum FuriganaParser {
    private enum RawToken {
        case plain(String)
        case ruby(surface: String, reading: String, explicitTarget: Bool)
    }

    /// `{한자|후리가나}` 마크업을 제거한 순수 일본어 예문 반환
    public static func stripMarkup(_ markup: String) -> String {
        tokenize(markup).map { token in
            switch token {
            case .plain(let text):
                return text
            case .ruby(let surface, _, _):
                return surface
            }
        }.joined()
    }

    /// 단어 표기(`term`)를 글자 단위로 분해하여 한자 터치 가능 여부를 태깅
    public static func segmentTermGlyphs(_ term: String) -> [TermGlyph] {
        Array(term).enumerated().map { idx, ch in
            TermGlyph(
                index: idx,
                character: String(ch),
                isKanji: JapaneseScript.isKanji(ch)
            )
        }
    }

    /// 마크업 문자열을 `[한자 + 뒤 히라가나]` 어절 박스 배열로 변환
    /// - Parameters:
    ///   - markup: `{한자|후리가나}` 또는 `{*표제어한자|후리가나}` 마크업 문자열
    ///   - targetTerm: 현재 카드의 표제어(`word.term`). 전달 시 표제어 한자가 포함된 어절을 자동 감지해 `isTargetWord = true`로 잠급니다.
    ///   - maxAutoOkurigana: 자동 흡수할 뒤 히라가나 최대 글자 수
    public static func parsePhraseBoxes(
        _ markup: String,
        targetTerm: String? = nil,
        maxAutoOkurigana: Int = 5
    ) -> [FuriganaSegment] {
        let targetKanjiSet: Set<Character>
        if let targetTerm {
            targetKanjiSet = Set(targetTerm.filter { JapaneseScript.isKanji($0) })
        } else {
            targetKanjiSet = []
        }

        let tokens = tokenize(markup)
        return buildSegments(
            from: tokens,
            targetKanjiSet: targetKanjiSet,
            maxAutoOkurigana: maxAutoOkurigana
        )
    }

    // MARK: - 내부 보조 함수

    private static func buildSegments(
        from tokens: [RawToken],
        targetKanjiSet: Set<Character>,
        maxAutoOkurigana: Int
    ) -> [FuriganaSegment] {
        var mutableTokens = tokens
        var segments: [FuriganaSegment] = []
        var nextId = 0
        var i = 0

        while i < mutableTokens.count {
            switch mutableTokens[i] {
            case .plain(let text):
                if !text.isEmpty {
                    segments.append(FuriganaSegment(id: nextId, baseText: text))
                    nextId += 1
                }
                i += 1

            case .ruby(let rawSurface, let rawReading, let explicitTarget):
                let split = splitTrailingHiraganaFromRuby(surface: rawSurface, reading: rawReading)
                var baseText = split.base
                var okurigana = split.okurigana
                let reading = split.cleanReading
                let hadExplicitOkurigana = !okurigana.isEmpty

                let minimumSurfaceChars = Int(ceil(Double(reading.count) * 0.65))
                if i + 1 < mutableTokens.count, case .plain(let followingText) = mutableTokens[i + 1] {
                    let leadingHiragana = leadingHiraganaPrefix(in: followingText)
                    if !leadingHiragana.isEmpty {
                        let currentWidth = baseText.count + okurigana.count
                        let neededForWidth = max(0, minimumSurfaceChars - currentWidth)
                        let absorbLimit = hadExplicitOkurigana
                            ? neededForWidth
                            : max(neededForWidth, maxAutoOkurigana)

                        let absorbCount = min(leadingHiragana.count, absorbLimit)
                        if absorbCount > 0 {
                            let absorbed = String(leadingHiragana.prefix(absorbCount))
                            okurigana += absorbed
                            let remainder = String(followingText.dropFirst(absorbCount))
                            if remainder.isEmpty {
                                i += 1 // 다음 plain 토큰 전체 흡수
                            } else {
                                mutableTokens[i + 1] = .plain(remainder)
                            }
                        }
                    }
                }

                if baseText.isEmpty {
                    baseText = rawSurface
                    okurigana = ""
                }

                let segmentKanjiSet = Set(baseText.filter { JapaneseScript.isKanji($0) })
                let matchesTargetKanji = !targetKanjiSet.isEmpty
                    && !segmentKanjiSet.isEmpty
                    && (segmentKanjiSet.isSubset(of: targetKanjiSet) || targetKanjiSet.isSubset(of: segmentKanjiSet))

                segments.append(
                    FuriganaSegment(
                        id: nextId,
                        baseText: baseText,
                        okurigana: okurigana,
                        reading: reading,
                        isTargetWord: explicitTarget || matchesTargetKanji
                    )
                )
                nextId += 1
                i += 1
            }
        }

        return segments
    }

    private static func tokenize(_ markup: String) -> [RawToken] {
        var result: [RawToken] = []
        var plainBuffer = ""
        var cursor = markup.startIndex

        while cursor < markup.endIndex {
            let ch = markup[cursor]
            if ch == "{" {
                let afterOpen = markup.index(after: cursor)
                if let closeIdx = markup[afterOpen...].firstIndex(of: "}"),
                   let pipeIdx = markup[afterOpen..<closeIdx].firstIndex(of: "|") {
                    if !plainBuffer.isEmpty {
                        result.append(.plain(plainBuffer))
                        plainBuffer = ""
                    }
                    var rawSurface = String(markup[afterOpen..<pipeIdx])
                    var explicitTarget = false
                    if rawSurface.hasPrefix("*"), rawSurface.count > 1 {
                        explicitTarget = true
                        rawSurface.removeFirst()
                    }
                    let readingStart = markup.index(after: pipeIdx)
                    let reading = String(markup[readingStart..<closeIdx])
                    if rawSurface.isEmpty {
                        result.append(.plain(reading))
                    } else if reading.isEmpty {
                        result.append(.plain(rawSurface))
                    } else {
                        result.append(.ruby(surface: rawSurface, reading: reading, explicitTarget: explicitTarget))
                    }
                    cursor = markup.index(after: closeIdx)
                    continue
                }
            }
            plainBuffer.append(ch)
            cursor = markup.index(after: cursor)
        }

        if !plainBuffer.isEmpty {
            result.append(.plain(plainBuffer))
        }
        return result
    }

    private static func splitTrailingHiraganaFromRuby(
        surface: String,
        reading: String
    ) -> (base: String, okurigana: String, cleanReading: String) {
        let surfaceChars = Array(surface)
        guard surfaceChars.contains(where: { JapaneseScript.isKanji($0) }) else {
            return (surface, "", reading)
        }

        var trailingCount = 0
        for ch in surfaceChars.reversed() {
            if JapaneseScript.isHiragana(ch) {
                trailingCount += 1
            } else {
                break
            }
        }

        guard trailingCount > 0, trailingCount < surfaceChars.count else {
            return (surface, "", reading)
        }

        let base = String(surfaceChars.dropLast(trailingCount))
        let okurigana = String(surfaceChars.suffix(trailingCount))

        var cleanReading = reading
        if cleanReading.hasSuffix(okurigana), cleanReading.count > okurigana.count {
            cleanReading = String(cleanReading.dropLast(okurigana.count))
        }
        return (base, okurigana, cleanReading)
    }

    private static func leadingHiraganaPrefix(in text: String) -> String {
        var prefixChars: [Character] = []
        for ch in text {
            if JapaneseScript.isHiragana(ch) {
                prefixChars.append(ch)
            } else {
                break
            }
        }
        return String(prefixChars)
    }
}
