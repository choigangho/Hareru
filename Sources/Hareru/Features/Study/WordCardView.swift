import SwiftUI

// MARK: - 단일 단어 카드 (앞면: 표제어 + 후리가나 없는 예문만 / 뒷면: 발음·뜻·후리가나·해석·다의어·한자)
// - 하단 액션 슬롯은 카드 내부에 위치·크기가 고정되어 있고,
//   '정답 보기' 한 개 버튼이 같은 자리에서 '모르겠음 · 애매함 · 알고있음 · 쉬움' 4개로 갈라지며 변합니다.
// - 다의어처럼 내용이 길어져도 스크롤은 상단 콘텐츠 영역에서만 일어나고 버튼은 움직이지 않습니다.
public struct WordCardView: View {
    public let item: SessionQueueItem
    public let catalog: CatalogRepository
    public let palette: WeatherSkyPalette
    public let isRaining: Bool
    public var onReveal: (() -> Void)?
    public var onEvaluate: ((ReviewButton) -> Void)?

    @State private var isRevealed: Bool = false
    @State private var exampleVisible: Bool = false

    // 한자 1단계 말풍선 & 2단계 상세 시트 상태
    @State private var activeKanjiPopoverIndex: Int?
    @State private var showNonKanjiPopover: Bool = false
    @State private var detailSheetKanji: KanjiInfo?
    @State private var detailSheetUsage: WordKanjiUsage?

    @State private var speaker = SpeechPlayer()
    @Namespace private var actionSlotNamespace

    private static let actionSlotHeight: CGFloat = 58

    public init(
        item: SessionQueueItem,
        catalog: CatalogRepository = .shared,
        palette: WeatherSkyPalette = WeatherSkyPalette.resolve(condition: .clear, timeOfDay: .midday),
        isRaining: Bool = false,
        onReveal: (() -> Void)? = nil,
        onEvaluate: ((ReviewButton) -> Void)? = nil
    ) {
        self.item = item
        self.catalog = catalog
        self.palette = palette
        self.isRaining = isRaining
        self.onReveal = onReveal
        self.onEvaluate = onEvaluate
    }

    /// 단독 프리뷰 및 간편 테스트용 생성자
    public init(word: Word, palette: WeatherSkyPalette = WeatherSkyPalette.resolve(condition: .rain, timeOfDay: .night)) {
        self.init(
            item: SessionQueueItem(word: word, snapshot: WordMemorySnapshot(wordId: word.id)),
            catalog: .shared,
            palette: palette,
            isRaining: true
        )
    }

    private var word: Word { item.word }
    private var quizzedSense: WordSense { item.presentedSense }
    private var accentColor: Color { palette.accentColor }

