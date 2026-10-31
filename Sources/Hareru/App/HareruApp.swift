import SwiftUI
import Hareru
#if os(macOS)
import AppKit
#endif

@main
struct HareruApp: App {
    init() {
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
                WordDeckView()
                    .tabItem {
                        Label("단어 학습", systemImage: "rectangle.stack.fill")
                    }

                GameHubView()
                    .tabItem {
                        Label("게임 (SMS)", systemImage: "bubble.left.and.bubble.right.fill")
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
