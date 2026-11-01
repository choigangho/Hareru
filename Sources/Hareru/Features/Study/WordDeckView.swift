import SwiftUI
import SwiftData

// MARK: - 탭 1 단어 학습 허브 & 덱 화면
// 앱을 켰을 때 바로 단어 카드가 뜨지 않고, 먼저 이전 학습 기록·남은 시험일 계획·진도 동향을 보여준 뒤
// 사용자가 '이어서 학습하기' 또는 '오늘의 세션 시작하기'를 선택해 카드 덱으로 진입합니다.
public struct WordDeckView: View {
    @State private var sessionEngine: StudySessionEngine
    @State private var isStudyingCards: Bool = false
    @State private var feedbackBanner: String?
    @State private var cardPresentationId = UUID()
    @State private var showClearCelebration: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    private let weatherEngine: WeatherAtmosphereEngine

    public init(
        engine: StudySessionEngine? = nil,
        weatherEngine: WeatherAtmosphereEngine = .shared,
        startImmediatelyInDeck: Bool = false
    ) {
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
        _isStudyingCards = State(initialValue: startImmediatelyInDeck)
        self.weatherEngine = weatherEngine
    }

    private var palette: WeatherSkyPalette { weatherEngine.activePalette }

    /// 오늘 여러 번 놓친 카드일수록 하늘이 조금씩 어두워짐 (배지 없이 분위기로만 전달)
    private var currentFailureCount: Int {
        guard isStudyingCards else { return 0 }
        return sessionEngine.currentItem?.todayErosionCount ?? 0
    }

    public var body: some View {
        ZStack {
            WeatherSkyCanvasView(
                condition: weatherEngine.activeCondition,
                timeOfDay: weatherEngine.activeTimeOfDay,
                palette: palette,
                failureCount: currentFailureCount,
                isHareruCleared: weatherEngine.isHareruClearedToday
            )
            .animation(.easeInOut(duration: 0.45), value: cardPresentationId)

            if showClearCelebration {
                HareruClearCelebrationView(palette: palette)
                    .transition(.opacity)
            }

            if isStudyingCards {
                activeCardDeckBody
            } else {
                studyOverviewDashboardBody
            }
        }
        .onChange(of: sessionEngine.isSessionCompleted) { _, completed in
            guard completed, isStudyingCards else { return }
            celebrateHareruClear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard isStudyingCards else { return }
            if newPhase == .active {
                sessionEngine.resumeReactionTimer()
            } else {
                sessionEngine.pauseReactionTimer()
            }
        }
    }

    // MARK: - 1) 학습 시작 전 개요 대시보드 (이전 학습 요약 + 시험 D-Day 계획 + 이어서 학습 선택)

