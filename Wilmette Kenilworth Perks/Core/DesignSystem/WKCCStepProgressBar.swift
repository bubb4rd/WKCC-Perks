import SwiftUI

/// Capsule progress track with labeled steps (used by login and submit-promotion flows).
struct WKCCStepProgressBar: View {
    let labels: [String]
    /// Zero-based index of the current step.
    let currentIndex: Int

    var body: some View {
        VStack(spacing: WKCCSpacing.sm) {
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let denominator = max(labels.count - 1, 1)
                let progress = CGFloat(currentIndex) / CGFloat(denominator)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WKCCColors.primary.opacity(0.12))
                        .frame(height: 6)

                    Capsule()
                        .fill(WKCCColors.primary)
                        .frame(width: max(6, trackWidth * progress), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(
                            index <= currentIndex
                                ? WKCCColors.primary
                                : WKCCColors.textSecondary
                        )
                        .frame(maxWidth: .infinity, alignment: alignment(for: index))
                }
            }
        }
    }

    private func alignment(for index: Int) -> Alignment {
        switch index {
        case 0: .leading
        case labels.count - 1: .trailing
        default: .center
        }
    }
}

#Preview {
    WKCCStepProgressBar(labels: ["Company", "Offer", "Confirm"], currentIndex: 1)
        .padding()
        .wkccPageBackground()
}
