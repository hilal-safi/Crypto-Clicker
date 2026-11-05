import SwiftUI

@main
struct CryptoClickerApp: App {
    @State private var store = GameStore()
    @AppStorage(Preferences.appearanceKey) private var appearance = Appearance.auto
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(appearance.colorScheme)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            store.scenePhaseChanged(to: phase)
        }
    }
}
