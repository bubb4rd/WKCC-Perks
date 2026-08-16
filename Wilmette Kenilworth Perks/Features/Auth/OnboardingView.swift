import SwiftUI

enum OnboardingStore {
    private static let key = "wkcc.hasCompletedOnboarding"

    static var hasCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var page = 0

    private var isLastPage: Bool {
        page == OnboardingSlide.all.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(OnboardingSlide.all.enumerated()), id: \.element.id) { index, slide in
                    OnboardingSlidePage(slide: slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.28), value: page)

            footer
        }
        .wkccPageBackground()
    }

    private var footer: some View {
        VStack(spacing: WKCCSpacing.md) {
            pageIndicator

            WKCCPrimaryButton(title: isLastPage ? "Get started" : "Next") {
                advance()
            }

            if isLastPage {
                Color.clear
                    .frame(height: skipRowHeight)
            } else {
                Button("Skip") {
                    finish()
                }
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.primary)
                .frame(height: skipRowHeight)
                .accessibilityHint("Skip introduction and continue to sign in")
            }
        }
        .padding(.horizontal, WKCCSpacing.lg)
        .padding(.top, WKCCSpacing.sm)
        .padding(.bottom, WKCCSpacing.lg)
    }

    private var skipRowHeight: CGFloat { 24 }

    private var pageIndicator: some View {
        HStack(spacing: WKCCSpacing.xs) {
            ForEach(OnboardingSlide.all.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? WKCCColors.accent : WKCCColors.primary.opacity(0.18))
                    .frame(width: index == page ? 28 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.22), value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(OnboardingSlide.all.count)")
    }

    private func advance() {
        if isLastPage {
            finish()
        } else {
            page += 1
        }
    }

    private func finish() {
        OnboardingStore.hasCompleted = true
        onFinished()
    }
}

private struct OnboardingSlide: Identifiable {
    let id: String
    let title: String
    let message: String
    let artwork: Artwork

    enum Artwork {
        case perks
        case redeem
        case memberCard
    }

    static let all: [OnboardingSlide] = [
        OnboardingSlide(
            id: "perks",
            title: "Local perks, just for members",
            message: "See exclusive offers from Wilmette and Kenilworth businesses in one list.",
            artwork: .perks
        ),
        OnboardingSlide(
            id: "redeem",
            title: "Redeem in a few taps",
            message: "Open a perk, show the code or QR, and save at the register.",
            artwork: .redeem
        ),
        OnboardingSlide(
            id: "card",
            title: "Your member card, ready",
            message: "Carry digital proof of membership when you walk into a participating shop.",
            artwork: .memberCard
        )
    ]
}

private struct OnboardingSlidePage: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: WKCCSpacing.xl) {
            Spacer(minLength: WKCCSpacing.md)

            artwork
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .accessibilityHidden(true)

            VStack(spacing: WKCCSpacing.sm) {
                Text(slide.title)
                    .font(WKCCTypography.largeTitle)
                    .foregroundStyle(WKCCColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(slide.message)
                    .font(WKCCTypography.body)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, WKCCSpacing.sm)

            Spacer(minLength: WKCCSpacing.md)
        }
        .padding(.horizontal, WKCCSpacing.lg)
    }

    @ViewBuilder
    private var artwork: some View {
        switch slide.artwork {
        case .perks:
            PerksArtwork()
        case .redeem:
            RedeemArtwork()
        case .memberCard:
            MemberCardArtwork()
        }
    }
}

private struct OnboardingStage: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(WKCCColors.primary.opacity(0.06))
                .frame(width: 268, height: 268)

            Circle()
                .fill(WKCCColors.accent.opacity(0.22))
                .frame(width: 108, height: 108)
                .offset(x: 98, y: -78)

            Circle()
                .fill(WKCCColors.primary.opacity(0.08))
                .frame(width: 64, height: 64)
                .offset(x: -110, y: 86)
        }
    }
}

private struct PerksArtwork: View {
    var body: some View {
        ZStack {
            OnboardingStage()

            perkTile(
                icon: "tag.fill",
                title: "Member offer",
                detail: "Participating shops"
            )
            .rotationEffect(.degrees(-8))
            .offset(x: -28, y: 18)

            perkTile(
                icon: "building.2.fill",
                title: "Local partners",
                detail: "Wilmette & Kenilworth"
            )
            .rotationEffect(.degrees(7))
            .offset(x: 36, y: -36)
        }
    }

    private func perkTile(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: WKCCSpacing.sm) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(WKCCColors.accent)
                .frame(width: 40, height: 40)
                .background(WKCCColors.accent.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)
                Text(detail)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(WKCCSpacing.sm)
        .frame(width: 236)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.lg, style: .continuous)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: WKCCColors.primary.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

private struct RedeemArtwork: View {
    var body: some View {
        ZStack {
            OnboardingStage()

            HStack(alignment: .center, spacing: WKCCSpacing.md) {
                phone
                checkBadge
            }
        }
    }

    private var phone: some View {
        VStack(spacing: WKCCSpacing.sm) {
            Capsule()
                .fill(WKCCColors.primary.opacity(0.16))
                .frame(width: 36, height: 5)

            RoundedRectangle(cornerRadius: WKCCRadius.sm, style: .continuous)
                .stroke(WKCCColors.primary, lineWidth: 3)
                .frame(width: 84, height: 84)
                .overlay {
                    VStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { column in
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill((row + column).isMultiple(of: 2) ? WKCCColors.primary : WKCCColors.primary.opacity(0.28))
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                }

            Capsule()
                .fill(WKCCColors.accent)
                .frame(width: 56, height: 8)
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.vertical, WKCCSpacing.lg)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(WKCCColors.primary.opacity(0.14), lineWidth: 2)
        )
        .shadow(color: WKCCColors.primary.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var checkBadge: some View {
        Image(systemName: "checkmark")
            .font(.title.weight(.bold))
            .foregroundStyle(WKCCColors.textOnPrimary)
            .frame(width: 64, height: 64)
            .background(WKCCColors.accent)
            .clipShape(Circle())
            .shadow(color: WKCCColors.accent.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

private struct MemberCardArtwork: View {
    var body: some View {
        ZStack {
            OnboardingStage()

            VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                HStack(alignment: .top) {
                    WKCCLogoView(style: .mark, maxWidth: 52)

                    Spacer(minLength: WKCCSpacing.sm)

                    Text("MEMBER")
                        .font(WKCCTypography.brandCaps)
                        .foregroundStyle(WKCCColors.accent)
                        .tracking(1)
                }

                VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(WKCCColors.primary.opacity(0.82))
                        .frame(width: 148, height: 12)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(WKCCColors.primary.opacity(0.22))
                        .frame(width: 110, height: 8)
                }
                .padding(.top, WKCCSpacing.xs)

                Spacer(minLength: WKCCSpacing.xs)

                Rectangle()
                    .fill(WKCCColors.accent)
                    .frame(height: 2)

                HStack {
                    Text("Show at checkout")
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.textSecondary)
                    Spacer()
                    Image(systemName: "qrcode")
                        .font(.title3)
                        .foregroundStyle(WKCCColors.primary)
                }
            }
            .padding(WKCCSpacing.md)
            .frame(width: 260, height: 168, alignment: .topLeading)
            .background(WKCCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous)
                    .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: WKCCColors.primary.opacity(0.1), radius: 12, x: 0, y: 6)
            .rotationEffect(.degrees(-4))
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
