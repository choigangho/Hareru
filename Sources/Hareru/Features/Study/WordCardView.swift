import SwiftUI

// MARK: - 단일 단어 카드 뷰
// - 전면(정답 공개 전): 후리가나, 한국어 해석, 발음 힌트 일절 없음! 순수 한자/단어 + 순수 예문만 제시.
// - 정답 보기 클릭 시: 카드 하단 동일 위치에서 4버튼(모르겠음 / 애매함 / 알고있음 / 쉬움)으로 부드럽게 제자리 모핑.
// - 다의어가 많아도 하단 버튼 영역은 고정되며 내용 영역만 스크롤.
// - 비/태풍 날씨일 경우 유리창 빗방울 오버레이 및 정답 공개 시 빗방울 흘러내림 연출.
public struct WordCardView: View {
    public let item: SessionQueueItem
    public let timing: CardTimingConfig
    public let catalog: CatalogRepository
    public var onReveal: (() -> Void)?
    public var onEvaluate: ((ReviewButton) -> Void)?

    @State private var isRevealed: Bool = false
    @State private var revealProgress: CGFloat = 0.0

    // 한자 터치 팝오버 및 상세 시트
    @State private var activeKanjiPopoverIndex: Int?
    @State private var showNonKanjiPopover: Bool = false
    @State private var detailSheetKanji: KanjiInfo?
    @State private var detailSheetUsage: WordKanjiUsage?

    @State private var speaker = SpeechPlayer()
    @Environment(\.scenePhase) private var scenePhase

    private var weatherEngine = WeatherAtmosphereEngine.shared

    public init(
        item: SessionQueueItem,
        timing: CardTimingConfig = .standard,
        catalog: CatalogRepository = .shared,
        onReveal: (() -> Void)? = nil,
        onEvaluate: ((ReviewButton) -> Void)? = nil
    ) {
        self.item = item
        self.timing = timing
        self.catalog = catalog
        self.onReveal = onReveal
        self.onEvaluate = onEvaluate
    }

    /// 프리뷰 및 테스트용
    public init(word: Word, timing: CardTimingConfig = .standard) {
        self.init(
            item: SessionQueueItem(word: word, snapshot: WordMemorySnapshot(wordId: word.id)),
            timing: timing,
            catalog: .shared
        )
    }

    private var word: Word { item.word }
    private var quizzedSense: WordSense { item.presentedSense }
    private var palette: WeatherSkyPalette { weatherEngine.activePalette }

