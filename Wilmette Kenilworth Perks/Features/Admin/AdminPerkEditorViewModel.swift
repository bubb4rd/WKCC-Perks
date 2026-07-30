import Foundation
import Observation

@Observable
@MainActor
final class AdminPerkEditorViewModel {
    enum Mode: Equatable {
        case create
        case edit(dealId: String)
    }

    let mode: Mode

    var submission = PromotionSubmission()
    var selectedBusinessId = ""
    private(set) var businesses: [ChamberBusiness] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    private let perksAdminService: any PerksAdminServicing
    private let businessService: any BusinessServicing

    init(
        mode: Mode,
        perksAdminService: any PerksAdminServicing = AppDependencies.shared.perksAdminService,
        businessService: any BusinessServicing = AppDependencies.shared.businessService
    ) {
        self.mode = mode
        self.perksAdminService = perksAdminService
        self.businessService = businessService
    }

    var navigationTitle: String {
        switch mode {
        case .create: "Add Perk"
        case .edit: "Edit Perk"
        }
    }

    var selectedBusinessName: String {
        businesses.first { $0.id == selectedBusinessId }?.name ?? ""
    }

    var isValid: Bool {
        guard !selectedBusinessId.isEmpty else { return false }

        return !submission.title.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.shortDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.fullDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.redemptionInstructions.trimmingCharacters(in: .whitespaces).isEmpty
            && submission.endDate >= submission.startDate
            && (!submission.redemptionCodeType.requiresCodeValue
                || !submission.redemptionCode.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            businesses = try await businessService.fetchBusinesses()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            switch mode {
            case .create:
                if let firstBusiness = businesses.first {
                    selectedBusinessId = firstBusiness.id
                }
            case .edit(let dealId):
                let detail = try await perksAdminService.fetchPerk(id: dealId)
                let summaries = try await perksAdminService.fetchAllPerks()
                let summary = summaries.first { $0.id == dealId }
                submission = detail.toPromotionSubmission(shortDescription: summary?.shortDescription)
                selectedBusinessId = detail.businessId
                if !businesses.contains(where: { $0.id == detail.businessId }) {
                    businesses.insert(
                        ChamberBusiness(
                            id: detail.businessId,
                            name: detail.businessName,
                            category: detail.category,
                            shortDescription: summary?.shortDescription ?? "",
                            fullDescription: nil,
                            logoURL: nil,
                            websiteURL: nil,
                            phone: nil,
                            address: nil,
                            email: nil,
                            latitude: nil,
                            longitude: nil,
                            memberSince: nil,
                            isChamberPartner: true,
                            activeDeals: [],
                            redemptionNotes: nil
                        ),
                        at: 0
                    )
                }
            }
        } catch {
            errorMessage = "Unable to load perk details."
        }

        isLoading = false
    }

    func dismissError() {
        errorMessage = nil
    }

    func save() async -> Bool {
        guard isValid, !isSaving else { return false }
        isSaving = true
        errorMessage = nil

        let businessName = selectedBusinessName

        do {
            switch mode {
            case .create:
                _ = try await perksAdminService.createPerk(
                    submission,
                    businessId: selectedBusinessId,
                    businessName: businessName
                )
            case .edit(let dealId):
                _ = try await perksAdminService.updatePerk(
                    id: dealId,
                    submission: submission,
                    businessId: selectedBusinessId,
                    businessName: businessName
                )
            }
            isSaving = false
            return true
        } catch {
            errorMessage = "Unable to save this perk."
            isSaving = false
            return false
        }
    }
}
