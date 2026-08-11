import SwiftUI

@main
struct Wilmette_Kenilworth_PerksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authManager = AuthManager()

    init() {
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(authManager)
                .preferredColorScheme(.light)
        }
    }
}
