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
    @State private var navigationDirection = 1

    private var isLastPage: Bool {
        page == OnboardingSlide.all.count - 1
    }

    private var pageTransition: AnyTransition {
        let edge: Edge = navigationDirection >= 0 ? .trailing : .leading
        return .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: edge))
                .animation(.easeOut(duration: 0.32).delay(0.14)),
            removal: .opacity.animation(.easeInOut(duration: 0.16))
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 44)

                OnboardingSlidePage(slide: OnboardingSlide.all[page])
                    .id(page)
                    .transition(pageTransition)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }

            topBar
        }
        .wkccPageBackground()
    }

    private var topBar: some View {
        HStack {
            if page > 0 {
                circleButton(icon: "chevron.left") {
                    goBack()
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()

            if !isLastPage {
                Button("Skip") {
                    finish()
                }
                .font(WKCCTypography.callout.weight(.semibold))
                .foregroundStyle(WKCCColors.textSecondary)
                .accessibilityHint("Skip introduction and continue to sign in")
            } else {
                Color.clear.frame(width: 40, height: 20)
            }
        }
        .padding(.horizontal, WKCCSpacing.lg)
        .padding(.top, WKCCSpacing.sm)
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(WKCCColors.primary)
                .frame(width: 40, height: 40)
                .background(WKCCColors.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(WKCCColors.primary.opacity(0.1), lineWidth: 1)
                )
                .wkccCardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var footerTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .bottom))
                .animation(.easeOut(duration: 0.3).delay(0.16)),
            removal: .opacity.animation(.easeInOut(duration: 0.14))
        )
    }

    private var footer: some View {
        VStack(spacing: WKCCSpacing.md) {
            pageIndicator

            if isLastPage {
                VStack(spacing: WKCCSpacing.sm) {
                    WKCCPrimaryButton(title: "I Have an Account", trailingIcon: "arrow.right") {
                        finish()
                    }
                    WKCCSecondaryButton(title: "Join Now") {
                        UIApplication.shared.open(AppConfig.chamberWebsiteURL)
                    }
                }
                .id("lastPageButtons")
                .transition(footerTransition)
            } else {
                WKCCPrimaryButton(title: "Continue", trailingIcon: "arrow.right") {
                    advance()
                }
                .id("continueButton")
                .transition(footerTransition)
            }
        }
        .padding(.horizontal, WKCCSpacing.lg)
        .padding(.top, WKCCSpacing.sm)
        .padding(.bottom, WKCCSpacing.lg)
    }

    private var pageIndicator: some View {
        HStack(spacing: WKCCSpacing.xs) {
            ForEach(OnboardingSlide.all.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? WKCCColors.accent : WKCCColors.primary.opacity(0.16))
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
            navigationDirection = 1
            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
        }
    }

    private func goBack() {
        guard page > 0 else { return }
        navigationDirection = -1
        withAnimation(.easeInOut(duration: 0.3)) { page -= 1 }
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
        case join
    }

    static let all: [OnboardingSlide] = [
        OnboardingSlide(
            id: "perks",
            title: "Community perks, just for members",
            message: "See exclusive offers from WKCC businesses in one place.",
            artwork: .perks
        ),
        OnboardingSlide(
            id: "redeem",
            title: "Redeem in a few taps",
            message: "Open a perk, show the code or QR, and save at the register.",
            artwork: .redeem
        ),
        OnboardingSlide(
            id: "join",
            title: "Not a WKCC member?",
            message: "Join the Wilmette/Kenilworth Chamber of Commerce to unlock exclusive perks.",
            artwork: .join
        )
    ]
}

private struct OnboardingSlidePage: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: WKCCSpacing.xl) {
            Spacer(minLength: WKCCSpacing.sm)

            artwork
                .frame(maxWidth: .infinity)
                .frame(height: 330)
                .accessibilityHidden(true)

