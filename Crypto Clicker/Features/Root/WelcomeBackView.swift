import SwiftUI
import CryptoClickerKit

/// Shown after time away: what the miners earned, and whether the offline cap cut it short.
struct WelcomeBackView: View {
    let report: OfflineReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            CoinIcon(size: 72)
                .padding(.top, 28)
            VStack(spacing: 6) {
                Text("Welcome back!")
                    .font(.title.bold())
                Text("You were away for \(CoinFormat.duration(report.elapsed)).")
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 4) {
                Text("Your miners earned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                CoinAmount(amount: report.earned, font: .system(size: 40, weight: .bold, design: .rounded), iconSize: 34)
            }
            if report.wasCapped {
                Label("Miners stop after \(CoinFormat.duration(report.credited)) offline. Offline upgrades in the Shop raise the limit.",
                      systemImage: "hourglass")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Text("Collect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .padding()
        .presentationDetents([.medium])
    }
}
