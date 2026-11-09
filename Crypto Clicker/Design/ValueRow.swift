import SwiftUI
import CryptoClickerKit

/// A label and its value on one line, or the value under the label once it won't fit beside it, so
/// a long figure (every digit of a late-game balance, a range of two of them) never wraps into a
/// ragged right-hand column. For the Income and Statistics lists.
struct ValueRow: View {
    let title: String
    let value: String
    /// A second figure under the value, such as its share of a total.
    var detail: String? = nil
    var bold = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                titleText
                    .fixedSize()
                Spacer(minLength: 12)
                figures(alignment: .trailing)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: 3) {
                titleText
                    .fixedSize(horizontal: false, vertical: true)
                figures(alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var titleText: some View {
        Text(title)
            .fontWeight(bold ? .bold : .regular)
    }

    private func figures(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(value)
                .fontWeight(bold ? .bold : .regular)
                .foregroundStyle(bold ? AnyShapeStyle(.primary) : AnyShapeStyle(.subtext))
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if let detail {
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.subtext)
            }
        }
        .monospacedDigit()
    }
}

/// One source's part of the income: an icon, its name and what boosts it, its rate and share, and
/// a bar for the share. The rate moves under the name when it's too long to sit beside it.
struct ShareRow<Icon: View>: View {
    let title: String
    let detail: String
    /// The rate, formatted: "8,352,403".
    let rate: String
    let share: Double
    @ViewBuilder let icon: Icon

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                icon
                    .frame(width: 30)
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        names
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            rateText
                            shareText
                        }
                        .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        names
                        HStack(alignment: .firstTextBaseline) {
                            rateText
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Spacer(minLength: 8)
                            shareText
                                .fixedSize()
                        }
                    }
                }
            }
            ProgressView(value: min(max(share, 0), 1))
                .tint(Theme.accent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.subtext)
        }
    }

    private var rateText: some View {
        Text("\(rate)/s")
            .font(.subheadline.weight(.semibold).monospacedDigit())
    }

    private var shareText: some View {
        Text(CoinFormat.percent(share))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.accent)
    }
}
