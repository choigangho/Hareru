import SwiftUI

// MARK: - 가상 일본인 SMS 미션 스테이지 화면 (SPEC.md §1.3)
public struct SMSGameView: View {
    @State private var engine: SMSEpisodeEngine
    @State private var showTranslations: Bool = true
    @State private var speaker = SpeechPlayer()
    public var onCompleteEpisode: ((SMSEpisode, Int) -> Void)?

    public init(
        episode: SMSEpisode = .buchouIzakaya,
        onCompleteEpisode: ((SMSEpisode, Int) -> Void)? = nil
    ) {
        _engine = State(initialValue: SMSEpisodeEngine(episode: episode))
        self.onCompleteEpisode = onCompleteEpisode
    }

    private var accentColor: Color {
        engine.episode.palette.accentColor
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1) 상단 캐릭터 프로필 & 호감도(기분) 게이지 헤더
            characterHeader

            // 2) 현재 턴 미션 가이드 배너
            if let turn = engine.currentTurn, !engine.isEpisodeCleared {
                missionBanner(for: turn)
            }

            // 3) 대화 타임라인 (상대 말풍선 · 스탬프 · 음성 재생 · 입력 중••• · 내 말풍선 + 1줄 코칭 배지)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(engine.messages) { msg in
                            messageRow(msg)
                                .id(msg.id)
                        }

                        if engine.isNPCTyping {
                            typingIndicatorBubble
                                .id("typing_indicator")
                        }

                        if engine.isEpisodeCleared {
                            stageClearCard
                                .id("stage_clear_card")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: engine.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        if engine.isEpisodeCleared {
                            proxy.scrollTo("stage_clear_card", anchor: .bottom)
                        } else if let lastId = engine.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: engine.isNPCTyping) { _, typing in
                    if typing {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("typing_indicator", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 4) 하단 한글 발음 자동 변환 입력기 (후보 칩 + 실시간 일본어 변환 미리보기 + 입력창)
            if !engine.isEpisodeCleared {
                hangulSmartInputBar
            }
        }
        .background(
            LinearGradient(
                colors: [
                    engine.episode.palette.swiftUIColors[1].opacity(0.45),
                    Color.secondary.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            if let firstAudio = engine.messages.first?.audioFile {
                speaker.playSingle(fileName: firstAudio, voice: engine.episode.voice)
            }
        }
        .onDisappear {
            speaker.stop()
        }
    }

    // MARK: - 1) 상단 헤더 & 호감도 게이지

    private var characterHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(engine.episode.voice.label.prefix(1)))
                            .font(.headline.bold())
                            .foregroundStyle(accentColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(engine.episode.voice.label)
                            .font(.headline)
                        Text(engine.isEpisodeCleared ? "CLEAR" : "TURN \(engine.currentTurnIndex + 1)/\(engine.totalTurns)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.16), in: Capsule())
                            .foregroundStyle(accentColor)
                    }
                    Text(engine.episode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showTranslations.toggle()
                } label: {
                    Label(showTranslations ? "해석 켜짐" : "해석 끔", systemImage: "character.bubble")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // 호감도(기분) 게이지 바
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.pink)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.secondary.opacity(0.2))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(engine.affectionScore) / 100.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.affectionScore)
                    }
                }
                .frame(height: 7)

                Text("\(engine.affectionScore)%")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - 2) 미션 가이드 배너

    private func missionBanner(for turn: SMSTurnStage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(turn.missionGuide)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text("한글 발음 예: \"\(turn.sampleHangulHint)\"")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button("예시 자동 입력") {
                            engine.inputText = turn.sampleHangulHint
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accentColor)
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.10))
    }

    // MARK: - 3) 말풍선 및 스탬프 · 코칭 배지

    @ViewBuilder
    private func messageRow(_ message: SMSChatMessage) -> some View {
        switch message.sender {
        case .npc:
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(engine.episode.voice.label.prefix(1)))
                            .font(.caption.bold())
                            .foregroundStyle(accentColor)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    if let stamp = message.stamp {
                        Text(stamp.rawValue)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.18), in: Capsule())
                            .foregroundStyle(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(message.japaneseText)
                                .font(.callout.weight(.medium))

                            if let audioFile = message.audioFile {
                                Button {
                                    speaker.playSingle(fileName: audioFile, voice: engine.episode.voice)
                                } label: {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if showTranslations, let ko = message.koreanTranslation {
                            Text(ko)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Spacer(minLength: 36)
            }

        case .player:
            HStack {
                Spacer(minLength: 36)

                VStack(alignment: .trailing, spacing: 5) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(message.japaneseText)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)

                        if let rawHangul = message.rawHangulInput {
                            Text("한글 발음: \(rawHangul)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // 내 말풍선 하단 1줄 코칭 배지 (SPEC.md §1.3)
                    if let coaching = message.coachingTip {
                        Text(coaching)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private var typingIndicatorBubble: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(accentColor.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "ellipsis.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                )

            Text("\(engine.episode.voice.label) 입력 중•••")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())

            Spacer()
        }
    }

    private var stageClearCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            Text("SMS 미션 클리어!")
                .font(.headline.bold())

            Text("\(engine.episode.voice.label)과의 호감도 \(engine.affectionScore)% 달성")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("다시 대화하기") {
                    engine.startEpisode()
                }
                .buttonStyle(.bordered)

                if let onCompleteEpisode {
                    Button("결과 저장 & 목록으로") {
                        onCompleteEpisode(engine.episode, engine.affectionScore)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - 4) 한글 발음 → 일본어 자동 변환 입력 바

    private var hangulSmartInputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 실시간 일본어 변환 미리보기 스트립
            if !engine.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    Text("🇯🇵 자동 변환:")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accentColor)

                    Text(engine.convertedPreviewText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // 미션 어휘 추천 변환 칩 가로 스크롤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(engine.liveCandidates) { candidate in
                        Button {
                            engine.applyCandidate(candidate.entry)
                        } label: {
                            HStack(spacing: 4) {
                                Text(candidate.entry.surface)
                                    .font(.caption.weight(.bold))
                                Text("(\(candidate.matchedHangul) · \(candidate.entry.meaning))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 한글 발음 텍스트 필드 + 전송 버튼
            HStack(spacing: 8) {
                TextField("한글로 발음 입력 (예: 칸파이 시마쇼)", text: $engine.inputText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onSubmit {
                        sendMessage()
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(
                            engine.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isNPCTyping
                                ? Color.secondary.opacity(0.4)
                                : accentColor,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(engine.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isNPCTyping)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        engine.sendPlayerInputWithTypingAnimation(typingDelay: 0.55) { audioFile in
            if let audioFile {
                speaker.playSingle(fileName: audioFile, voice: engine.episode.voice)
            }
        }
    }
}

#Preview("SMS 미션 게임") {
    SMSGameView(episode: .buchouIzakaya)
}
