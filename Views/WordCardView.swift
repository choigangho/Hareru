import SwiftUI

// MARK: - 단일 단어 카드 뷰
struct WordCardView: View {
    let word: Word

    // ⏱ 타이머 및 애니메이션 설정값
    static let sequenceDuration: Double = 10.0 // 카드 등장 즉시 시작되는 10초 시퀀스
    static let initialDelayBeforeAudio: Double = 0.5 // "정답 보기" 클릭 후 단어 음성 시작까지 대기(초)
    static let delayBetweenTermAndExample: Double = 0.45 // 단어 음성 종료 후 예문 음성 시작까지 간격(초)

    // 진행도: 0.0(완전 흐림) -> 1.0(완전 선명)
    @State private var hintProgress: CGFloat = 0.0      // 후리가나, 예문, 예문 해설 (10초에 걸쳐 선명)
    @State private var isRevealed: Bool = false         // 정답 보기 여부
    @State private var secondsLeft: Int = Int(sequenceDuration)
    @State private var round: Int = 0
    @State private var speaker = SpeechPlayer()

    private var countdownText: String {
        if !isRevealed && secondsLeft > 0 {
            return "힌트 완성까지 \(secondsLeft)초"
        }
        return " "
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(countdownText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            // 1. 단어 본체 (항상 선명) + 후리가나 (10초 시퀀스에 걸쳐 점진적으로 선명)
            VStack(spacing: 6) {
                Text(word.term)
                    .font(.system(size: 52, weight: .bold))

                // 후리가나(읽는 법): 10초 시퀀스 동안 서서히 선명해짐
                Text(word.reading)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .hintBlur(isRevealed ? 1.0 : hintProgress)

                Button {
                    speaker.playSingle(fileName: word.termAudioFile,
                                       fallbackText: word.term,
                                       voice: word.voice)
                } label: {
                    Label(word.voice.label, systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(word.colors[2])
            }

            Divider()

            // 2. 정답(뜻): 10초 시퀀스와 무관하게 "정답 보기"를 누르기 전까지 블러 대기
            Text(word.meaning)
                .font(.title)
                .fontWeight(.semibold)
                .hintBlur(isRevealed ? 1.0 : 0.0)

            // 3. 예문 (일본어) + 예문 해설 (한국어): 10초 시퀀스에 걸쳐 점진적으로 선명해짐
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(word.example)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .hintBlur(isRevealed ? 1.0 : hintProgress)

                    Button {
                        speaker.playSingle(fileName: word.exampleAudioFile,
                                           fallbackText: word.example,
                                           voice: word.voice)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                // 예문 해석:
                // 앞/뒤 문맥은 10초 시퀀스(hintProgress)를 따르고,
                // 가운데 정답 키워드는 "정답 보기"(isRevealed ? 1.0 : 0.0) 전까지 숨겨짐
                SplitText(before: word.transBefore,
                          answer: word.transAnswer,
                          after: word.transAfter,
                          otherProgress: isRevealed ? 1.0 : hintProgress,
                          answerProgress: isRevealed ? 1.0 : 0.0)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // 4. 정답 보기 버튼
            Button(isRevealed ? "다시 가리기" : "정답 보기") {
                isRevealed ? hide() : reveal()
            }
            .buttonStyle(.borderedProminent)
            .tint(word.colors[2])
        }
        .padding(32)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onDisappear {
            speaker.stop()
        }
        // 카드가 나타나거나 round가 갱신되면 10초 시퀀스 즉시 시작
        .task(id: round) {
            await startTenSecondSequence()
        }
    }

    // MARK: - 인터랙션 및 애니메이션 동작

    /// 정답 보기 클릭 시 동작
    private func reveal() {
        isRevealed = true
        withAnimation(.easeOut(duration: 0.25)) {
            hintProgress = 1.0
        }

        // 정답 보기를 누르고 지정된 시간(0.5초) 뒤 단어 음성 시작 -> 끝나고 예문 음성 자동 재생
        speaker.playTermThenExample(for: word,
                                    initialDelay: Self.initialDelayBeforeAudio,
                                    gapDelay: Self.delayBetweenTermAndExample)
    }

    /// 다시 가리기 클릭 시 동작
    private func hide() {
        speaker.stop()
        isRevealed = false
        hintProgress = 0.0
        secondsLeft = Int(Self.sequenceDuration)
        round += 1 // 10초 시퀀스 재시작
    }

    /// 카드 시작과 동시에 작동하는 10초 점진적 선명화(그라데이션) 시퀀스
    private func startTenSecondSequence() async {
        hintProgress = 0.0
        secondsLeft = Int(Self.sequenceDuration)

        // 1) 시작과 동시에 10초 동안 hintProgress가 0(흐림)에서 1(선명)으로 선형 보간
        withAnimation(.linear(duration: Self.sequenceDuration)) {
            hintProgress = 1.0
        }

        // 2) 1초마다 남은 초(카운트다운) 갱신
        for sec in stride(from: Int(Self.sequenceDuration), through: 0, by: -1) {
            if isRevealed { return }
            withAnimation {
                secondsLeft = sec
            }
            if sec > 0 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }
}

#Preview {
    WordCardView(word: .beer)
        .padding()
        .background(Color.orange.opacity(0.2))
}
