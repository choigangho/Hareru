import SwiftUI
import SwiftData

// MARK: - 탭 1 단어 학습 허브 & 덱 화면
// 앱을 켰을 때 바로 단어 카드가 뜨지 않고, 먼저 이전 학습 기록·남은 시험일 계획·진도 동향을 보여준 뒤
// 사용자가 '이어서 학습하기' 또는 '오늘의 세션 시작하기'를 선택해 카드 덱으로 진입합니다.
public struct WordDeckView: View {
    @State private var sessionEngine: StudySessionEngine
    @State private var isStudyingCards: Bool = false
    @State private var showGoalResetOnboarding: Bool = false
    @State private var feedbackBanner: String?
    @State private var cardPresentationId = UUID()
    @Environment(\.scenePhase) private var scenePhase

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

    private var backgroundColors: [Color] {
        if isStudyingCards, let item = sessionEngine.currentItem {
            return item.activeColors(maxDailyEncounters: sessionEngine.configuration.maxDailyEncounters)
        }
        return CategoryThemeGroup.standardDefault.palette.swiftUIColors
    }

    private var isDeeplyEroded: Bool {
        isStudyingCards && (sessionEngine.currentItem?.todayErosionCount ?? 0) >= 2
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
            .animation(.easeInOut(duration: 0.35), value: isStudyingCards)

            if isStudyingCards {
                activeCardDeckBody
            } else {
                studyOverviewDashboardBody
            }
        }
        .sheet(isPresented: $showGoalResetOnboarding) {
            OnboardingFlowView(engine: sessionEngine) { _ in
                showGoalResetOnboarding = false
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

                    // C. 카테고리 컬러 테마 가이드 (단어별 무작위 색상 대신 5대 카테고리 + 기본 테마)
                    categoryPaletteGuideCard
                }
                .padding(18)
            }
            .navigationTitle("오늘의 단어 학습")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showGoalResetOnboarding = true
                    } label: {
                        Label("목표·진단 재설정", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
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
                miniMetric(title: "누적 졸업", value: "\(totalGraduatedCount)단어")
                miniMetric(title: "오늘 학습", value: "\(todayReviewedWordsCount)단어")
                miniMetric(title: "복습 대기", value: "\(dueReviewCount)단어")
            }

            if hasActiveQueue {
                Text("직전 세션에서 \(sessionGraduatedCount)단어를 졸업하고, 현재 \(remainingInQueue)장의 카드가 큐에 남아 있습니다.")
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

    private var categoryPaletteGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("카테고리별 테마 컬러 안내")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text("눈이 피로하지 않도록 단어마다 색을 바꾸지 않고, 의미 카테고리별로 차분한 테마 색상을 적용합니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CategoryThemeGroup.allCases, id: \.rawValue) { group in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(group.palette.accentColor)
                                .frame(width: 10, height: 10)
                            Text(group.rawValue)
                                .font(.caption2.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            group.palette.swiftUIColors[0].opacity(0.55),
                            in: Capsule()
                        )
                    }
                }
            }
        }
        .padding(16)
        .hareruGlassCard(cornerRadius: 20)
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

    // MARK: - 상단 진행 헤더 (학습 요약으로 돌아가기 버튼 포함)

    private var headerBar: some View {
        HareruGlassGroup(spacing: 8) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
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
                        .padding(.vertical, 7)
                        .hareruGlass(in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if let item = sessionEngine.currentItem {
                        Label("\(item.word.jlptLevel.rawValue) · \(item.word.categoryThemeGroup.rawValue)", systemImage: "tag.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .hareruGlass(in: Capsule())

                        if item.isAwaitingFinalConfirmation {
                            Text("최종 확인")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .foregroundStyle(.white)
                                .hareruGlass(in: Capsule(), tint: .teal)
                        } else if item.todayErosionCount > 0 {
                            Text("침식 \(item.todayErosionCount)단계")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .foregroundStyle(.white)
                                .hareruGlass(in: Capsule(), tint: .red)
                        }
                    }

                    Spacer()

                    Text("\(sessionEngine.queue.count)장 남음")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .hareruGlass(in: Capsule())
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
                .frame(height: 6)
            }
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
                Text("이번 세션 졸업 단어: \(sessionEngine.graduatedWordIds.count)개")
                    .font(.subheadline.weight(.semibold))
                if !sessionEngine.deferredTodayWordIds.isEmpty {
                    Text("수면 공고화로 내일 이관된 단어: \(sessionEngine.deferredTodayWordIds.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let plan = sessionEngine.currentStudyPlanProjection() {
                    Text("최근 정답률 동향이 반영되어 일일 소화 가능 속도가 \(plan.estimatedDailyPaceCapacity)단어로 업데이트되었습니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
        .hareruGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
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
        }
    }

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
        case .graduated(let schedule, let didPurify, _, _):
            if didPurify {
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

#Preview("학습 대시보드 & 카드 덱") {
    WordDeckView(engine: StudySessionEngine(store: InMemoryMemoryStore()))
}
