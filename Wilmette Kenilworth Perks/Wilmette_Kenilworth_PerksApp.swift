import SwiftUI

@main
struct Wilmette_Kenilworth_PerksApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environment(authManager)
                .preferredColorScheme(.light)
        }
    }
}
