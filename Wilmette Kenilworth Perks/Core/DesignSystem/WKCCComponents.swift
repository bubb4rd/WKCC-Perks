import SwiftUI

struct WKCCPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WKCCSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(WKCCTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WKCCSpacing.md)
            .background(WKCCColors.primary)
            .foregroundStyle(WKCCColors.textOnPrimary)
            .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
        }
        .disabled(isLoading)
    }
}

struct WKCCSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WKCCTypography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .foregroundStyle(WKCCColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct DealCard: View {
    let deal: DealSummary

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack {
                if deal.isFeatured {
                    BadgeLabel(text: "Featured", color: WKCCColors.accent)
                }
                if deal.isExpiringSoon {
                    BadgeLabel(text: "Expiring Soon", color: WKCCColors.warning)
                }
                Spacer()
            }

            Text(deal.title)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)
                .lineLimit(2)

            Text(deal.businessName)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)

            Text(deal.shortDescription)
                .font(WKCCTypography.caption)
                .foregroundStyle(WKCCColors.textSecondary)
                .lineLimit(2)

            if let expiration = deal.expirationDate {
                HStack(spacing: WKCCSpacing.xxs) {
                    Image(systemName: "clock")
                    Text(expiration, format: .dateTime.month().day().year())
                }
                .font(WKCCTypography.caption)
                .foregroundStyle(deal.isExpiringSoon ? WKCCColors.warning : WKCCColors.textSecondary)
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }
}

struct BusinessCard: View {
    let business: ChamberBusiness

    var body: some View {
        HStack(spacing: WKCCSpacing.md) {
            BusinessLogoPlaceholder(category: business.category)

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text(business.name)
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)

                Text(business.category.rawValue)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.accent)

                Text(business.shortDescription)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .lineLimit(2)

                if business.activeDealCount > 0 {
                    Text("\(business.activeDealCount) active perk\(business.activeDealCount == 1 ? "" : "s")")
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.primary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }
}

struct BusinessLogoPlaceholder: View {
    let category: DealCategory
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WKCCRadius.md)
                .fill(WKCCColors.accent.opacity(0.15))
                .frame(width: size, height: size)

            Image(systemName: category.iconName)
                .font(.title2)
                .foregroundStyle(WKCCColors.primary)
        }
    }
}

struct BadgeLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, WKCCSpacing.xs)
            .padding(.vertical, WKCCSpacing.xxs)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct CategoryChip: View {
    let category: DealCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WKCCSpacing.xxs) {
                Image(systemName: category.iconName)
                Text(category.rawValue)
            }
            .font(WKCCTypography.captionBold)
            .padding(.horizontal, WKCCSpacing.sm)
            .padding(.vertical, WKCCSpacing.xs)
            .background(isSelected ? WKCCColors.primary : WKCCColors.cardBackground)
            .foregroundStyle(isSelected ? WKCCColors.textOnPrimary : WKCCColors.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(WKCCColors.primary.opacity(isSelected ? 0 : 0.15), lineWidth: 1)
            )
        }
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(WKCCTypography.brandCaps)
                .foregroundStyle(WKCCColors.primary)
                .tracking(0.5)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.accent)
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: WKCCSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(WKCCColors.accent)

            Text(title)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(message)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(WKCCSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: WKCCSpacing.md) {
            ProgressView()
                .tint(WKCCColors.primary)
            Text(message)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .wkccPageBackground()
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(WKCCTypography.callout)
            Spacer()
            Button("Dismiss", action: onDismiss)
                .font(WKCCTypography.captionBold)
        }
        .padding(WKCCSpacing.md)
        .background(WKCCColors.error.opacity(0.1))
        .foregroundStyle(WKCCColors.error)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
    }
}

struct WKCCBrandedPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(WKCCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wkccCardStyle()
    }
}
