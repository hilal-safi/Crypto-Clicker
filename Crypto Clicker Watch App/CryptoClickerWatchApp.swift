import SwiftUI

@main
struct CryptoClickerWatchApp: App {
    @State private var store = WatchStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            store.scenePhaseChanged(to: phase)
        }
    }
}
