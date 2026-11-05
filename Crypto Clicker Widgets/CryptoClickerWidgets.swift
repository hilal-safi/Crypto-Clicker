import SwiftUI
import WidgetKit

/// The app's widgets: the balance on the Home Screen and the Lock Screen, and the Live Activity on
/// the Lock Screen and in the Dynamic Island.
@main
struct CryptoClickerWidgets: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        MiningLiveActivity()
    }
}