            VStack(spacing: WKCCSpacing.sm) {
                Text(slide.title)
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .tracking(-0.3)
                    .foregroundStyle(WKCCColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(slide.message)
                    .font(WKCCTypography.body)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, WKCCSpacing.sm)
            }
            .padding(.horizontal, WKCCSpacing.sm)

            Spacer(minLength: WKCCSpacing.sm)
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
        case .join:
            JoinArtwork()
        }
    }
}

/// Soft layered glow behind each slide's hero art, for depth instead of flat shapes.
private struct OnboardingHalo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [WKCCColors.primary.opacity(0.14), WKCCColors.primary.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 170
                    )
                )
                .frame(width: 320, height: 320)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [WKCCColors.accent.opacity(0.34), WKCCColors.accent.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .offset(x: 96, y: -74)
        }
    }
}

/// Small orbiting icon chip, echoing the satellite avatars in premium onboarding kits.
private struct FloatingBadge: View {
    let icon: String
    var tint: Color = WKCCColors.accent

    var body: some View {
        Image(systemName: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(WKCCColors.cardBackground)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(tint.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.28), radius: 8, x: 0, y: 4)
    }
}

private struct PerksArtwork: View {
    var body: some View {
        ZStack {
            OnboardingHalo()

            heroCard
                .rotationEffect(.degrees(4))

            FloatingBadge(icon: "mappin.circle.fill", tint: WKCCColors.accent)
                .offset(x: 96, y: -150)

            FloatingBadge(icon: "checkmark.seal.fill", tint: WKCCColors.primary)
                .offset(x: -100, y: 100)
        }
    }

    private var ghostCard: some View {
        RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [WKCCColors.primary.opacity(0.32), WKCCColors.accent.opacity(0.32)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 180, height: 260)
            .overlay(
                RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: WKCCColors.primary.opacity(0.14), radius: 14, x: 0, y: 8)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image("OnboardingMemberPhoto")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.05), Color.black.opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        BadgeLabel(text: "20% Off", color: .white, surface: .dark)
                    }
                }
                .padding(WKCCSpacing.sm)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Member offer")
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)
                Text("Participating local shops")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
            }
            .padding(WKCCSpacing.sm)
        }
        .frame(width: 192)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: WKCCColors.primary.opacity(0.20), radius: 22, x: 0, y: 14)
    }
}

private struct RedeemArtwork: View {
    var body: some View {
        ZStack {
            OnboardingHalo()

            ticketCard
                .rotationEffect(.degrees(-3))

            checkStamp
                .offset(x: 100, y: -104)

            FloatingBadge(icon: "bolt.fill", tint: WKCCColors.primary)
                .offset(x: -100, y: 104)
        }
    }

    private var ticketCard: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text("PERK CODE")
                .font(WKCCTypography.captionBold)
                .foregroundStyle(WKCCColors.textSecondary)
                .tracking(0.6)

            qrGrid

            Capsule()
                .fill(WKCCColors.accent)
                .frame(height: 40)
                .overlay(
                    Text("Show at checkout")
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(.white)
                )
        }
        .padding(WKCCSpacing.md)
        .frame(width: 224)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.xl, style: .continuous)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: WKCCColors.primary.opacity(0.18), radius: 20, x: 0, y: 12)
    }

    private var qrGrid: some View {
        RoundedRectangle(cornerRadius: WKCCRadius.md, style: .continuous)
            .fill(WKCCColors.primary.opacity(0.05))
            .frame(height: 108)
            .overlay {
                VStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<4, id: \.self) { column in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(
                                        (row + column).isMultiple(of: 2)
                                            ? WKCCColors.primary
                                            : WKCCColors.primary.opacity(0.25)
                                    )
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
            }
    }

    private var checkStamp: some View {
        Image(systemName: "checkmark")
            .font(.title.weight(.bold))
            .foregroundStyle(WKCCColors.textOnPrimary)
            .frame(width: 60, height: 60)
            .background(WKCCColors.accent)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(WKCCColors.cardBackground, lineWidth: 3)
            )
            .shadow(color: WKCCColors.accent.opacity(0.35), radius: 10, x: 0, y: 6)
    }
}

