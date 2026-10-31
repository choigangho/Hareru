import SwiftUI
import Hareru
#if os(macOS)
import AppKit
#endif

@main
struct HareruApp: App {
    @State private var sharedSessionEngine: StudySessionEngine

    init() {
        let store: MemoryStoreProtocol
        if let container = try? SwiftDataMemoryStore.makeContainer(inMemory: false) {
            store = SwiftDataMemoryStore(container: container)
        } else {
            store = InMemoryMemoryStore()
        }
        _sharedSessionEngine = State(initialValue: StudySessionEngine(store: store))

        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup("Hareru (晴れる)") {
            HareruMainTabView(sessionEngine: sharedSessionEngine)
            #if os(macOS)
            .frame(minWidth: 410, idealWidth: 420, maxWidth: 460,
                   minHeight: 780, idealHeight: 840, maxHeight: 920)
            #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}

// MARK: - 메인 2탭 통합 뷰 + 최초 실행 시 회원가입·급수 진단 온보딩 자동 연결 (게임 탭 제거됨)
public struct HareruMainTabView: View {
    @State private var sessionEngine: StudySessionEngine

    public init(sessionEngine: StudySessionEngine? = nil) {
        if let sessionEngine {
            _sessionEngine = State(initialValue: sessionEngine)
        } else {
            _sessionEngine = State(initialValue: StudySessionEngine(store: InMemoryMemoryStore()))
        }
    }

    public var body: some View {
        let _ = sessionEngine.stateRevision

        if sessionEngine.userProfile == nil {
            OnboardingFlowView(engine: sessionEngine)
                .transition(.opacity)
        } else {
            TabView {
                WordDeckView(engine: sessionEngine)
                    .tabItem {
                        Label("단어 학습", systemImage: "rectangle.stack.fill")
                    }

                InsightsHubView(engine: sessionEngine)
                    .tabItem {
                        Label("통계 · 노트", systemImage: "chart.bar.doc.horizontal.fill")
                    }
            }
            .modifier(LiquidGlassTabBarBehavior())
            .transition(.opacity)
        }
    }
}

// MARK: - iOS 26 Liquid Glass 탭 바: 스크롤 시 자동 최소화
private struct LiquidGlassTabBarBehavior: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#Preview("1. 온보딩 (회원가입 · N급수 10문항 진단)") {
    HareruMainTabView(sessionEngine: StudySessionEngine(store: InMemoryMemoryStore()))
}

#Preview("2. 메인 앱 (학습 요약 홈 · 카드 덱 · 통계)") {
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
