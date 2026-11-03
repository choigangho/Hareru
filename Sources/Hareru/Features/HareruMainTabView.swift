import SwiftUI

// MARK: - 메인 3탭 통합 뷰 + 최초 실행 시 회원가입·급수 진단 온보딩 자동 연결
// 하단은 시스템 TabView 바 대신 플로팅 Liquid Glass 캡슐 탭 바를 사용합니다.
public struct HareruMainTabView: View {
    @State private var sessionEngine: StudySessionEngine
    @State private var selectedTab: HareruMainTab = .study
    // 연구소 상태는 학습 기록과 별도 파일(Application Support/Hareru/institute.json)에 저장
    @State private var instituteEngine = InstituteEngine(store: JSONFileInstituteStore())
    // 1일차 스토리 (Docs/Story/lines/N5_D1.md) — 끝내면 다시 뜨지 않음, 설정의 '1일차 다시 보기'로 처음부터
    @State private var dayOne = DayOneDirector()
    @AppStorage(DayOneDirector.doneKey) private var dayOneDone = false
    private let weatherEngine: WeatherAtmosphereEngine

    public init(sessionEngine: StudySessionEngine? = nil, weatherEngine: WeatherAtmosphereEngine = .shared) {
        if let sessionEngine {
            _sessionEngine = State(initialValue: sessionEngine)
        } else {
            let store: MemoryStoreProtocol
            if let container = try? SwiftDataMemoryStore.makeContainer(inMemory: false) {
                store = SwiftDataMemoryStore(container: container)
            } else {
                store = InMemoryMemoryStore()
            }
            _sessionEngine = State(initialValue: StudySessionEngine(store: store))
        }
        self.weatherEngine = weatherEngine
    }

    public var body: some View {
        let _ = sessionEngine.stateRevision
        let palette = weatherEngine.activePalette

        if sessionEngine.userProfile == nil {
            OnboardingFlowView(engine: sessionEngine)
                .transition(.opacity)
        } else {
            ZStack {
                // 학습 탭은 카드 진행 상태가 유지되도록 항상 띄워두고 노출만 전환,
                // 연구소·통계·설정은 선택될 때만 만들어 60fps 하늘 캔버스가 중복으로 돌지 않게 함
                tabContent(for: .study)
                    .opacity(selectedTab == .study ? 1 : 0)
                    .allowsHitTesting(selectedTab == .study)
                    .accessibilityHidden(selectedTab != .study)

                if selectedTab != .study {
                    tabContent(for: selectedTab)
                        .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingGlassTabBar(selection: $selectedTab, palette: palette)
                    .padding(.bottom, 6)
            }
            .overlay {
                if !dayOneDone {
                    StoryOverlayView(
                        director: dayOne,
                        onWeatherSync: { weatherEngine.requestLocationPermission() },
                        onSkipStudy: { dayOne.studySessionEnded() }
                    )
                    .transition(.opacity)
                }
            }
            .onAppear {
                dayOne.configure(profile: sessionEngine.userProfile)
                if !dayOneDone { selectedTab = dayOne.tab }
            }
            .onChange(of: dayOne.tab) { _, tab in selectedTab = tab }
            .onChange(of: sessionEngine.submittedEvaluationCount) { _, _ in
                dayOne.recordStudy(sessionCompleted: sessionEngine.isSessionCompleted)
            }
            .onChange(of: dayOneDone) { _, done in
                // 설정에서 진행을 지우면 새 진행으로 처음부터
                if !done {
                    dayOne = DayOneDirector()
                    dayOne.configure(profile: sessionEngine.userProfile)
                    selectedTab = dayOne.tab
                }
            }
            // 하늘 명도에 맞춰 시스템 재질·보조 텍스트 대비를 함께 맞춤
            // environment만 바꾸면 팝오버·시트의 시스템 배경은 라이트로 남아 흰 바탕에 흰 글씨가 되므로 창 전체에 적용
            .preferredColorScheme(palette.isDarkSky ? .dark : .light)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: HareruMainTab) -> some View {
        switch tab {
        case .study:
            WordDeckView(engine: sessionEngine, weatherEngine: weatherEngine, isTabActive: selectedTab == .study)
        case .game:
            InstituteView(sessionEngine: sessionEngine, instituteEngine: instituteEngine, weatherEngine: weatherEngine)
        case .insights:
            InsightsHubView(engine: sessionEngine, weatherEngine: weatherEngine)
        case .settings:
            HareruSettingsView(engine: sessionEngine, weatherEngine: weatherEngine)
        }
    }
}

#Preview("1. 온보딩 (회원가입 · N급수 10문항 진단)") {
    HareruMainTabView(sessionEngine: StudySessionEngine(store: InMemoryMemoryStore()))
}

#Preview("2. 메인 앱 (학습 · 통계 · 설정)") {
    let sampleProfile = UserStudyProfile(
        email: "learner@hareru.app",
        displayName: "도쿄합격생",
        passwordHash: UserStudyProfile.hashPassword("hareru1234"),
        targetLevel: .n2,
        examDate: Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date(),
        diagnosticTestedCount: 10,
        diagnosticCorrectCount: 6,
        diagnosticAverageSeconds: 3.8
    )
    let store = InMemoryMemoryStore(initialProfile: sampleProfile)
    HareruMainTabView(sessionEngine: StudySessionEngine(store: store))
}
