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
    private let isTabActive: Bool

    public init(
        engine: StudySessionEngine? = nil,
        weatherEngine: WeatherAtmosphereEngine = .shared,
        isTabActive: Bool = true,
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
        self.isTabActive = isTabActive
    }

    private var palette: WeatherSkyPalette { weatherEngine.activePalette }

    /// 오늘 여러 번 놓친 카드일수록 하늘이 조금씩 어두워짐 (배지 없이 분위기로만 전달)
    private var currentFailureCount: Int {
        guard isStudyingCards else { return 0 }
        return sessionEngine.currentItem?.todayErosionCount ?? 0
    }

    private var skyCanvas: some View {
        WeatherSkyCanvasView(
            condition: weatherEngine.activeCondition,
            timeOfDay: weatherEngine.activeTimeOfDay,
            palette: palette,
            failureCount: currentFailureCount,
            isHareruCleared: weatherEngine.isHareruClearedToday
        )
    }

    public var body: some View {
        ZStack {
            // 요약 화면은 NavigationStack이 자체 배경을 칠하므로 그 안쪽에서 하늘을 그림 (중복 캔버스 방지)
            if isStudyingCards {
                RetroBackground(windowHeight: 70) {
                    skyCanvas
                        .animation(.easeInOut(duration: 0.45), value: cardPresentationId)
                }
            }

            if showClearCelebration && isStudyingCards {
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
            if newPhase == .active && isTabActive {
                sessionEngine.resumeReactionTimer()
            } else {
                sessionEngine.pauseReactionTimer()
            }
        }
        // 통계·설정 탭을 보는 동안은 FSRS 반응 시간이 흐르지 않도록 정지
        .onChange(of: isTabActive) { _, active in
            guard isStudyingCards else { return }
            if active {
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
            RetroScrollScreen(windowHeight: 120) {
                ZStack {
                    skyCanvas
                    if showClearCelebration {
                        HareruClearCelebrationView(palette: palette)
                    }
                }
            } content: {
                VStack(alignment: .leading, spacing: 16) {
                    dashboardHeader
                        .retroHangingCable(.dangle, x: 214)

                    // A. 사용자 목표 급수 & 시험 D-Day 동적 암기 계획 카드
                    if let profile = sessionEngine.userProfile,
                       let plan = sessionEngine.currentStudyPlanProjection() {
                        examPlanSummaryCard(profile: profile, plan: plan)
                            .retroHangingCable(.loop, x: 120)
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

                    HStack { RetroCodeMonitor(kind: .industrial).offset(x: -6); Spacer(minLength: 0) }
                }
                .padding(.horizontal, 14)
                .padding(.top, 96)
                .padding(.bottom, 40)
            }
            .retroHidesNavigationBar()
        }
    }

    /// 머리: 작은 터미널에 「오늘의 판독」 + 커서, 옆에 코드만 흐르는 모니터
    private var dashboardHeader: some View {
        HStack(alignment: .bottom, spacing: 6) {
            RetroMonitor(style: .termRight, glow: 0.18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("오늘의 판독").font(.title2.bold()).phosphor()
                        RetroCursor(height: 22)
                    }
                    Text("NJL-OS 2.94 · STUDY").font(.caption2.monospaced()).phosphor(RetroColor.phosphorDim, glow: 2)
                }
            }
            RetroCodeMonitor(kind: .termB)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func examPlanSummaryCard(
        profile: UserStudyProfile,
        plan: StudyPlanProjection
    ) -> some View {
        let badgeColor: Color = {
            switch plan.feasibility {
            case .comfortable: return RetroColor.phosphor
            case .achievable: return RetroColor.amber
            case .tight: return RetroColor.alert
            }
        }()

        return RetroMonitor(style: .crt, glow: 0.24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(profile.displayName) · \(profile.targetLevel.rawValue) 목표")
                            .font(.caption.weight(.bold)).phosphor(RetroColor.phosphorDim, glow: 1)
                        Text("오늘의 권장 판독량").font(.caption).phosphor(RetroColor.phosphorDim, glow: 1)
                        Text("하루 \(plan.requiredDailyNewWords)단어")
                            .font(.title.bold().monospacedDigit()).phosphor(RetroColor.phosphorBright)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("시험까지").font(.caption2.weight(.bold)).phosphor(RetroColor.phosphorDim, glow: 1)
                        RetroFlipCounter(text: "D-\(plan.remainingDays)")
                            .accessibilityLabel("시험까지 \(plan.remainingDays)일")
                    }
                }

                HStack(spacing: 6) {
                    Text(plan.isUsingLiveLearningTrend ? "실시간 판독 속도" : "진단 기반 예상 속도")
                        .font(.caption).phosphor(RetroColor.phosphorDim, glow: 1)
                    Spacer()
                    Text("일 \(plan.estimatedDailyPaceCapacity)단어 소화 가능")
                        .font(.subheadline.weight(.bold).monospacedDigit()).phosphor(badgeColor, glow: 2)
                }

                HStack(spacing: 8) {
                    Circle().fill(badgeColor).frame(width: 7, height: 7).shadow(color: badgeColor, radius: 3)
                    Text(plan.statusHeadline).font(.caption.weight(.bold)).phosphor(badgeColor, glow: 2)
                }

                Text(plan.statusDetail)
                    .font(.caption2)
                    .phosphor(RetroColor.phosphorDim, glow: 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        VStack(alignment: .leading, spacing: 14) {
            RetroMonitor(style: .industrialTurned, glow: 0.2) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("이전 판독 기록").font(.subheadline.weight(.bold)).phosphor()
                        Spacer()
                        if hasActiveQueue {
                            Text("진행 중인 세션").font(.caption2.weight(.bold)).phosphor(RetroColor.amber, glow: 2)
                        }
                    }

                    HStack(spacing: 6) {
                        miniMetric(title: "외운 단어", value: "\(totalGraduatedCount)")
                        miniMetric(title: "오늘 판독", value: "\(todayReviewedWordsCount)")
                        miniMetric(title: "복습 대기", value: "\(dueReviewCount)")
                    }

                    Group {
                        if hasActiveQueue {
                            Text("직전 세션에서 \(sessionGraduatedCount)단어를 외우고, 현재 \(remainingInQueue)장의 카드가 큐에 남아 있습니다.")
                        } else if recentLogsCount > 0 {
                            Text("누적 \(recentLogsCount)회의 카드 평가 기록이 판독 속도에 반영되어 있습니다.")
                        } else {
                            Text("아직 판독 기록이 없습니다. 첫 세션을 시작하면 실제 정답률에 맞춰 일일 계획이 정교해집니다.")
                        }
                    }
                    .font(.caption)
                    .phosphor(RetroColor.phosphorDim, glow: 1)
                }
            }

            if hasActiveQueue {
                Button {
                    sessionEngine.resumeReactionTimer()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isStudyingCards = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        RetroSprite(name: "rt_glyph_play", animated: false)
                        Text("이어서 판독하기 (남은 \(remainingInQueue)장)").font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(RetroKeyStyle(tone: .amber))

                Button {
                    startFreshSessionAndEnterDeck()
                } label: {
                    Text("새 세션으로 처음부터 다시 편성하기").font(.caption.weight(.bold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(RetroKeyStyle(tone: .cream))
            } else {
                Button {
                    startFreshSessionAndEnterDeck()
                } label: {
                    HStack(spacing: 12) {
                        RetroSprite(name: "rt_glyph_play", animated: false)
                        Text(totalGraduatedCount > 0 ? "이어서 오늘의 판독 시작" : "첫 판독 시작하기").font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(RetroKeyStyle(tone: .amber))
            }
        }
    }

    /// 작은 칸: 금속 명판 위 숫자 (가로 셋)
    private func miniMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(RetroColor.creamInk)
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(RetroColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RetroNineSlice(name: "rt_plate_metal", animated: false))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 2) 실제 단어 카드 학습 화면 본체

    private var activeCardDeckBody: some View {
        VStack(spacing: 18) {
            headerBar
                .frame(maxWidth: 360)

            // 안내 문구 자리는 높이를 고정해 문구 유무에 따라 카드·버튼 위치가 흔들리지 않게 함
            ZStack {
                if let banner = feedbackBanner {
                    Text(banner)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RetroColor.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(RetroNineSlice(name: "rt_plate_cream", animated: false))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(height: 30)

            Spacer(minLength: 0)

            if let activeItem = sessionEngine.currentItem {
                // 바깥 ScrollView 없이 남은 높이를 카드가 꽉 채워, 내용은 카드 안에서만 스크롤되고
                // '정답 보기'와 4개 평가 버튼은 항상 같은 높이(카드 하단)에 고정됨
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
                RetroSprite(name: "rt_glyph_back", animated: false)
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(RetroKeyStyle(tone: .cream))
            .accessibilityLabel("학습 요약으로")

            Spacer()

            HStack(spacing: 5) {
                Text("\(resolved)")
                    .contentTransition(.numericText())
                Text("/")
                    .foregroundStyle(RetroColor.creamInk)
                Text("\(total)")
                    .foregroundStyle(RetroColor.creamInk)
            }
            .font(.headline.monospacedDigit())
            .foregroundStyle(RetroColor.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(RetroNineSlice(name: "rt_plate_metal", animated: false))
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: resolved)
            .accessibilityLabel("전체 \(total)장 중 \(resolved)장 완료")

            Spacer()

            // 좌우 대칭을 위한 투명 자리 표시
            Color.clear.frame(width: 52, height: 36)
        }
    }

    // MARK: - 세션 완료 카드

    private var sessionCompletedCard: some View {
        VStack(spacing: 14) {
            RetroMonitor(style: .crt, glow: 0.35) {
                VStack(spacing: 10) {
                    RetroSprite(name: "rt_phosphor_sun", scale: 2)
                    Text("晴れる").font(JLPTFont.termMincho(size: 44)).phosphor(RetroColor.phosphorBright, glow: 5)
                    Text("흐릿하던 기억이 맑게 갰어요!").font(.headline).phosphor()
                }
                .frame(maxWidth: .infinity)
            }

            RetroPlate(tone: .metal) {
                HStack {
                    Text("오늘 외운 단어").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(sessionEngine.graduatedWordIds.count)개").font(.headline.monospacedDigit())
                }
            }
            if !sessionEngine.deferredTodayWordIds.isEmpty {
                RetroPlate(tone: .metal) {
                    HStack {
                        Text("내일 다시 만날 단어").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(sessionEngine.deferredTodayWordIds.count)개").font(.headline.monospacedDigit())
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation {
                        isStudyingCards = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        RetroSprite(name: "rt_glyph_back", animated: false)
                        Text("학습 요약으로").font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(RetroKeyStyle(tone: .cream))

                Button {
                    startFreshSessionAndEnterDeck()
                } label: {
                    Text("다음 세션 시작").font(.subheadline.weight(.bold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(RetroKeyStyle(tone: .amber))
            }
        }
        .frame(maxWidth: 380)
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
