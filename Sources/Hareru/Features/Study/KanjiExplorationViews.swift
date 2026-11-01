import SwiftUI

// MARK: - 1단계 말풍선 팝오버 (대표 훈음 + 현재 단어에서 읽힌 발음 하이라이트, SPEC.md §2.4)
public struct KanjiQuickPopoverView: View {
    public let kanjiInfo: KanjiInfo
    public let usage: WordKanjiUsage?
    public let accentColor: Color
    public let onOpenDetail: () -> Void

    public init(
        kanjiInfo: KanjiInfo,
        usage: WordKanjiUsage?,
        accentColor: Color,
        onOpenDetail: @escaping () -> Void
    ) {
        self.kanjiInfo = kanjiInfo
        self.usage = usage
        self.accentColor = accentColor
        self.onOpenDetail = onOpenDetail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(kanjiInfo.character)
                    .jlptTermFont(size: 40)
                    .frame(width: 52, height: 52)
                    .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(kanjiInfo.koreanHunEum)
                        .font(.headline)

                    if let usage {
                        HStack(spacing: 6) {
                            Text(usage.readingType.displayTitle)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(accentColor)

                            Text(activeReadingDescription(for: usage))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            if !kanjiInfo.meanings.isEmpty {
                Text(kanjiInfo.meanings.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                onOpenDetail()
            } label: {
                HStack {
                    Text("자세히 보기 (음독·훈독·연관 단어)")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 260)
    }

    private func activeReadingDescription(for usage: WordKanjiUsage) -> String {
        if let dict = usage.dictionaryReading,
           JapaneseScript.normalizeReading(dict) != JapaneseScript.normalizeReading(usage.activeReading) {
            return "\(usage.activeReading) (원형 \(dict))"
        }
        return usage.activeReading
    }
}

// MARK: - 비한자 단어(외래어·순수 히라가나) 어원 팝오버 (SPEC.md §2.4)
public struct NonKanjiOriginPopoverView: View {
    public let term: String
    public let note: NonKanjiNote

    public init(term: String, note: NonKanjiNote) {
        self.term = term
        self.note = note
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "globe.asia.australia.fill")
                    .foregroundStyle(.secondary)
                Text(note.displayBadge)
                    .font(.subheadline.weight(.bold))
            }
            Text(note.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 250)
    }
}

// MARK: - 2단계 한자 상세 시트 (음독·훈독 하이라이트 · 획수 · 동일 한자 연관 단어, SPEC.md §2.4)
public struct KanjiDetailSheetView: View {
    public let kanjiInfo: KanjiInfo
    public let usage: WordKanjiUsage?
    public let currentWordId: String
    public let accentColor: Color
    @Environment(\.dismiss) private var dismiss

    public init(
        kanjiInfo: KanjiInfo,
        usage: WordKanjiUsage?,
        currentWordId: String,
        accentColor: Color
    ) {
        self.kanjiInfo = kanjiInfo
        self.usage = usage
        self.currentWordId = currentWordId
        self.accentColor = accentColor
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1) 상단 대표 한자 & 획수/부수 메타데이터
                    HStack(spacing: 16) {
                        Text(kanjiInfo.character)
                            .jlptTermFont(size: 60)
                            .frame(width: 84, height: 84)
                            .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(kanjiInfo.koreanHunEum)
                                    .font(.title2.bold())
                                if let level = kanjiInfo.jlptLevel {
                                    Text(level.rawValue)
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.secondary.opacity(0.16), in: Capsule())
                                }
                            }

                            Text("\(kanjiInfo.strokeCount)획" + (kanjiInfo.radical.map { " · 부수 \($0)" } ?? ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if !kanjiInfo.meanings.isEmpty {
                                Text(kanjiInfo.meanings.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // 2) 음독 & 훈독 (현재 단어에서 읽힌 발음 하이라이트)
                    readingSection(title: "음독 (音読み)", readings: kanjiInfo.onyomi, type: .onyomi)
                    readingSection(title: "훈독 (訓読み)", readings: kanjiInfo.kunyomi, type: .kunyomi)

                    // 3) 동일 한자 연관 단어 목록
                    if !kanjiInfo.relatedWords.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            Text("이 한자가 쓰인 연관 단어")
                                .font(.headline)

                            ForEach(kanjiInfo.relatedWords) { related in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(related.term)
                                                .jlptTermFont(size: 18)
                                            Text("(\(related.reading))")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            if related.wordId == currentWordId {
                                                Text("현재 단어")
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(accentColor.opacity(0.18), in: Capsule())
                                                    .foregroundStyle(accentColor)
                                            }
                                        }
                                        Text(related.primaryMeaning)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(related.jlptLevel.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("한자 상세")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func readingSection(title: String, readings: [String], type: KanjiReadingType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if readings.isEmpty {
                Text("해당 없음")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                PhraseFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(readings, id: \.self) { candidate in
                        let highlighted = usage?.isHighlighted(candidate: candidate, type: type) ?? false
                        HStack(spacing: 4) {
                            if highlighted {
                                Image(systemName: "sparkle")
                                    .font(.caption2)
                            }
                            Text(candidate)
                                .font(.subheadline.weight(highlighted ? .bold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            highlighted ? accentColor : Color.secondary.opacity(0.14),
                            in: Capsule()
                        )
                        .foregroundStyle(highlighted ? Color.white : Color.primary)
                    }
                }
            }
        }
    }
}