    public var body: some View {
        VStack(spacing: 0) {
            // A. 상단 카드 콘텐츠 (다의어일 때만 스크롤 가능, 하단 액션 영역은 항상 제자리 고정)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 1. 메인 표제어 (JLPT 시험지 인쇄 명조 서체 적용)
                    tappableTermHeader

                    // 2. 단어 발음: 앞면에서는 완전 비공개(스포일러 방지) -> 정답 보기 시에만 노출
                    if isRevealed {
                        HStack(spacing: 8) {
                            Text(word.reading)
                                .jlptExampleFont(size: 20, weight: .semibold)
                                .foregroundStyle(palette.secondaryTextColor)

                            // 발음 오디오 재생 버튼
                            Button {
                                speaker.playSingle(fileName: word.termAudioFile, voice: quizzedSense.voice)
                            } label: {
                                Image(systemName: "speaker.wave.2.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(palette.accentColor)
                            }
                            .buttonStyle(.plain)

                            if !word.hasKanji, let note = word.nonKanjiNote {
                                Button {
                                    showNonKanjiPopover = true
                                } label: {
                                    Text(note.kind == .loanword ? "외래어" : "어원")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(.white.opacity(0.18), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .popover(isPresented: $showNonKanjiPopover) {
                                    NonKanjiOriginPopoverView(term: word.term, note: note)
                                        .presentationCompactAdaptation(.popover)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }

                    Divider()
                        .background(palette.secondaryTextColor.opacity(0.25))

                    // 3. 단어 뜻 (정답 공개 시에만 노출)
                    if isRevealed {
                        VStack(spacing: 4) {
                            if let pos = quizzedSense.partOfSpeech {
                                Text(pos)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(palette.secondaryTextColor)
                            }
                            Text(quizzedSense.meaning)
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(palette.primaryTextColor)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 4. 예문: 앞면에서는 후리가나/해석 없이 순수 일본어 원문만 노출!
                    VStack(spacing: 10) {
                        if isRevealed {
                            // 정답 공개 후: 후리가나 어절 박스 + 해석 + 음성 해금
                            VStack(spacing: 8) {
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
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.footnote)
                                            .padding(6)
                                            .background(palette.accentColor.opacity(0.22), in: Circle())
                                            .foregroundStyle(palette.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Text(quizzedSense.translation.fullText)
                                    .font(.subheadline)
                                    .foregroundStyle(palette.secondaryTextColor)
                                    .multilineTextAlignment(.center)
                            }
                            .transition(.opacity)
                        } else {
                            // 정답 공개 전: 후리가나 일절 없는 순수 일본어 예문 (진짜 실력으로 읽기)
                            Text(quizzedSense.example)
                                .jlptExampleFont(size: 19, weight: .medium)
                                .lineSpacing(6)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(palette.primaryTextColor)
                                .padding(.horizontal, 8)
                        }
                    }

                    // 5. 다의어 서브 의미 (정답 공개 시 하단에 확장)
                    if isRevealed && !item.supplementarySenses.isEmpty {
                        supplementarySensesSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: 460)

            Divider()
                .background(palette.secondaryTextColor.opacity(0.2))

            // B. 하단 액션 버튼 영역 (정답 보기 -> 4버튼 제자리 고정 모핑)
            bottomMorphingActionBar
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
        }
        .frame(maxWidth: 360)
        .hareruGlass(
            in: RoundedRectangle(cornerRadius: 32, style: .continuous),
            tint: palette.glassTintColor
        )
        .overlay(
            CardGlassRaindropOverlay(
                isRaining: weatherEngine.activeCondition.hasRaindropsOnGlass,
                isRevealed: isRevealed
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
        .shadow(color: .black.opacity(palette.isDarkSky ? 0.35 : 0.12), radius: 25, y: 12)
        .onAppear {
            resetState()
        }
        .onDisappear {
            speaker.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                speaker.stop()
            }
        }
        .sheet(item: $detailSheetKanji) { kanji in
            KanjiDetailSheetView(
                kanjiInfo: kanji,
                usage: detailSheetUsage,
                currentWordId: word.id,
                accentColor: palette.accentColor
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 표제어 헤더 (JLPT 시험지 인쇄 명조 서체)

    private var tappableTermHeader: some View {
        HStack(spacing: 2) {
            ForEach(word.termGlyphs) { glyph in
                let canTapKanji = isRevealed && glyph.isKanji && catalog.kanjiInfo(for: glyph.character) != nil
                Button {
                    guard canTapKanji else { return }
                    activeKanjiPopoverIndex = glyph.index
                } label: {
                    VStack(spacing: 4) {
                        Text(glyph.character)
                            .jlptTermFont(size: 46, weight: .bold)
                            .foregroundStyle(palette.primaryTextColor)

                        if canTapKanji {
                            Capsule()
                                .fill(palette.accentColor)
                                .frame(width: 16, height: 3)
                        } else {
                            Capsule().fill(Color.clear).frame(height: 3)
                        }
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
                            accentColor: palette.accentColor
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

    // MARK: - 다의어 보조 의미 섹션

    private var supplementarySensesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("다른 의미")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)

            ForEach(item.supplementarySenses) { sense in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("뜻 \(sense.senseNumber)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.18), in: Capsule())

                        Text(sense.meaning)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryTextColor)

                        Spacer()

                        Button {
                            speaker.playSingle(fileName: sense.exampleAudioFile, voice: sense.voice)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryTextColor)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(sense.example)
                        .jlptExampleFont(size: 13, weight: .medium)
                        .foregroundStyle(palette.secondaryTextColor)

                    Text(sense.translation.fullText)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryTextColor.opacity(0.85))
                }
                .padding(10)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 하단 제자리 모핑 액션 바 ('정답 보기' -> '모르겠음 / 애매함 / 알고있음 / 쉬움')

    @ViewBuilder
    private var bottomMorphingActionBar: some View {
        ZStack {
            if !isRevealed {
                Button {
                    revealAnswer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                        Text("정답 보기")
                            .fontWeight(.bold)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(palette.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(palette.isDarkSky ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            } else {
                HStack(spacing: 8) {
                    evaluationOptionButton(.again, title: "모르겠음", icon: "xmark")
                    evaluationOptionButton(.hard, title: "애매함", icon: "questionmark")
                    evaluationOptionButton(.good, title: "알고있음", icon: "checkmark")
                    evaluationOptionButton(.easy, title: "쉬움", icon: "bolt.fill")
                }
                .frame(height: 52)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.05)),
                    removal: .opacity.combined(with: .scale(scale: 1.05))
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isRevealed)
    }

    private func evaluationOptionButton(_ button: ReviewButton, title: String, icon: String) -> some View {
        let buttonColor = palette.buttonColor(for: button)

        return Button {
            speaker.stop()
            onEvaluate?(button)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(buttonColor.opacity(0.88), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 내부 상태 제어

    private func resetState() {
        isRevealed = false
        revealProgress = 0.0
    }

    private func revealAnswer() {
        onReveal?()
        withAnimation(.easeOut(duration: 0.25)) {
            isRevealed = true
            revealProgress = 1.0
        }

        speaker.playTermThenExample(
            for: word,
            sense: quizzedSense,
            initialDelay: timing.initialDelayBeforeTermAudio,
            gapDelay: timing.gapBetweenTermAndExampleAudio
        )
    }
}
