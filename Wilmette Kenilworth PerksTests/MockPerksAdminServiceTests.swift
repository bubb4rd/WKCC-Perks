import Foundation
import Testing
@testable import Wilmette_Kenilworth_Perks

@MainActor
struct MockPerksAdminServiceTests {
    @Test func createPerkAppearsInDealsService() async throws {
        let store = MockDealsStore.shared
        store.resetToSeedData()
        let adminService = MockPerksAdminService(store: store)
        let dealsService = MockDealsService(store: store)

    var submission = PromotionSubmission()
    submission.title = "Admin Created Perk"
    submission.shortDescription = "Short copy"
    submission.fullDescription = "Full copy for members"
    submission.redemptionInstructions = "Show member card at checkout"

    let created = try await adminService.createPerk(
      submission,
      businessId: "biz-001",
      businessName: "Central Street Café"
    )

    let deals = try await dealsService.fetchDeals()
    #expect(deals.contains { $0.id == created.id })
    #expect(deals.first { $0.id == created.id }?.title == "Admin Created Perk")
  }

    @Test func updateSeededDealReflectsInDealsService() async throws {
        let store = MockDealsStore.shared
        store.resetToSeedData()
        let adminService = MockPerksAdminService(store: store)
        let dealsService = MockDealsService(store: store)

        let seedID = MockData.dealSummaries[0].id
        let original = try await dealsService.fetchDeal(id: seedID)
    var submission = PromotionSubmission()
    submission.title = "Updated Perk Title"
    submission.shortDescription = "Updated short description"
    submission.fullDescription = "Updated full description"
    submission.redemptionInstructions = "Updated redemption steps"
    submission.category = original.category
    submission.startDate = Date()
    submission.endDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!

    _ = try await adminService.updatePerk(
      id: original.id,
      submission: submission,
      businessId: original.businessId,
      businessName: original.businessName
    )

    let deals = try await dealsService.fetchDeals()
    #expect(deals.first { $0.id == seedID }?.title == "Updated Perk Title")
  }

  @Test func submissionApprovePublishesToSharedStore() async throws {
    let store = MockDealsStore.shared
    store.resetToSeedData()
    MockPromotionSubmissionStore.shared.resetToSeedData()
    let submissionService = MockPromotionSubmissionService(store: .shared, dealsStore: store)
    let dealsService = MockDealsService(store: store)

    let pending = try await submissionService.fetchSubmissions(status: .pending)
    guard let record = pending.first else {
      Issue.record("Expected at least one pending submission in seed data.")
      return
    }

    _ = try await submissionService.approve(id: record.id, reviewedBy: "admin-001")

    let deals = try await dealsService.fetchDeals()
    #expect(deals.contains { $0.id == "deal-sub-\(record.id)" })
  }

  @Test func archivePerkHidesFromMemberCatalogAndUnarchiveRestores() async throws {
    let store = MockDealsStore.shared
    store.resetToSeedData()
    let adminService = MockPerksAdminService(store: store)
    let dealsService = MockDealsService(store: store)

    let seedID = MockData.dealSummaries[1].id
    let before = try await dealsService.fetchDeals()
    #expect(before.contains { $0.id == seedID })

    let archived = try await adminService.archivePerk(id: seedID)
    #expect(archived.isArchived)

    let afterArchive = try await dealsService.fetchDeals()
    #expect(!afterArchive.contains { $0.id == seedID })

    await #expect(throws: ContentError.notFound) {
      _ = try await dealsService.fetchDeal(id: seedID)
    }

    let adminList = try await adminService.fetchAllPerks()
    #expect(adminList.contains { $0.id == seedID && $0.isArchived })

    let restored = try await adminService.unarchivePerk(id: seedID)
    #expect(!restored.isArchived)

    let afterRestore = try await dealsService.fetchDeals()
    #expect(afterRestore.contains { $0.id == seedID })
  }
}