    public var body: some View {
        VStack(spacing: 0) {
            // 1) 콘텐츠 영역 (내용이 길면 이 영역 안에서만 스크롤)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    termHeader
                    if isRevealed {
                        revealedMeaningBlock
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    exampleBlock
                    if isRevealed && !item.supplementarySenses.isEmpty {
                        supplementarySensesSection
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            // 2) 고정 액션 슬롯 (위치·크기 불변)
            actionSlot
                .frame(height: Self.actionSlotHeight)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .padding(.top, 6)
        }
        .frame(maxWidth: 380)
        .frame(maxHeight: .infinity)
        .foregroundStyle(palette.primaryTextColor)
        .hareruGlass(
            in: RoundedRectangle(cornerRadius: 38, style: .continuous),
            tint: palette.glassTintColor
        )
        .overlay {
            CardGlassRaindropOverlay(isRaining: isRaining, isRevealed: isRevealed)
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        }
        .shadow(color: .black.opacity(0.16), radius: 26, y: 14)
        .onAppear {
            isRevealed = false
            exampleVisible = false
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                exampleVisible = true
            }
        }
        .onDisappear {
            speaker.stop()
        }
        .sheet(item: $detailSheetKanji) { kanji in
            KanjiDetailSheetView(
                kanjiInfo: kanji,
                usage: detailSheetUsage,
                currentWordId: word.id,
                accentColor: accentColor
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 표제어 (JLPT 명조체) + 정답 공개 후에만 발음·음성 노출

    private var termHeader: some View {
        VStack(spacing: 10) {
            tappableTermGlyphs

            if isRevealed {
                HStack(spacing: 8) {
                    Text(word.reading)
                        .jlptExampleFont(size: 18, weight: .medium)
                        .foregroundStyle(palette.secondaryTextColor)

                    Button {
                        speaker.playSingle(fileName: word.termAudioFile, voice: quizzedSense.voice)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                            .padding(7)
                            .background(.white.opacity(0.16), in: Circle())
                    }
                    .buttonStyle(.plain)

                    if !word.hasKanji, let note = word.nonKanjiNote {
                        Button {
                            showNonKanjiPopover = true
                        } label: {
                            Text(note.kind == .loanword ? "원어" : "어원")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.16), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showNonKanjiPopover) {
                            NonKanjiOriginPopoverView(term: word.term, note: note)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    /// 정답 공개 후 한자 글자만 개별 터치 가능하게 분리 렌더링
    private var tappableTermGlyphs: some View {
        HStack(spacing: 2) {
            ForEach(word.termGlyphs) { glyph in
                let canTapKanji = isRevealed && glyph.isKanji && catalog.kanjiInfo(for: glyph.character) != nil
                Button {
                    guard canTapKanji else { return }
                    activeKanjiPopoverIndex = glyph.index
                } label: {
                    VStack(spacing: 3) {
                        Text(glyph.character)
                            .jlptTermFont(size: 50, weight: .bold)
                        Capsule()
                            .fill(canTapKanji ? accentColor.opacity(0.8) : Color.clear)
                            .frame(width: 18, height: 3)
                    }
                }
                .buttonStyle(.plain)
                .allowsHitTesting(canTapKanji)
                .popover(
                    isPresented: Binding(
                        get: { activeKanjiPopoverIndex == glyph.index },
                        set: { if !$0 { activeKanjiPopoverIndex = nil } }
                    )
                ) {
                    if let info = catalog.kanjiInfo(for: glyph.character) {
                        let usage = word.kanjiUsage(for: glyph.character)
                        KanjiQuickPopoverView(
                            kanjiInfo: info,
                            usage: usage,
                            accentColor: accentColor
                        ) {
                            activeKanjiPopoverIndex = nil
                            detailSheetUsage = usage
                            detailSheetKanji = info
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
    }

    // MARK: - 뜻 (정답 공개 후)

    private var revealedMeaningBlock: some View {
        VStack(spacing: 4) {
            if let pos = quizzedSense.partOfSpeech {
                Text(pos)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
            }
            Text(quizzedSense.meaning)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 예문 (앞면: 후리가나 없는 순수 예문만 / 뒷면: 후리가나 + 한국어 해석 + 음성)

    private var exampleBlock: some View {
        VStack(spacing: 12) {
            if isRevealed {
                HStack(alignment: .top, spacing: 8) {
                    PhraseBoxFuriganaView(
                        segments: word.segments(for: quizzedSense),
                        exampleProgress: 1.0,
                        furiganaProgress: 1.0,
                        isRevealed: true
                    )

                    Button {
                        speaker.playSingle(fileName: quizzedSense.exampleAudioFile, voice: quizzedSense.voice)
                    } label: {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.title3)
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }

                SplitText(
                    before: quizzedSense.translation.before,
                    answer: quizzedSense.translation.answer,
                    after: quizzedSense.translation.after,
                    otherProgress: 1.0,
                    answerProgress: 1.0,
                    accentColor: accentColor
                )
                .font(.callout)
                .foregroundStyle(palette.secondaryTextColor)
                .transition(.opacity)
            } else {
                Text(quizzedSense.example)
                    .jlptExampleFont(size: 18, weight: .medium)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .opacity(exampleVisible ? 1 : 0)
                    .blur(radius: exampleVisible ? 0 : 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var supplementarySensesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("함께 쓰이는 다른 의미")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)

            ForEach(item.supplementarySenses) { sense in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("뜻 \(sense.senseNumber)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.16), in: Capsule())

                        Text(sense.meaning)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Button {
                            speaker.playSingle(fileName: sense.exampleAudioFile, voice: sense.voice)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryTextColor)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(sense.example)
                        .jlptExampleFont(size: 13)

                    Text(sense.translation.fullText)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryTextColor)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - 고정 액션 슬롯: '정답 보기' ➔ 같은 자리에서 4개 평가 버튼으로 분할 모핑

    private var actionSlot: some View {
        HareruGlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                if !isRevealed {
                    Button {
                        revealAnswer()
                    } label: {
                        Label("정답 보기", systemImage: "eye.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.isDarkSky ? Color.black.opacity(0.82) : Color.white)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .matchedGeometryEffect(id: "slot.good", in: actionSlotNamespace)
                    .transition(.opacity)
                } else {
                    evaluationButton(.again, icon: "xmark")
                    evaluationButton(.hard, icon: "questionmark")
                    evaluationButton(.good, icon: "checkmark")
                        .matchedGeometryEffect(id: "slot.good", in: actionSlotNamespace)
                    evaluationButton(.easy, icon: "bolt.fill")
                }
            }
        }
    }

    private func evaluationButton(_ button: ReviewButton, icon: String) -> some View {
        Button {
            speaker.stop()
            onEvaluate?(button)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                Text(button.koreanTitle)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .background(palette.buttonColor(for: button).opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
        )
        .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    // MARK: - 정답 공개

    private func revealAnswer() {
        onReveal?()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            isRevealed = true
        }
        speaker.playTermThenExample(
            for: word,
            sense: quizzedSense,
            initialDelay: CardTimingConfig.standard.initialDelayBeforeTermAudio,
            gapDelay: CardTimingConfig.standard.gapBetweenTermAndExampleAudio
        )
    }
}

#Preview("카드 (비 오는 밤)") {
    ZStack {
        let palette = WeatherSkyPalette.resolve(condition: .rain, timeOfDay: .night)
        WeatherSkyCanvasView(condition: .rain, timeOfDay: .night, palette: palette)
        WordCardView(word: .amai, palette: palette)
            .padding(.horizontal, 16)
            .padding(.vertical, 60)
    }
}
