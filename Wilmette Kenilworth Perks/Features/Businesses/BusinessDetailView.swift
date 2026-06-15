import SwiftUI

struct BusinessDetailView: View {
    let businessId: String

    @State private var business: ChamberBusiness?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let businessService: any BusinessServicing = AppDependencies.shared.businessService

    var body: some View {
        Group {
            if isLoading && business == nil {
                LoadingView(message: "Loading business...")
            } else if let business {
                businessContent(business)
            } else {
                EmptyStateView(
                    icon: "building.2.crop.circle",
                    title: "Business Not Found",
                    message: errorMessage ?? "This business may no longer be participating."
                )
            }
        }
        .navigationTitle(business?.name ?? "Business")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await load()
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            business = try await businessService.fetchBusiness(id: businessId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func businessContent(_ business: ChamberBusiness) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                headerSection(business)

                if let description = business.fullDescription {
                    aboutSection(description)
                }

                if !business.activeDeals.filter({ !$0.isExpired }).isEmpty {
                    dealsSection(business)
                }

                contactSection(business)

                if let notes = business.redemptionNotes {
                    redemptionNotesSection(notes)
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
    }

    private func headerSection(_ business: ChamberBusiness) -> some View {
        HStack(spacing: WKCCSpacing.md) {
            BusinessLogoPlaceholder(category: business.category, size: 72)

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text(business.name)
                    .font(WKCCTypography.title)

                Text(business.category.rawValue)
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.accent)

                if business.isChamberPartner {
                    BadgeLabel(text: "Chamber Partner", color: WKCCColors.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aboutSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("About")
                .font(WKCCTypography.headline)

            Text(description)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }

    private func dealsSection(_ business: ChamberBusiness) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Current Perks")
                .font(WKCCTypography.headline)

            ForEach(business.activeDeals.filter { !$0.isExpired }) { deal in
                NavigationLink(value: deal) {
                    DealCard(deal: deal)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: DealSummary.self) { deal in
            DealDetailView(dealId: deal.id)
        }
    }

    private func contactSection(_ business: ChamberBusiness) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Contact")
                .font(WKCCTypography.headline)

            if let address = business.address {
                contactRow(icon: "mappin.and.ellipse", text: address)
            }

            if let phone = business.phone {
                Button {
                    if let url = URL(string: "tel:\(phone.filter { $0.isNumber })") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    contactRow(icon: "phone", text: phone)
                }
            }

            if let website = business.websiteURL {
                Button {
                    UIApplication.shared.open(website)
                } label: {
                    contactRow(icon: "globe", text: website.host ?? "Website")
                }
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: WKCCSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(WKCCColors.primary)
                .frame(width: 24)
            Text(text)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textPrimary)
            Spacer()
        }
    }

    private func redemptionNotesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Label("Redemption Notes", systemImage: "info.circle")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.warning)

            Text(notes)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WKCCColors.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
    }
}

#Preview {
    NavigationStack {
        BusinessDetailView(businessId: "biz-001")
    }
}
