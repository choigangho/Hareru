import SwiftUI

// MARK: - 단일 단어 카드 뷰 (10초 3단 등속 파도 · 한자 2단계 탐색 · 다의어 · 4버튼 평가)
public struct WordCardView: View {
    public let item: SessionQueueItem
    public let timing: CardTimingConfig
    public let catalog: CatalogRepository
    public var onReveal: (() -> Void)?
    public var onEvaluate: ((ReviewButton) -> Void)?

    @State private var isRevealed: Bool = false
    @State private var revealProgress: CGFloat = 0.0
    @State private var sequenceStartDate: Date = Date()
    @State private var pausedAtDate: Date?
    @State private var accumulatedPauseSeconds: TimeInterval = 0

    // 한자 1단계 말풍선 & 2단계 상세 시트 상태
    @State private var activeKanjiPopoverIndex: Int?
    @State private var showNonKanjiPopover: Bool = false
    @State private var detailSheetKanji: KanjiInfo?
    @State private var detailSheetUsage: WordKanjiUsage?

    @State private var speaker = SpeechPlayer()
    @Environment(\.scenePhase) private var scenePhase

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

    /// 단독 프리뷰 및 간편 테스트용 생성자
    public init(word: Word, timing: CardTimingConfig = .standard) {
        self.init(
            item: SessionQueueItem(word: word, snapshot: WordMemorySnapshot(wordId: word.id)),
            timing: timing,
            catalog: .shared
        )
    }

