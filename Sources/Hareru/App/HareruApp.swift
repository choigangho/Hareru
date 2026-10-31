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
            TabView {
                WordDeckView(engine: sharedSessionEngine)
                    .tabItem {
                        Label("단어 학습", systemImage: "rectangle.stack.fill")
                    }

                GameHubView(engine: sharedSessionEngine)
                    .tabItem {
                        Label("게임 (SMS)", systemImage: "bubble.left.and.bubble.right.fill")
                    }

                InsightsHubView(engine: sharedSessionEngine)
                    .tabItem {
                        Label("통계 · 노트", systemImage: "chart.bar.doc.horizontal.fill")
                    }
            }
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
