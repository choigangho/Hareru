import SwiftUI

// MARK: - 단어 학습 대시보드 및 카드 덱 컨테이너
// - 날씨 앱 헤더: "서울 · 비 14° · D-60일 하루 25단어"
// - 이전 학습 요약 및 시험 D-Day 완주 예측
// - 상단 덱 헤더: "12 / 30" 형태로 심플화 ('침식 N단계', '조우' 배지 완전 삭제)
// - 오늘의 목표 완료 시 날씨가 맑게 개는(晴れる) 연출 트리거
public struct WordDeckView: View {
    @State private var sessionEngine: StudySessionEngine
    @State private var isStudyingCards: Bool = false
    @State private var showGoalResetSheet: Bool = false
    @State private var feedbackBanner: String?
    @State private var cardPresentationId = UUID()
    @Environment(\.scenePhase) private var scenePhase

    private var weatherEngine = WeatherAtmosphereEngine.shared

    public init(engine: StudySessionEngine? = nil, startImmediatelyInDeck: Bool = false) {
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
    }

    private var palette: WeatherSkyPalette {
        weatherEngine.activePalette
    }

    private var currentFailureCount: Int {
        sessionEngine.currentItem?.todayErosionCount ?? 0
    }

    public var body: some View {
        ZStack {
            // Apple 날씨 앱 스타일 상시 하늘 & 기상 파티클 렌더러
            WeatherSkyCanvasView(
                condition: weatherEngine.activeCondition,
                timeOfDay: weatherEngine.activeTimeOfDay,
                palette: palette,
                failureCount: isStudyingCards ? currentFailureCount : 0,
                isHareruCleared: weatherEngine.isHareruClearedToday
            )

            if isStudyingCards {
                activeCardDeckBody
            } else {
                studyOverviewDashboardBody
            }
        }
        .sheet(isPresented: $showGoalResetSheet) {
            OnboardingFlowView(engine: sessionEngine) { _ in
                showGoalResetSheet = false
            }
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

    // MARK: - 1) 첫 화면: 오늘의 기상 브리핑 + D-Day 계획 + 학습 요약 홈

    private var studyOverviewDashboardBody: some View {
        let _ = sessionEngine.stateRevision
        let snapshots = sessionEngine.store.allSnapshots()
        let todayKey = DayKeyFormatter.dayKey(for: Date(), calendar: sessionEngine.calendar)

        let totalMasteredCount = snapshots.values.filter { $0.reps > 0 }.count
        let todayLearnedCount = snapshots.values.filter {
            $0.lastEncounterDayKey == todayKey && $0.todayEncounterCount > 0
        }.count
        let dueReviewCount = snapshots.values.filter {
            $0.reps > 0 && $0.dueAt <= Date()
        }.count
        let hasActiveQueue = !sessionEngine.queue.isEmpty

        return NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // A. 상단 날씨 앱 스타일 기상 브리핑 헤더
                    weatherBriefingHeader

                    // B. 목표 급수 및 시험 D-Day 완주 예측 카드
                    if let profile = sessionEngine.userProfile,
                       let plan = sessionEngine.currentStudyPlanProjection() {
                        examPlanProjectionCard(profile: profile, plan: plan)
                    }

                    // C. 이전 학습 기록 요약 & 세션 시작/이어하기 카드
                    previousProgressSummaryCard(
                        hasActiveQueue: hasActiveQueue,
                        remainingInQueue: sessionEngine.queue.count,
                        sessionMasteredCount: sessionEngine.graduatedWordIds.count,
                        todayLearnedCount: todayLearnedCount,
                        totalMasteredCount: totalMasteredCount,
                        dueReviewCount: dueReviewCount
                    )
                }
                .padding(18)
                .padding(.bottom, 80) // 하단 플로팅 토글 바 여백
            }
            .navigationTitle("학습")
            .foregroundStyle(palette.primaryTextColor)
        }
    }

    private var weatherBriefingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: weatherEngine.activeCondition.sfSymbolName(for: weatherEngine.activeTimeOfDay))
                    .font(.title2)
                Text(weatherEngine.locationTitle)
                    .font(.title3.bold())
                Spacer()
                Text("\(weatherEngine.temperatureCelsius)°")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
            }

            Text("\(weatherEngine.activeCondition.koreanTitle) · \(weatherEngine.activeTimeOfDay.koreanLabel)")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryTextColor)
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }

    private func examPlanProjectionCard(profile: UserStudyProfile, plan: StudyPlanProjection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(profile.targetLevel.rawValue) 목표 · D-\(plan.remainingDays)", systemImage: "flag.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.accentColor)
                Spacer()
                Text(plan.feasibility.summaryBadge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘 권장 암기량")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryTextColor)
                    Text("하루 \(plan.requiredDailyNewWords)단어")
                        .font(.title3.bold().monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.isUsingLiveLearningTrend ? "실시간 학습 속도 반영됨" : "진단 기반 예상 속도")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryTextColor)
                    Text("일 \(plan.estimatedDailyPaceCapacity)단어 소화 가능")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(palette.accentColor)
                }
            }

            Text(plan.statusDetail)
                .font(.caption2)
                .foregroundStyle(palette.secondaryTextColor)
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }

    private func previousProgressSummaryCard(
        hasActiveQueue: Bool,
        remainingInQueue: Int,
        sessionMasteredCount: Int,
        todayLearnedCount: Int,
        totalMasteredCount: Int,
        dueReviewCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("학습 현황")
                    .font(.headline)
                Spacer()
                if hasActiveQueue {
                    Text("진행 중인 세션 있음")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.accentColor.opacity(0.2), in: Capsule())
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                miniBox(title: "누적 암기", value: "\(totalMasteredCount)단어")
                miniBox(title: "오늘 학습", value: "\(todayLearnedCount)단어")
                miniBox(title: "복습 대기", value: "\(dueReviewCount)단어")
            }

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
                    .frame(height: 50)
                    .background(palette.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(palette.isDarkSky ? Color.black : Color.white)
                }
                .buttonStyle(.plain)

                Button {
                    startFreshSessionAndEnterDeck()
                } label: {
                    Text("새 세션으로 처음부터 시작하기")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startFreshSessionAndEnterDeck()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text(totalMasteredCount > 0 ? "이어서 오늘의 학습 시작하기" : "첫 단어 학습 시작하기")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(palette.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(palette.isDarkSky ? Color.black : Color.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .hareruGlassCard(cornerRadius: 24, tint: palette.glassTintColor)
    }

    private func miniBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryTextColor)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 2) 카드 학습 진행 화면

    private var activeCardDeckBody: some View {
        VStack(spacing: 16) {
            // 상단 간소화된 진행 헤더 ("< 요약" 및 "12 / 30" 심플 표기)
            simpleDeckHeader
                .frame(maxWidth: 360)

            if let banner = feedbackBanner {
                Text(banner)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
                    .foregroundStyle(palette.primaryTextColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            if let activeItem = sessionEngine.currentItem {
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
            } else {
                sessionCompletedCard
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, 72) // 하단 토글 바 여백
    }

    private var simpleDeckHeader: some View {
        let total = sessionEngine.initialCardCount
        let remaining = sessionEngine.queue.count
        let completed = max(0, total - remaining)

        return HStack {
            Button {
                sessionEngine.pauseReactionTimer()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isStudyingCards = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("요약")
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
                .foregroundStyle(palette.primaryTextColor)
            }
            .buttonStyle(.plain)

            Spacer()

            // 100/200 형태의 간단하고 깔끔한 숫자 표기
            Text("\(completed) / \(total)")
                .font(.headline.monospacedDigit().weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .hareruGlass(in: Capsule(), tint: palette.glassTintColor)
                .foregroundStyle(palette.primaryTextColor)
        }
    }

    // MARK: - 세션 완료 카드 (목표 완료 시 날씨가 개는 '晴れる' 연출)

    private var sessionCompletedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.yellow)

            Text("흐릿하던 기억이 맑게 갰어요!")
                .font(.title3.bold())
                .foregroundStyle(palette.primaryTextColor)

            Text("이번 세션에서 \(sessionEngine.graduatedWordIds.count)단어를 완벽하게 암기 완료했습니다.")
                .font(.caption)
                .foregroundStyle(palette.secondaryTextColor)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    withAnimation {
                        isStudyingCards = false
                    }
                } label: {
                    Text("학습 요약으로")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .hareruSecondaryButtonStyle()

                Button {
                    startFreshSessionAndEnterDeck()
                } label: {
                    Label("다음 세션 시작", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .hareruProminentButtonStyle()
                .tint(palette.accentColor)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .hareruGlassCard(cornerRadius: 30, tint: palette.glassTintColor)
        .onAppear {
            // 오늘의 세션을 끝까지 완료하면 앱 이름처럼 날씨가 맑게 개는 Hareru 효과 트리거
            weatherEngine.isHareruClearedToday = true
        }
    }

    // MARK: - 세션 시작 & 평가 피드백

    private func startFreshSessionAndEnterDeck() {
        let targetLevel = sessionEngine.userProfile?.targetLevel
        if let level = targetLevel, !sessionEngine.catalog.words(for: level).isEmpty {
            let levelWords = sessionEngine.catalog.words(for: level)
            let otherWords = sessionEngine.catalog.words.filter { $0.jlptLevel != level }
            sessionEngine.startSession(words: levelWords + otherWords)
        } else {
            sessionEngine.startSession()
        }
        cardPresentationId = UUID()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isStudyingCards = true
        }
    }

    private func handleEvaluation(button: ReviewButton) {
        guard let outcome = sessionEngine.submitEvaluation(button: button) else { return }

        let message: String?
        switch outcome.status {
        case .requeued:
            message = "잠시 후 다시 확인합니다"
        case .confirmationQueued:
            message = "세션 마지막에 한 번 더 확인합니다"
        case .graduated(let schedule, _, _, _):
            message = "암기 완료! (\(schedule.scheduledIntervalDays)일 뒤 복습)"
        case .deferredByDailyCap:
            message = "오늘 8회 도달 · 내일 맑은 머리로 다시 만나요"
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            feedbackBanner = message
            cardPresentationId = UUID()
        }
    }
}

#Preview("학습 뷰") {
    WordDeckView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