    private var word: Word { item.word }
    private var quizzedSense: WordSense { item.presentedSense }
    private var accentColor: Color {
        let palette = word.activePalette(for: quizzedSense)
        return item.todayErosionCount > 0
            ? Color(red: 0.85, green: 0.24, blue: 0.30)
            : palette.accentColor
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isRevealed || pausedAtDate != nil)) { context in
            let elapsed = effectiveElapsedSeconds(at: context.date)
            let voiceTagProg = CGFloat(timing.voiceTagProgress(at: elapsed))
            let wave1Prog = CGFloat(timing.wave1Progress(at: elapsed))
            let wave2Prog = CGFloat(timing.wave2Progress(at: elapsed))
            let wave3Prog = CGFloat(timing.wave3Progress(at: elapsed))
            let remainingSec = timing.remainingSeconds(at: elapsed)

            cardContent(
                voiceTagProgress: voiceTagProg,
                wave1Progress: wave1Prog,
                wave2Progress: wave2Prog,
                wave3Progress: wave3Prog,
                remainingSeconds: remainingSec
            )
        }
        .onAppear {
            resetWaveClock()
        }
        .onDisappear {
            speaker.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
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

    // MARK: - 카드 레이아웃 본체

    @ViewBuilder
    private func cardContent(
        voiceTagProgress: CGFloat,
        wave1Progress: CGFloat,
        wave2Progress: CGFloat,
        wave3Progress: CGFloat,
        remainingSeconds: Int
    ) -> some View {
        VStack(spacing: 18) {
            // 상단 카운트다운 및 다의어/한자 조작 안내
            topStatusLine(remainingSeconds: remainingSeconds)

            // 1. 메인 표제어(0.0초 상시 선명) + 정답 보호 발음(`reading`) + 캐릭터 태그(0~3초)
            VStack(spacing: 8) {
                tappableTermHeader

                // 단어 발음(`reading`): 10초가 지나도 열리지 않으며 '정답 보기' 클릭 시 0.25s 해금
                HStack(spacing: 6) {
                    Text(word.reading)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)

                    if !word.hasKanji, let note = word.nonKanjiNote {
                        Button {
                            guard isRevealed else { return }
                            showNonKanjiPopover = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "info.circle")
                                Text(note.kind == .loanword ? "원어" : "어원")
                            }
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isRevealed)
                        .popover(isPresented: $showNonKanjiPopover) {
                            NonKanjiOriginPopoverView(term: word.term, note: note)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                .furiganaBlur(revealProgress)

                // 성우 캐릭터 이름 태그 (0~3초 먼저 암시, 스피커 재생은 정답 공개 후 활성화)
                Button {
                    guard isRevealed else { return }
                    speaker.playSingle(fileName: word.termAudioFile, voice: quizzedSense.voice)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isRevealed ? "speaker.wave.2.fill" : "waveform")
                            .font(.caption)
                        Text(quizzedSense.voice.label)
                            .font(.caption.weight(.semibold))
                    }
                }
                .hareruSecondaryButtonStyle()
                .controlSize(.small)
                .tint(accentColor)
                .allowsHitTesting(isRevealed)
                .hintBlur(isRevealed ? 1.0 : voiceTagProgress)
            }

            Divider()

            // 2. 단어 뜻(`meaning`): 정답 보기 전까지 블러 보호
            VStack(spacing: 4) {
                if let pos = quizzedSense.partOfSpeech, isRevealed {
                    Text(pos)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                Text(quizzedSense.meaning)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .furiganaBlur(revealProgress)
            }

            // 3. 파도 1(예문 0~6초) · 파도 2(주변 문맥 후리가나 2~8초) · 파도 3(한국어 앞/뒤 문맥 4~10초)
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    PhraseBoxFuriganaView(
                        segments: word.segments(for: quizzedSense),
                        exampleProgress: wave1Progress,
                        furiganaProgress: wave2Progress,
                        isRevealed: isRevealed
                    )

                    // 예문 스피커 버튼 (정답 보호 요소: 정답 공개 시 해금)
                    Button {
                        guard isRevealed else { return }
                        speaker.playSingle(fileName: quizzedSense.exampleAudioFile, voice: quizzedSense.voice)
                    } label: {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.title3)
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(isRevealed)
                    .furiganaBlur(revealProgress)
                }

                SplitText(
                    before: quizzedSense.translation.before,
                    answer: quizzedSense.translation.answer,
                    after: quizzedSense.translation.after,
                    otherProgress: isRevealed ? 1.0 : wave3Progress,
                    answerProgress: revealProgress,
                    accentColor: accentColor
                )
                .font(.callout)
            }

            // 4. 다의어 서브 의미 확장 (정답 공개 시 각기 다른 성우 캐릭터와 함께 노출)
            if isRevealed && !item.supplementarySenses.isEmpty {
                supplementarySensesSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 5. 하단 컨트롤: '정답 보기' → 4단계 평가 버튼 ('어려움 / 애매함 / 앎 / 쉬움')
            bottomActionSection
        }
        .padding(24)
        .frame(maxWidth: 360)
        .hareruGlass(
            in: RoundedRectangle(cornerRadius: 38, style: .continuous),
            tint: item.todayErosionCount > 0 ? Color.black.opacity(0.25) : nil
        )
        .shadow(color: .black.opacity(0.14), radius: 24, y: 12)
    }

    // MARK: - 서브 뷰 빌더

    @ViewBuilder
    private func topStatusLine(remainingSeconds: Int) -> some View {
        HStack {
            if isRevealed {
                if word.hasKanji {
                    Label("한자를 터치해 음훈 확인", systemImage: "hand.tap")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("발음과 뜻을 확인하고 평가해 주세요")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else if remainingSeconds > 0 {
                Text("힌트 완성까지 \(remainingSeconds)초")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else {
                Text("문맥 힌트 완성 · 정답을 떠올려 보세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 16)
    }

    /// 정답 공개 후 한자 글자만 개별 터치 가능하게 분리 렌더링
    private var tappableTermHeader: some View {
        HStack(spacing: 2) {
            ForEach(word.termGlyphs) { glyph in
                let canTapKanji = isRevealed && glyph.isKanji && catalog.kanjiInfo(for: glyph.character) != nil
                Button {
                    guard canTapKanji else { return }
                    activeKanjiPopoverIndex = glyph.index
                } label: {
                    VStack(spacing: 2) {
                        Text(glyph.character)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.primary)

                        Capsule()
                            .fill(canTapKanji ? accentColor.opacity(0.65) : Color.clear)
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

    private var supplementarySensesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("함께 쓰이는 다른 의미")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(item.supplementarySenses) { sense in
                let senseAccent = word.categoryPalette.accentColor
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("뜻 \(sense.senseNumber)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(senseAccent.opacity(0.18), in: Capsule())
                            .foregroundStyle(senseAccent)

                        Text(sense.meaning)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Button {
                            speaker.playSingle(fileName: sense.exampleAudioFile, voice: sense.voice)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "speaker.wave.2.fill")
                                Text(sense.voice.label)
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(sense.example)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.9))

                    Text(sense.translation.fullText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var bottomActionSection: some View {
        if !isRevealed {
            Button {
                revealAnswer()
            } label: {
                Label("정답 보기", systemImage: "eye.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .hareruProminentButtonStyle()
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(accentColor)
        } else if onEvaluate != nil {
            HareruGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    evaluationButton(.again, icon: "xmark", tint: .red)
                    evaluationButton(.hard, icon: "questionmark", tint: .orange)
                    evaluationButton(.good, icon: "checkmark", tint: accentColor)
                    evaluationButton(.easy, icon: "bolt.fill", tint: .teal)
                }
            }
        } else {
            Button("다시 가리기") {
                hideForPreview()
            }
            .hareruSecondaryButtonStyle()
            .buttonBorderShape(.capsule)
            .tint(accentColor)
        }
    }

    private func evaluationButton(_ button: ReviewButton, icon: String, tint: Color) -> some View {
        Button {
            speaker.stop()
            onEvaluate?(button)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                Text(button.koreanTitle)
                    .font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .hareruProminentButtonStyle()
        .buttonBorderShape(.roundedRectangle(radius: 18))
        .tint(tint)
    }

    // MARK: - 시간 계산 및 상태 제어

    private func resetWaveClock() {
        isRevealed = false
        revealProgress = 0.0
        sequenceStartDate = Date()
        pausedAtDate = nil
        accumulatedPauseSeconds = 0
    }

    private func effectiveElapsedSeconds(at now: Date) -> Double {
        let endPoint = pausedAtDate ?? now
        let raw = endPoint.timeIntervalSince(sequenceStartDate) - accumulatedPauseSeconds
        return max(0.0, raw)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard !isRevealed else { return }
        if newPhase == .active {
            if let pausedAt = pausedAtDate {
                accumulatedPauseSeconds += Date().timeIntervalSince(pausedAt)
                pausedAtDate = nil
            }
        } else if pausedAtDate == nil {
            pausedAtDate = Date()
            speaker.stop()
        }
    }

    private func revealAnswer() {
        onReveal?()
        withAnimation(.easeOut(duration: timing.answerRevealDuration)) {
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

    private func hideForPreview() {
        speaker.stop()
        resetWaveClock()
    }
}

#Preview("다의어 · 한자 탐색") {
    WordCardView(word: .amai)
        .padding()
        .background(Color.pink.opacity(0.18))
}
