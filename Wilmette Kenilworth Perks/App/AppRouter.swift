import SwiftUI

struct AppRouter: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            switch authManager.flowState {
            case .launching:
                SplashView()
            case .unauthenticated, .authenticating:
                LoginView()
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
        .task {
            await authManager.bootstrap()
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
        .wkccPageBackground()
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            NavigationStack {
                DealsListView()
            }
            .tabItem {
                Label("Deals", systemImage: "tag.fill")
            }
            .tag(1)

            NavigationStack {
                BusinessesListView()
            }
            .tabItem {
                Label("Businesses", systemImage: "building.2.fill")
            }
            .tag(2)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(3)
        }
        .tint(WKCCColors.primary)
        .toolbarBackground(WKCCColors.cardBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
