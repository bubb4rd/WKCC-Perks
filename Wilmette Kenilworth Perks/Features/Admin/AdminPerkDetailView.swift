import SwiftUI

struct AdminPerkDetailView: View {
    let dealId: String

    @State private var detail: DealDetail?
    @State private var summary: DealSummary?
    @State private var isLoading = true
    @State private var isArchiving = false
    @State private var errorMessage: String?
    @State private var showArchiveConfirm = false
    @State private var showRestoreConfirm = false

    private let perksAdminService: any PerksAdminServicing = AppDependencies.shared.perksAdminService

    var body: some View {
        Group {
            if isLoading && detail == nil {
                LoadingView(message: "Loading perk...")
            } else if let detail {
                perkContent(detail)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Perk Not Found",
                    message: errorMessage ?? "This perk could not be loaded."
                )
            }
        }
        .wkccPageBackground()
        .navigationTitle("Perk Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if let detail {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: WKCCSpacing.sm) {
                        if detail.isArchived {
                            Button("Restore") {
                                showRestoreConfirm = true
                            }
                            .font(WKCCTypography.callout.weight(.semibold))
                            .foregroundStyle(WKCCColors.accent)
                            .disabled(isArchiving)
                        } else {
                            Button("Archive", role: .destructive) {
                                showArchiveConfirm = true
                            }
                            .font(WKCCTypography.callout.weight(.semibold))
                            .disabled(isArchiving)

                            NavigationLink {
                                AdminPerkEditorView(mode: .edit(dealId: dealId))
                            } label: {
                                Text("Edit")
                                    .font(WKCCTypography.callout.weight(.semibold))
                                    .foregroundStyle(WKCCColors.accent)
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Archive this perk?",
            isPresented: $showArchiveConfirm,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) {
                Task { await archive() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be hidden from the member catalog. You can restore it later.")
        }
        .confirmationDialog(
            "Restore this perk?",
            isPresented: $showRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("Restore") {
                Task { await unarchive() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will appear again in the member catalog (if not expired).")
        }
        .task(id: dealId) {
            await load()
        }
    }

    @ViewBuilder
    private func perkContent(_ detail: DealDetail) -> some View {
        let submission = detail.toPromotionSubmission(shortDescription: summary?.shortDescription)

        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.xl) {
                if detail.isArchived {
                    Text("Archived")
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.error)
                        .padding(.horizontal, WKCCSpacing.sm)
                        .padding(.vertical, WKCCSpacing.xs)
                        .background(WKCCColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                    Text(detail.title)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(WKCCColors.textPrimary)

                    HStack {
                        Text(detail.businessName)
                            .font(WKCCTypography.callout.weight(.semibold))
                            .foregroundStyle(WKCCColors.primary)

                        Label(detail.category.rawValue, systemImage: detail.category.iconName)
                            .font(WKCCTypography.captionBold)
                            .foregroundStyle(WKCCColors.textSecondary)
                    }
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage) {
                        self.errorMessage = nil
                    }
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: WKCCSpacing.sm),
                        GridItem(.flexible(), spacing: WKCCSpacing.sm),
                    ],
                    spacing: WKCCSpacing.sm
                ) {
                    if let startDate = detail.startDate {
                        ReviewFactTile(
                            icon: "calendar",
                            label: "Starts",
                            value: startDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    if let expirationDate = detail.expirationDate {
                        ReviewFactTile(
                            icon: "calendar.badge.clock",
                            label: "Ends",
                            value: expirationDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }

                EditorialDetailSection(
                    title: "Short summary",
                    content: summary?.shortDescription ?? submission.shortDescription,
                    collapsedLineLimit: 3
                )

                EditorialHairlineDivider()

                EditorialDetailSection(
                    title: "Full description",
                    content: detail.description,
                    collapsedLineLimit: 5
                )

                if let terms = detail.terms, !terms.isEmpty {
                    EditorialHairlineDivider()

                    EditorialListSection(
                        title: "Terms and exclusions",
                        items: submission.termsListItems,
                        collapsedVisibleCount: 3
                    )
                }

                EditorialHairlineDivider()

                EditorialDetailSection(
                    title: "How members redeem",
                    content: detail.redemptionInstructions,
                    footnote: detail.redemptionCode.map { "Code: \($0)" },
                    collapsedLineLimit: 4
                )
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.top, WKCCSpacing.md)
            .padding(.bottom, WKCCSpacing.xxl)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedDetail = try await perksAdminService.fetchPerk(id: dealId)
            let summaries = try await perksAdminService.fetchAllPerks()
            detail = loadedDetail
            summary = summaries.first { $0.id == dealId }
        } catch {
            detail = nil
            errorMessage = "Unable to load this perk."
        }

        isLoading = false
    }

    private func archive() async {
        isArchiving = true
        errorMessage = nil
        do {
            detail = try await perksAdminService.archivePerk(id: dealId)
            summary = summary.map {
                DealSummary(
                    id: $0.id,
                    title: $0.title,
                    businessId: $0.businessId,
                    businessName: $0.businessName,
                    shortDescription: $0.shortDescription,
                    category: $0.category,
                    expirationDate: $0.expirationDate,
                    isFeatured: $0.isFeatured,
                    membersOnly: $0.membersOnly,
                    archivedAt: detail?.archivedAt
                )
            }
        } catch {
            errorMessage = "Unable to archive this perk."
        }
        isArchiving = false
    }

    private func unarchive() async {
        isArchiving = true
        errorMessage = nil
        do {
            detail = try await perksAdminService.unarchivePerk(id: dealId)
            summary = summary.map {
                DealSummary(
                    id: $0.id,
                    title: $0.title,
                    businessId: $0.businessId,
                    businessName: $0.businessName,
                    shortDescription: $0.shortDescription,
                    category: $0.category,
                    expirationDate: $0.expirationDate,
                    isFeatured: $0.isFeatured,
                    membersOnly: $0.membersOnly,
                    archivedAt: nil
                )
            }
        } catch {
            errorMessage = "Unable to restore this perk."
        }
        isArchiving = false
    }
}

#Preview {
    NavigationStack {
        AdminPerkDetailView(dealId: MockData.dealSummaries[0].id)
    }
}
