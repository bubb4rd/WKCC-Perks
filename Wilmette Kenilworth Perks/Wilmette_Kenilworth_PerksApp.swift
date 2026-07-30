import SwiftUI

@main
struct Wilmette_Kenilworth_PerksApp: App {
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
