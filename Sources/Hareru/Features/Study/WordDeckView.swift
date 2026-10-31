import SwiftUI
import SwiftData

// MARK: - 탭 1 단어 학습 덱 화면 (FSRS 순환 큐 · 실패 침식 · 졸업 정화 · SMS 티켓 연동)
public struct WordDeckView: View {
    @State private var sessionEngine: StudySessionEngine
    @State private var feedbackBanner: String?
    @State private var cardPresentationId = UUID()
    @Environment(\.scenePhase) private var scenePhase

    public init(engine: StudySessionEngine? = nil) {
        if let engine {
            _sessionEngine = State(initialValue: engine)
        } else {
            let store: MemoryStoreProtocol
            if let container = try? SwiftDataMemoryStore.makeContainer(inMemory: false) {
                store = SwiftDataMemoryStore(container: container)
            } else {
                store = InMemoryMemoryStore()
            }
            _sessionEngine = State(initialValue: StudySessionEngine(store: store))
        }
    }

    private var backgroundColors: [Color] {
        if let item = sessionEngine.currentItem {
            return item.activeColors(maxDailyEncounters: sessionEngine.configuration.maxDailyEncounters)
        }
        return [
            Color(red: 0.96, green: 0.89, blue: 0.72),
            Color(red: 0.99, green: 0.97, blue: 0.93),
            Color(red: 0.35, green: 0.25, blue: 0.18)
        ]
    }

    private var isDeeplyEroded: Bool {
        (sessionEngine.currentItem?.todayErosionCount ?? 0) >= 2
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: cardPresentationId)

            VStack(spacing: 18) {
                headerBar
                    .frame(maxWidth: 360)

                if let banner = feedbackBanner {
                    Text(banner)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                if let activeItem = sessionEngine.currentItem {
                    ScrollView(.vertical, showsIndicators: false) {
                        WordCardView(
                            item: activeItem,
                            timing: .standard,
                            catalog: sessionEngine.catalog,
                            onReveal: {
                                sessionEngine.markAnswerRevealed()
                            },
                            onEvaluate: { button in
                                handleEvaluation(button: button)
                            }
                        )
                        .id(cardPresentationId)
                        .padding(.vertical, 4)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .environment(\.colorScheme, isDeeplyEroded ? .dark : .light)
                } else {
                    sessionCompletedCard
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            if sessionEngine.initialCardCount == 0 {
                sessionEngine.startSession()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                sessionEngine.resumeReactionTimer()
            } else {
                sessionEngine.pauseReactionTimer()
            }
        }
    }

    // MARK: - 상단 진행 헤더

    private var headerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if let item = sessionEngine.currentItem {
                    Label("\(item.word.jlptLevel.rawValue) · \(item.word.category)", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())

                    if item.isAwaitingFinalConfirmation {
                        Text("최종 확인")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.teal.opacity(0.85), in: Capsule())
                            .foregroundStyle(.white)
                    } else if item.todayErosionCount > 0 {
                        Text("침식 \(item.todayErosionCount)단계")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.80), in: Capsule())
                            .foregroundStyle(.white)
                    }
                } else {
                    Label("오늘의 세션 완료", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                let ticketCount = sessionEngine.unconsumedGameTickets().count
                if ticketCount > 0 {
                    Label("\(ticketCount)", systemImage: "ticket.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Text("남은 카드 \(sessionEngine.queue.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isDeeplyEroded ? Color.white.opacity(0.85) : Color.primary.opacity(0.75))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.32))
                    Capsule()
                        .fill(isDeeplyEroded ? Color.red : backgroundColors[2])
                        .frame(width: geo.size.width * CGFloat(sessionEngine.completionProgress))
                        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: sessionEngine.completionProgress)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - 세션 완료 카드

    private var sessionCompletedCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("흐릿하던 기억이 맑게 갰어요!")
                .font(.title3.bold())

            VStack(spacing: 6) {
                Text("오늘 졸업한 단어: \(sessionEngine.graduatedWordIds.count)개")
                    .font(.subheadline.weight(.semibold))
                if !sessionEngine.deferredTodayWordIds.isEmpty {
                    Text("수면 공고화로 내일 이관된 단어: \(sessionEngine.deferredTodayWordIds.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                let tickets = sessionEngine.unconsumedGameTickets().count
                if tickets > 0 {
                    Text("보유 중인 SMS 미션 티켓: \(tickets)장")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                }
            }

            Button {
                let previewStore = InMemoryMemoryStore()
                sessionEngine = StudySessionEngine(store: previewStore)
                sessionEngine.startSession()
                cardPresentationId = UUID()
            } label: {
                Label("샘플 덱 다시 체험하기", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(32)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    // MARK: - 평가 후 피드백 배너 및 다음 카드 전환

    private func handleEvaluation(button: ReviewButton) {
        guard let outcome = sessionEngine.submitEvaluation(button: button) else { return }

        let message: String?
        switch outcome.status {
        case .requeued(_, let encounters, let erosion):
            if erosion > 0 {
                message = "다시 순환합니다 · 조우 \(encounters)/\(sessionEngine.configuration.maxDailyEncounters)"
            } else {
                message = "잠시 후 한 번 더 확인합니다 (\(outcome.grade.displayName))"
            }
        case .confirmationQueued(_, _, let didPurify):
            message = didPurify
                ? "컬러 정화 완료! 세션 마지막에 최종 확인 1회 남았습니다"
                : "세션 마지막에 최종 확인 1회 진행합니다"
        case .graduated(let schedule, let didPurify, _, let ticket):
            if let ticket {
                let voiceLabel = VoiceProfile.preset(forId: ticket.voiceId).label
                message = "졸업! \(voiceLabel) SMS 미션 티켓 획득"
            } else if didPurify {
                message = "침식 정화 & 졸업 완료! (\(schedule.scheduledIntervalDays)일 뒤 복습)"
            } else {
                message = "졸업 완료! (\(outcome.grade.displayName) · \(schedule.scheduledIntervalDays)일 뒤 복습)"
            }
        case .deferredByDailyCap(_, let prescribed):
            message = prescribed
                ? "3일 누적 보류 → 손글씨 처방 노트로 이동했습니다"
                : "오늘 8회 도달 · 수면 후 내일 맑은 머리로 다시 만나요"
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            feedbackBanner = message
            cardPresentationId = UUID()
        }
    }
}

#Preview {
    WordDeckView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
