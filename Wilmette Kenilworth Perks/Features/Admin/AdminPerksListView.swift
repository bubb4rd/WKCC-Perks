import SwiftUI

struct AdminPerksListView: View {
    var isEmbedded = false
    var refreshToken = UUID()

    @State private var viewModel = AdminPerksListViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.perks.isEmpty {
                LoadingView(message: "Loading perks...")
            } else if viewModel.perks.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "No Perks Yet",
                    message: "Add a perk with the + button, or approve a member submission."
                )
            } else {
                perksList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .wkccPageBackground()
        .modifier(AdminPerksListNavigationModifier(isEmbedded: isEmbedded))
        .refreshable {
            await viewModel.load()
        }
        .task(id: refreshToken) {
            await viewModel.load()
        }
    }

    private var perksList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                if !viewModel.activePerks.isEmpty {
                    sectionHeader("Published")
                    ForEach(viewModel.activePerks) { perk in
                        perkLink(perk)
                    }
                }

                if !viewModel.archivedPerks.isEmpty {
                    sectionHeader("Archived")
                    ForEach(viewModel.archivedPerks) { perk in
                        perkLink(perk)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WKCCSpacing.md)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(WKCCTypography.captionBold)
            .foregroundStyle(WKCCColors.textSecondary)
            .textCase(.uppercase)
            .padding(.top, WKCCSpacing.xs)
    }

    private func perkLink(_ perk: DealSummary) -> some View {
        NavigationLink {
            AdminPerkDetailView(dealId: perk.id)
        } label: {
            AdminPerkRow(perk: perk)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdminPerksListNavigationModifier: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content
                .navigationTitle("Published Perks")
                .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private struct AdminPerkRow: View {
    let perk: DealSummary

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack(alignment: .center, spacing: WKCCSpacing.xs) {
                Label(perk.category.rawValue, systemImage: perk.category.iconName)
                    .font(WKCCTypography.captionBold)
                    .foregroundStyle(WKCCColors.textSecondary)

                Spacer(minLength: WKCCSpacing.xs)

                if perk.isArchived {
                    Text("Archived")
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.error)
                }
            }

            Text(perk.title)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(perk.businessName)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .lineLimit(1)

            if let expirationDate = perk.expirationDate {
                Text("Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(perk.isExpired ? WKCCColors.error : WKCCColors.textSecondary)
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(perk.isArchived ? 0.72 : 1)
        .wkccCardStyle()
    }
}

#Preview {
    NavigationStack {
        AdminPerksListView()
    }
}
