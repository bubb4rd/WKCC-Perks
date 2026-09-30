import SwiftUI

struct AppRouter: View {
    @Environment(AuthManager.self) private var authManager
    @State private var hasCompletedOnboarding = OnboardingStore.hasCompleted

    private var showsOnboarding: Bool {
        !hasCompletedOnboarding
            && authManager.flowState == .unauthenticated
            && !authManager.isCodeSent
    }

    var body: some View {
        Group {
            switch authManager.flowState {
            case .launching:
                SplashView()
            case .unauthenticated, .authenticating, .confirmingLink:
                if showsOnboarding {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                } else {
                    NavigationStack {
                        LoginView()
                    }
                }
            case .authenticated:
                MainTabView()
            case .restrictedMembership:
                RestrictedAccessView()
            case .error(let message):
                ErrorStateView(message: message) {
                    authManager.dismissError()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.flowState)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .task {
            await authManager.bootstrap()
        }
        .onReceive(NotificationCenter.default.publisher(for: .memberSessionDidRefresh)) { _ in
            authManager.syncSessionFromKeychain()
        }
        .onReceive(NotificationCenter.default.publisher(for: .memberSessionDidExpire)) { _ in
            authManager.handleSessionExpiredFromKeychain()
        }
    }
}

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: WKCCSpacing.lg) {
            WKCCLogoView(style: .mark, maxWidth: 80)

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(WKCCColors.error)

            Text("Something went wrong")
                .font(WKCCTypography.title)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(message)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textSecondary)
                .multilineTextAlignment(.center)

            WKCCPrimaryButton(title: "Try Again", action: onRetry)
                .padding(.horizontal, WKCCSpacing.xl)
        }
        .padding(WKCCSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .wkccPageBackground()
    }
}

enum MainTab: Hashable {
    case home
    case deals
    case businesses
    case profile
}

extension EnvironmentValues {
    /// Switches the main tab bar, e.g. Home's "View all" jumping to the Businesses tab.
    @Entry var selectMainTab: (MainTab) -> Void = { _ in }
    /// Jumps to the Businesses tab with `category` applied as its filter.
    @Entry var showBusinesses: (DealCategory) -> Void = { _ in }
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home
    /// One-shot request consumed by BusinessesListView.
    @State private var requestedBusinessCategory: DealCategory?

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)

            NavigationStack {
                DealsListView()
            }
            .tabItem {
                Label("Deals", systemImage: "tag.fill")
            }
            .tag(MainTab.deals)

            NavigationStack {
                BusinessesListView(requestedCategory: $requestedBusinessCategory)
            }
            .tabItem {
                Label("Businesses", systemImage: "building.2.fill")
            }
            .tag(MainTab.businesses)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(MainTab.profile)
        }
        .environment(\.selectMainTab) { selectedTab = $0 }
        .environment(\.showBusinesses) { category in
            requestedBusinessCategory = category
            selectedTab = .businesses
        }
        .tint(WKCCColors.primary)
        .toolbarBackground(WKCCColors.cardBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
