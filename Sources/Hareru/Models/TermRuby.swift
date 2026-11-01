import Foundation

// MARK: - 표제어 루비(후리가나) 배치 단위
/// 같은 후리가나를 공유하는 글자 묶음. 한자 1자(現 → げん), 숙자훈 묶음(美味 → おい),
/// 또는 후리가나가 필요 없는 가나(しい)가 하나의 run이 됩니다.
public struct TermRubyRun: Identifiable, Equatable, Hashable, Sendable {
    public let id: Int
    public let glyphs: [TermGlyph]
    public let reading: String?

    public var text: String { glyphs.map(\.character).joined() }
}

public extension Word {
    /// 표제어를 '어느 한자에 어떤 후리가나가 붙는지' 보이도록 run 단위로 나눕니다.
    /// 1) 한자별 발음(`kanjiUsages`)을 이어 붙인 결과가 단어 전체 읽기와 같으면 한자마다 따로 루비
    /// 2) 다르면(숙자훈 등) 연속된 한자 묶음 하나에 남은 읽기를 통째로 루비
    /// 3) 그래도 맞출 수 없으면 표제어 전체에 단어 읽기를 한 번에 루비
    var termRubyRuns: [TermRubyRun] {
        let glyphs = termGlyphs
        guard glyphs.contains(where: \.isKanji) else {
            return [TermRubyRun(id: 0, glyphs: glyphs, reading: nil)]
        }
        let fullReading = JapaneseScript.toHiragana(reading)

        // 1) 한자별 루비
        var perKanjiRuns: [TermRubyRun] = []
        var rebuilt = ""
        var pendingKana: [TermGlyph] = []
        for glyph in glyphs {
            if glyph.isKanji, let usage = kanjiUsage(for: glyph.character) {
                if !pendingKana.isEmpty {
                    perKanjiRuns.append(TermRubyRun(id: perKanjiRuns.count, glyphs: pendingKana, reading: nil))
                    pendingKana = []
                }
                let kanjiReading = JapaneseScript.normalizeReading(usage.activeReading, stripOkuriganaSuffix: true)
                rebuilt += kanjiReading
                perKanjiRuns.append(TermRubyRun(id: perKanjiRuns.count, glyphs: [glyph], reading: kanjiReading))
            } else if glyph.isKanji {
                rebuilt = "" // 발음 데이터가 없는 한자 → 한자별 루비 불가
                break
            } else {
                rebuilt += JapaneseScript.toHiragana(glyph.character)
                pendingKana.append(glyph)
            }
        }
        if rebuilt == fullReading {
            if !pendingKana.isEmpty {
                perKanjiRuns.append(TermRubyRun(id: perKanjiRuns.count, glyphs: pendingKana, reading: nil))
            }
            return perKanjiRuns
        }

        // 2) 한자 묶음이 하나뿐이면 앞뒤 가나를 뺀 나머지 읽기를 묶음 루비로
        let prefix = Array(glyphs.prefix { !$0.isKanji })
        let suffix = Array(glyphs.reversed().prefix { !$0.isKanji }.reversed())
        let core = Array(glyphs.dropFirst(prefix.count).dropLast(suffix.count))
        let prefixKana = JapaneseScript.toHiragana(prefix.map(\.character).joined())
        let suffixKana = JapaneseScript.toHiragana(suffix.map(\.character).joined())
        if core.allSatisfy(\.isKanji),
           fullReading.hasPrefix(prefixKana),
           fullReading.hasSuffix(suffixKana),
           fullReading.count > prefixKana.count + suffixKana.count {
            let coreReading = String(fullReading.dropFirst(prefixKana.count).dropLast(suffixKana.count))
            var runs: [TermRubyRun] = []
            if !prefix.isEmpty { runs.append(TermRubyRun(id: runs.count, glyphs: prefix, reading: nil)) }
            runs.append(TermRubyRun(id: runs.count, glyphs: core, reading: coreReading))
            if !suffix.isEmpty { runs.append(TermRubyRun(id: runs.count, glyphs: suffix, reading: nil)) }
            return runs
        }

        // 3) 최후 수단: 표제어 전체에 단어 읽기
        return [TermRubyRun(id: 0, glyphs: glyphs, reading: fullReading)]
    }
}
