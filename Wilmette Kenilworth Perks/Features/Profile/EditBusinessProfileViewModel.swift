import Foundation
import Observation

@Observable
@MainActor
final class EditBusinessProfileViewModel {
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var didSave = false

    var draft = CompanyProfileUpdate()
    private(set) var businessName = ""

    private let companyId: String
    private let businessService: any BusinessServicing

    init(
        companyId: String,
        businessService: any BusinessServicing = AppDependencies.shared.businessService
    ) {
        self.companyId = companyId
        self.businessService = businessService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let business = try await businessService.fetchBusiness(id: companyId)
            businessName = business.name
            draft = CompanyProfileUpdate(business: business)
        } catch {
            errorMessage = "Unable to load your business profile."
        }
        isLoading = false
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        do {
            _ = try await businessService.updateCompanyProfile(draft)
            NotificationCenter.default.post(name: .businessLogoDidChange, object: nil)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func dismissError() {
        errorMessage = nil
    }
}
