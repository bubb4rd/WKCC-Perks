import Foundation

enum AppDependencies {
    static let shared = AppDependenciesContainer()

    final class AppDependenciesContainer {
        let authService: any AuthServicing
        let dealsService: any DealsServicing
        let businessService: any BusinessServicing

        init() {
            authService = AppConfig.useMockAuth
                ? MockAuthService()
                : GrowthZoneAuthService()
            dealsService = MockDealsService()
            businessService = MockBusinessService()
        }
    }
}
