import Foundation

enum AppDependencies {
    static let shared = AppDependenciesContainer()

    final class AppDependenciesContainer {
        let authService: any AuthServicing
        let dealsService: any DealsServicing
        let businessService: any BusinessServicing
        let promotionSubmissionService: any PromotionSubmissionServicing
        let perksAdminService: any PerksAdminServicing
        let notificationService: any NotificationServicing

        init() {
            let useMock = AppConfig.useMockAuth
            authService = useMock ? MockAuthService() : MemberAuthService()
            dealsService = useMock ? MockDealsService() : SupabaseDealsService()
            businessService = useMock ? MockBusinessService() : SupabaseBusinessService()
            promotionSubmissionService = useMock
                ? MockPromotionSubmissionService()
                : SupabasePromotionSubmissionService()
            perksAdminService = useMock
                ? MockPerksAdminService()
                : SupabasePerksAdminService()
            notificationService = MockNotificationService()
        }
    }
}