private struct JoinArtwork: View {
    var body: some View {
        ZStack {
            OnboardingHalo()

            communityRings

            satellite(image: "OnboardingMemberPhoto", tint: WKCCColors.primary, size: 48)
                .offset(x: -82, y: -82)

            satellite(image: "AtProperties", tint: WKCCColors.accent, size: 64)
                .offset(x: 82, y: -78)

            satellite(image: "Wayfair", tint: WKCCColors.accent, size: 64)
                .offset(x: -52, y: 96)

            satellite(image: "BylineBank", tint: WKCCColors.primary, size: 48)
                .offset(x: 108, y: 80)

            satellite(icon: "sparkles", tint: WKCCColors.accent, size:30)
                .offset(x: -12, y: -128)
            
            satellite(icon: "heart.fill", tint: WKCCColors.primary, size:30)
                .offset(x: 102, y: 8)
            satellite(icon: "bolt.fill", tint: WKCCColors.accent, size:30)
                .offset(x: -92, y: 12)
            satellite(icon: "leaf.fill", tint: WKCCColors.primary, size:30)
                .offset(x: 50, y: 120)

            centerMark
        }
    }

    private var communityRings: some View {
        ZStack {
            Circle()
                .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                .frame(width: 264, height: 264)

            Circle()
                .stroke(WKCCColors.accent.opacity(0.2), lineWidth: 1)
                .frame(width: 196, height: 196)
        }
    }

    private var centerMark: some View {
        WKCCLogoView(style: .mark, maxWidth: 72)
            .padding(WKCCSpacing.lg)
            .background(WKCCColors.cardBackground)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(WKCCColors.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: WKCCColors.primary.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    /// Icon-badge satellite (SF Symbol), e.g. `satellite(icon: "star.fill", tint: ..., size: 56)`.
    private func satellite(icon: String, tint: Color, size: CGFloat) -> some View {
        iconSatelliteContainer(tint: tint, size: size) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.white)
        }
    }

    /// Photo-avatar satellite backed by an asset catalog image (e.g. a real member/community photo),
    /// e.g. `satellite(image: "CommunityMemberPhoto", tint: ..., size: 56)`.
    private func satellite(image: String, tint: Color, size: CGFloat) -> some View {
        imageSatelliteContainer(tint: tint, size: size) {
            Image(image)
                .resizable()
                .scaledToFill()
        }
    }

    /// Chrome for icon-badge satellites: tint→shade gradient fill behind the glyph, with a
    /// matching shade-colored ring — the badge's own color carries the border.
    private func iconSatelliteContainer(
        tint: Color,
        size: CGFloat,
        @ViewBuilder content: () -> some View
    ) -> some View {
        let shade = tint == WKCCColors.primary ? WKCCColors.primaryDark : WKCCColors.accentDark

        return content()
            .frame(width: size, height: size)
            .background(LinearGradient(
                colors: [tint, shade],
                startPoint: .bottomTrailing,
                endPoint: .topLeading
            ))
            .clipShape(Circle())
            .overlay(
                Circle().stroke(shade)
            )
            .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 4)
    }

    /// Chrome for photo-avatar satellites: the photo fills the circle on its own, so instead of a
    /// tinted ring it gets a plain card-background "cutout" border to separate it from the halo.
    private func imageSatelliteContainer(
        tint: Color,
        size: CGFloat,
        @ViewBuilder content: () -> some View
    ) -> some View {
        content()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(WKCCColors.cardBackground, lineWidth: 2)
            )
            .shadow(color: tint.opacity(0.22), radius: 8, x: 0, y: 4)
    }

    /// Mini icon-badge satellite, styled like `satellite(icon:tint:size:)` but smaller —
    /// for accent points along the rings instead of a plain color dot.
    private func dot(icon: String, color: Color) -> some View {
        iconSatelliteContainer(tint: color, size: 24) {
            Image(systemName: icon)
                .font(.system(size: 11).weight(.semibold))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