    private var studyOverviewDashboardBody: some View {
        let _ = sessionEngine.stateRevision
        let snapshots = sessionEngine.store.allSnapshots()
        let logs = sessionEngine.store.allReviewLogs()
        let todayKey = DayKeyFormatter.dayKey(for: Date(), calendar: sessionEngine.calendar)

        let totalGraduatedCount = snapshots.values.filter { $0.reps > 0 }.count
        let todayReviewedWordsCount = snapshots.values.filter {
            $0.lastEncounterDayKey == todayKey && $0.todayEncounterCount > 0
        }.count
        let dueReviewCount = snapshots.values.filter {
            $0.reps > 0 && $0.dueAt <= Date()
        }.count
        let hasActiveQueue = !sessionEngine.queue.isEmpty

        return NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // A. 사용자 목표 급수 & 시험 D-Day 동적 암기 계획 카드
                    if let profile = sessionEngine.userProfile,
                       let plan = sessionEngine.currentStudyPlanProjection() {
                        examPlanSummaryCard(profile: profile, plan: plan)
                    }

                    // B. 이전 학습 요약 & 오늘 진행 현황 카드
                    previousProgressSummaryCard(
                        hasActiveQueue: hasActiveQueue,
                        remainingInQueue: sessionEngine.queue.count,
                        sessionGraduatedCount: sessionEngine.graduatedWordIds.count,
                        todayReviewedWordsCount: todayReviewedWordsCount,
                        totalGraduatedCount: totalGraduatedCount,
                        dueReviewCount: dueReviewCount,
                        recentLogsCount: logs.count
                    )
                }
                .padding(18)
            }
            .navigationTitle("오늘의 단어 학습")
        }
    }

    private func examPlanSummaryCard(
        profile: UserStudyProfile,
        plan: StudyPlanProjection
    ) -> some View {
        let badgeColor: Color = {
            switch plan.feasibility {
            case .comfortable: return .teal
            case .achievable: return .orange
            case .tight: return .red
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("\(profile.displayName) · \(profile.targetLevel.rawValue) 목표", systemImage: "flag.checkered")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
                Spacer()
                Text("시험 D-\(plan.remainingDays)일")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.14), in: Capsule())
                    .foregroundStyle(.indigo)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("오늘의 권장 암기량")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("하루 \(plan.requiredDailyNewWords)단어")
                        .font(.title2.bold().monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(plan.isUsingLiveLearningTrend ? "실시간 학습 속도 동향" : "진단 기반 예상 속도")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("일 \(plan.estimatedDailyPaceCapacity)단어 소화 가능")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(badgeColor)
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 8, height: 8)
                Text(plan.statusHeadline)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(badgeColor)
            }

            Text(plan.statusDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24)
    }

    private func previousProgressSummaryCard(
        hasActiveQueue: Bool,
        remainingInQueue: Int,
        sessionGraduatedCount: Int,
        todayReviewedWordsCount: Int,
        totalGraduatedCount: Int,
        dueReviewCount: Int,
        recentLogsCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("이전 학습 기록 요약", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if hasActiveQueue {
                    Text("진행 중인 세션 있음")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.teal.opacity(0.16), in: Capsule())
                        .foregroundStyle(.teal)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                miniMetric(title: "외운 단어", value: "\(totalGraduatedCount)단어")
                miniMetric(title: "오늘 학습", value: "\(todayReviewedWordsCount)단어")
                miniMetric(title: "복습 대기", value: "\(dueReviewCount)단어")
            }

            if hasActiveQueue {
                Text("직전 세션에서 \(sessionGraduatedCount)단어를 외우고, 현재 \(remainingInQueue)장의 카드가 큐에 남아 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if recentLogsCount > 0 {
                Text("누적 \(recentLogsCount)회의 카드 평가 기록이 학습 속도 동향에 반영되어 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 카드 학습 기록이 없습니다. 첫 세션을 시작하면 실제 정답률에 맞춰 일일 암기 계획이 실시간으로 정교해집니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                if hasActiveQueue {
                    Button {
                        sessionEngine.resumeReactionTimer()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isStudyingCards = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("이어서 학습하기 (남은 \(remainingInQueue)장)")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .hareruProminentButtonStyle()
                    .tint(.indigo)

                    Button {
                        startFreshSessionAndEnterDeck()
                    } label: {
                        Text("새 세션으로 처음부터 다시 편성하기")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .hareruSecondaryButtonStyle()
                    .tint(.secondary)
                } else {
                    Button {
                        startFreshSessionAndEnterDeck()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text(totalGraduatedCount > 0 ? "이어서 오늘의 학습 시작하기" : "첫 단어 학습 시작하기")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .hareruProminentButtonStyle()
                    .tint(.indigo)
                }
            }
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24)
    }

    private func miniMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 2) 실제 단어 카드 학습 화면 본체

    private var activeCardDeckBody: some View {
        VStack(spacing: 18) {
            headerBar
                .frame(maxWidth: 360)

            if let banner = feedbackBanner {
                Text(banner)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .hareruGlass(in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            if let activeItem = sessionEngine.currentItem {
                ScrollView(.vertical, showsIndicators: false) {
                    WordCardView(
                        item: activeItem,
                        catalog: sessionEngine.catalog,
                        palette: palette,
                        isRaining: weatherEngine.activeCondition.hasRaindropsOnGlass,
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
            } else {
                sessionCompletedCard
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 상단 진행 헤더 (요약으로 돌아가기 + `진행 / 전체` 숫자)

    private var headerBar: some View {
        let total = sessionEngine.initialCardCount
        let resolved = max(0, total - sessionEngine.queue.count)

        return HStack {
            Button {
                sessionEngine.pauseReactionTimer()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isStudyingCards = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .hareruGlass(in: Circle(), tint: palette.glassTintColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("학습 요약으로")

            Spacer()

            HStack(spacing: 5) {
                Text("\(resolved)")
                    .contentTransition(.numericText())
                Text("/")
                    .foregroundStyle(palette.secondaryTextColor)
                Text("\(total)")
                    .foregroundStyle(palette.secondaryTextColor)
            }
            .font(.headline.monospacedDigit())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: resolved)
            .accessibilityLabel("전체 \(total)장 중 \(resolved)장 완료")

            Spacer()

            // 좌우 대칭을 위한 투명 자리 표시
            Color.clear.frame(width: 36, height: 36)
        }
        .foregroundStyle(palette.primaryTextColor)
    }

    // MARK: - 세션 완료 카드

    private var sessionCompletedCard: some View {
        VStack(spacing: 18) {
            Text("晴れる")
                .font(JLPTFont.termMincho(size: 44))
                .foregroundStyle(palette.primaryTextColor)

            Text("흐릿하던 기억이 맑게 갰어요!")
                .font(.title3.bold())
                .foregroundStyle(palette.primaryTextColor)

            VStack(spacing: 6) {
                Text("오늘 외운 단어 \(sessionEngine.graduatedWordIds.count)개")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
                if !sessionEngine.deferredTodayWordIds.isEmpty {
                    Text("내일 다시 만날 단어 \(sessionEngine.deferredTodayWordIds.count)개")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation {
                        isStudyingCards = false
                    }
                } label: {
                    Text("학습 요약으로")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .hareruSecondaryButtonStyle()

                Button {
                    startFreshSessionAndEnterDeck()
                } label: {
                    Label("다음 세션 시작", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .hareruProminentButtonStyle()
                .tint(.indigo)
            }
        }
        .padding(32)
        .frame(maxWidth: 360)
        .hareruGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous), tint: palette.glassTintColor)
    }

    // MARK: - 내부 동작 헬퍼

    private func startFreshSessionAndEnterDeck() {
        let targetLevel = sessionEngine.userProfile?.targetLevel
        if let level = targetLevel, !sessionEngine.catalog.words(for: level).isEmpty {
            // 목표 급수 단어를 우선 배치하되 전체 카탈로그도 함께 이어서 학습할 수 있도록 편성
            let levelWords = sessionEngine.catalog.words(for: level)
            let remainingWords = sessionEngine.catalog.words.filter { $0.jlptLevel != level }
            sessionEngine.startSession(words: levelWords + remainingWords)
        } else {
            sessionEngine.startSession()
        }
        cardPresentationId = UUID()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isStudyingCards = true
            showClearCelebration = false
        }
    }

    /// 오늘의 카드를 모두 마치면 구름이 걷히고 햇살이 비치는 '晴れる' 연출
    private func celebrateHareruClear() {
        withAnimation(.easeInOut(duration: 1.6)) {
            weatherEngine.isHareruClearedToday = true
            showClearCelebration = true
        }
    }

    private func handleEvaluation(button: ReviewButton) {
        guard let outcome = sessionEngine.submitEvaluation(button: button) else { return }

        let message: String?
        switch outcome.status {
        case .requeued:
            message = "잠시 후 한 번 더 만나요"
        case .confirmationQueued:
            message = "마지막에 한 번 더 확인할게요"
        case .graduated(let schedule, _, _, _):
            message = "\(button.koreanTitle) · \(schedule.scheduledIntervalDays)일 뒤 다시 만나요"
        case .deferredByDailyCap:
            message = "오늘은 여기까지 · 내일 맑은 머리로 다시 만나요"
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            feedbackBanner = message
            cardPresentationId = UUID()
        }
    }
}

#Preview("학습 대시보드 & 카드 덱") {
    WordDeckView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
