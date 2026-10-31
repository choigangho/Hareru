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
