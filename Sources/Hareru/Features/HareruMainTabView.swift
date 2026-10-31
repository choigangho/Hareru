import SwiftUI

// MARK: - 하단 3개 메인 챕터 ('학습' · '통계' · '설정')
public enum MainChapterTab: String, CaseIterable, Identifiable {
    case study = "학습"
    case statistics = "통계"
    case settings = "설정"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .study: return "rectangle.stack.fill"
        case .statistics: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - iOS 26 스타일 굴곡 있는 플로팅 Liquid Glass 캡슐 토글 네비게이터
public struct FloatingLiquidGlassTabBar: View {
    @Binding public var selectedTab: MainChapterTab
    @Namespace private var tabIndicatorNamespace

    private var weatherEngine = WeatherAtmosphereEngine.shared

    public init(selectedTab: Binding<MainChapterTab>) {
        self._selectedTab = selectedTab
    }

    private var palette: WeatherSkyPalette {
        weatherEngine.activePalette
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(MainChapterTab.allCases) { tab in
                let isSelected = (selectedTab == tab)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 14, weight: .bold))

                        if isSelected {
                            Text(tab.rawValue)
                                .font(.caption.weight(.bold))
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .padding(.horizontal, isSelected ? 16 : 14)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            // 물방울처럼 유려하게 이동하는 굴곡진 액티브 글라스 인디케이터
                            Capsule()
                                .fill(palette.accentColor)
                                .matchedGeometryEffect(id: "activeTabGlassPill", in: tabIndicatorNamespace)
                                .shadow(color: palette.accentColor.opacity(0.35), radius: 8, y: 3)
                        }
                    }
                    .foregroundStyle(isSelected ? (palette.isDarkSky ? Color.black : Color.white) : palette.secondaryTextColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .hareruGlass(
            in: Capsule(),
            tint: palette.glassTintColor
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.45), .white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: .black.opacity(palette.isDarkSky ? 0.35 : 0.15), radius: 20, y: 10)
    }
}

// MARK: - Hareru 메인 3챕터 통합 뷰
public struct HareruMainTabView: View {
    @State private var sessionEngine: StudySessionEngine
    @State private var selectedTab: MainChapterTab = .study
    private var weatherEngine = WeatherAtmosphereEngine.shared

    public init(sessionEngine: StudySessionEngine? = nil) {
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
    }

    public var body: some View {
        let _ = sessionEngine.stateRevision

        if sessionEngine.userProfile == nil {
            // 프로필이 없는 신규 사용자는 온보딩(소셜/이메일 로그인 + N급수 10장 진단 + 위치 연동) 먼저 진행
            OnboardingFlowView(engine: sessionEngine, weatherEngine: weatherEngine) { _ in
                // 온보딩 완료 시 프로필이 자동 저장되어 메인 뷰로 전환됩니다
            }
            .transition(.opacity)
        } else {
            ZStack(alignment: .bottom) {
                // 3대 챕터 화면 (학습 · 통계 · 설정)
                Group {
                    switch selectedTab {
                    case .study:
                        WordDeckView(engine: sessionEngine)
                    case .statistics:
                        InsightsHubView(engine: sessionEngine)
                    case .settings:
                        SettingsHubView(engine: sessionEngine)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 하단 굴곡 플로팅 Liquid Glass 캡슐 바
                FloatingLiquidGlassTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 16)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

#Preview("1. 온보딩 프리뷰") {
    HareruMainTabView(sessionEngine: StudySessionEngine(store: InMemoryMemoryStore()))
}

#Preview("2. 메인 3챕터 앱 (플로팅 글라스 토글)") {
    let profile = UserStudyProfile(
        email: "learner@hareru.app",
        displayName: "도쿄합격생",
        passwordHash: UserStudyProfile.hashPassword("pass1234"),
        authProvider: .apple,
        targetLevel: .n2,
        examDate: Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date(),
        diagnosticTestedCount: 10,
        diagnosticCorrectCount: 7,
        diagnosticAverageSeconds: 3.2
    )
    let store = InMemoryMemoryStore(initialProfile: profile)
    HareruMainTabView(sessionEngine: StudySessionEngine(store: store))
}
