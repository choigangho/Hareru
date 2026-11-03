import SwiftUI

// MARK: - 단일 단어 카드 = 스캐너 위 종이 (앞면: 표제어 + 후리가나 없는 예문만 / 뒷면: 발음·뜻·후리가나·해석·다의어·한자)
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
    @State private var voiceNicknameVisible: Bool = false

    // 한자 1단계 말풍선 & 2단계 상세 시트 상태
    @State private var activeKanjiPopoverIndex: Int?
    @State private var showNonKanjiPopover: Bool = false
    @State private var detailSheetKanji: KanjiInfo?
    @State private var detailSheetUsage: WordKanjiUsage?

    @State private var speaker = SpeechPlayer()
    /// 스캔 빛줄 위치 (카드가 나올 때 · 정답을 볼 때 위 → 아래 한 번)
    @State private var scanProgress: CGFloat = 2
    @Namespace private var actionSlotNamespace

    private static let actionSlotHeight: CGFloat = 66
    private static let timing = CardTimingConfig.standard

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
    /// 종이 위 강조는 붉은 펜 (하늘 팔레트 대신 — 카드는 스캐너 위 종이, ART_BIBLE §7)
    private var accentColor: Color { RetroColor.paperRed }

    public var body: some View {
        VStack(spacing: 8) {
            // 1) 콘텐츠 영역 = 스캐너 위 종이 (내용이 길면 종이 안에서만 스크롤)
            RetroScannedPaper(scanProgress: scanProgress) {
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
            }
            .overlay {
                CardGlassRaindropOverlay(isRaining: isRaining, isRevealed: isRevealed)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .allowsHitTesting(false)
            }

            // 2) 고정 액션 슬롯 (위치·크기 불변) — 입체 키캡
            actionSlot
                .frame(height: Self.actionSlotHeight)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: 380)
        .frame(maxHeight: .infinity)
        .foregroundStyle(RetroColor.paperInk)
        .onAppear {
            isRevealed = false
            exampleVisible = false
            voiceNicknameVisible = false
            runScan()
            // 음성 캐릭터 별명(6.5초)이 먼저, 순수 예문(10초)이 더 천천히 선명해짐
            withAnimation(Self.slowRevealCurve(duration: Self.timing.voiceTagDuration)) {
                voiceNicknameVisible = true
            }
            withAnimation(Self.slowRevealCurve(duration: Self.timing.exampleFadeDuration)) {
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

    /// 스캔 빛줄을 종이 위에서 아래로 한 번 지나가게 함
    private func runScan() {
        scanProgress = -0.04
        withAnimation(.linear(duration: 1.1)) { scanProgress = 1.04 }
    }

    // MARK: - 표제어 (JLPT 명조체) + 정답 공개 후에만 발음·음성 노출

    /// 초반엔 윤곽만 아른거리다 끝에서 또렷해지는 easeOut 곡선 (`CardTimingConfig.waveCurveExponent` 근사)
    private static func slowRevealCurve(duration: Double) -> Animation {
        .timingCurve(0.3, 0.55, 0.55, 1.0, duration: duration)
    }

    private var termHeader: some View {
        VStack(spacing: 10) {
            if quizzedSense.voice.isAssigned {
                voiceNicknameTag
            }

            tappableTermGlyphs

            if isRevealed {
                // 읽기는 표제어 위 루비로 올라갔으므로 이 줄에는 스피커(와 어원 배지)만 둠
                HStack(spacing: 8) {
                    SpeakerHitButton(accessibilityLabel: "단어 발음 듣기") {
                        speaker.playSingle(fileName: word.termAudioFile, voice: quizzedSense.voice)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                            .padding(7)
                            .background(RetroColor.paperInk.opacity(0.08), in: Circle())
                    }

                    if !word.hasKanji, let note = word.nonKanjiNote {
                        Button {
                            showNonKanjiPopover = true
                        } label: {
                            Text(note.kind == .loanword ? "원어" : "어원")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RetroColor.paperInk.opacity(0.08), in: Capsule())
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

    /// 이 뜻의 음성을 맡은 캐릭터 별명 (앞면에서 6.5초에 걸쳐 서서히 등장)
    private var voiceNicknameTag: some View {
        let isShown = isRevealed || voiceNicknameVisible
        return Label(quizzedSense.voice.label, systemImage: "mic.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(RetroColor.paperInkDim)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RetroColor.paperInk.opacity(0.07), in: Capsule())
            .opacity(isShown ? 1 : 0)
            .blur(radius: isShown ? 0 : 4)
            .accessibilityLabel("음성 캐릭터 \(quizzedSense.voice.label)")
    }

    /// 정답 공개 후 각 한자(또는 숙자훈 묶음) 바로 위 가운데에 후리가나를 얹고, 한자 글자만 개별 터치 가능
    /// 루비 줄 높이는 앞면에서도 미리 확보해 정답 공개 순간 표제어가 위아래로 튀지 않게 함
    private var tappableTermGlyphs: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(word.termRubyRuns) { run in
                VStack(spacing: 0) {
                    Text(run.reading ?? " ")
                        .jlptFuriganaFont(size: 15)
                        .foregroundStyle(RetroColor.paperInkDim)
                        .fixedSize()
                        .opacity(isRevealed && run.reading != nil ? 1 : 0)

                    HStack(spacing: 2) {
                        ForEach(run.glyphs) { glyph in
                            termGlyphButton(glyph)
                        }
                    }
                }
            }
        }
    }

    private func termGlyphButton(_ glyph: TermGlyph) -> some View {
        let canTapKanji = isRevealed && glyph.isKanji && catalog.kanjiInfo(for: glyph.character) != nil
        return Button {
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

    // MARK: - 뜻 (정답 공개 후)

    private var revealedMeaningBlock: some View {
        VStack(spacing: 4) {
            if let pos = quizzedSense.partOfSpeech {
                Text(pos)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RetroColor.paperInkDim)
            }
            Text(quizzedSense.meaning)
                .font(.system(.title2, design: .serif).weight(.bold))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 예문 (앞면: 후리가나 없는 순수 예문만 / 뒷면: 후리가나 + 한국어 해석 + 음성)

    private var exampleBlock: some View {
        VStack(spacing: 12) {
            if !quizzedSense.hasExample {
                Text(WordSense.examplePendingNotice)
                    .font(.callout)
                    .foregroundStyle(RetroColor.paperInkDim)
            } else if isRevealed {
                // 예문은 카드 폭 전체를 쓰고(스피커가 옆에서 줄 배치를 밀지 않도록), 스피커는 해석 줄 오른쪽에 둠
                PhraseBoxFuriganaView(
                    segments: word.segments(for: quizzedSense),
                    exampleProgress: 1.0,
                    furiganaProgress: 1.0,
                    isRevealed: true
                )

                HStack(alignment: .center, spacing: 6) {
                    SplitText(
                        before: quizzedSense.translation.before,
                        answer: quizzedSense.translation.answer,
                        after: quizzedSense.translation.after,
                        otherProgress: 1.0,
                        answerProgress: 1.0,
                        accentColor: accentColor
                    )
                    .font(.callout)
                    .foregroundStyle(RetroColor.paperInkDim)
                    .frame(maxWidth: .infinity)

                    SpeakerHitButton(accessibilityLabel: "예문 듣기") {
                        speaker.playSingle(fileName: quizzedSense.exampleAudioFile, voice: quizzedSense.voice)
                    } label: {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.title2)
                            .foregroundStyle(accentColor)
                    }
                }
                .transition(.opacity)
            } else {
                Text(quizzedSense.example)
                    .jlptExampleFont(size: 18, weight: .medium)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .opacity(exampleVisible ? 1 : 0)
                    .blur(radius: exampleVisible ? 0 : 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RetroColor.paperInk.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var supplementarySensesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("함께 쓰이는 다른 의미")
                .font(.caption.weight(.bold))
                .foregroundStyle(RetroColor.paperInkDim)

            ForEach(item.supplementarySenses) { sense in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("뜻 \(sense.senseNumber)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RetroColor.paperInk.opacity(0.08), in: Capsule())

                        Text(sense.meaning)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        if sense.hasExample {
                            SpeakerHitButton(accessibilityLabel: "뜻 \(sense.senseNumber) 예문 듣기") {
                                speaker.playSingle(fileName: sense.exampleAudioFile, voice: sense.voice)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(RetroColor.paperInkDim)
                            }
                        }
                    }

                    if sense.hasExample {
                        Text(sense.example)
                            .jlptExampleFont(size: 13)

                        Text(sense.translation.fullText)
                            .font(.caption2)
                            .foregroundStyle(RetroColor.paperInkDim)
                    } else {
                        Text(WordSense.examplePendingNotice)
                            .font(.caption2)
                            .foregroundStyle(RetroColor.paperInkDim)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RetroColor.paperInk.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    // MARK: - 고정 액션 슬롯: '정답 보기' ➔ 같은 자리에서 4개 평가 버튼으로 분할 모핑

    private var actionSlot: some View {
        HStack(spacing: 6) {
            if !isRevealed {
                Button {
                    revealAnswer()
                } label: {
                    HStack(spacing: 10) {
                        RetroSprite(name: "rt_glyph_eye", animated: false)
                        Text("정답 보기").font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(RetroKeyStyle(tone: .cream))
                .matchedGeometryEffect(id: "slot.good", in: actionSlotNamespace)
                .transition(.opacity)
            } else {
                evaluationButton(.again)
                evaluationButton(.hard)
                evaluationButton(.good)
                    .matchedGeometryEffect(id: "slot.good", in: actionSlotNamespace)
                evaluationButton(.easy)
            }
        }
    }

    /// 네 버튼 모두 같은 숯색 키캡 — 색으로 좋고 나쁨을 가르지 않고, 키 위 LED 막대 칸 수(1~4)로만 강도를 보여 줌
    private func evaluationButton(_ button: ReviewButton) -> some View {
        Button {
            speaker.stop()
            onEvaluate?(button)
        } label: {
            VStack(spacing: 4) {
                RetroSprite(name: "rt_ledbar_\(button.retroLevel)")
                Text(button.koreanTitle)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(RetroKeyStyle(tone: .charcoal))
        .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    // MARK: - 정답 공개

    private func revealAnswer() {
        onReveal?()
        runScan()
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

// MARK: - 아이콘은 작게 두되 주변 44pt 원형 반경까지 터치로 인정하는 스피커 버튼
struct SpeakerHitButton<Label: View>: View {
    private static var hitDiameter: CGFloat { 44 }

    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(minWidth: Self.hitDiameter, minHeight: Self.hitDiameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
