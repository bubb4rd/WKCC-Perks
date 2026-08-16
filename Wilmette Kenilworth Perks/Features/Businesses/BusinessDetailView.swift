import SwiftUI

struct BusinessDetailView: View {
    let businessId: String

    @State private var business: ChamberBusiness?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAboutExpanded = false

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
        .navigationTitle("Business Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if let business {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareItem(for: business)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share business")
                }
            }
        }
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
        let activeDeals = business.activeDeals.filter { !$0.isExpired }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WKCCSpacing.xl) {
                BusinessDetailHeroImage(business: business)

                VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                    headerSection(business)
                    contactSection(business)
                }

                if let about = business.aboutText {
                    aboutSection(about)
                }

                dealsSection(activeDeals, logoURL: business.logoURL)
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.top, WKCCSpacing.lg)
            .padding(.bottom, WKCCSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .wkccPageBackground()
    }

    private func headerSection(_ business: ChamberBusiness) -> some View {
        Text(business.name)
            .font(.system(.title, design: .default).weight(.bold))
            .foregroundStyle(WKCCColors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func contactSection(_ business: ChamberBusiness) -> some View {
        let hasContact = business.address != nil
            || business.phone != nil
            || business.websiteURL != nil
            || !(business.email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || business.hasMapCoordinates

        if hasContact {
            VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                Text("Contact")
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)

                if let address = business.address {
                    contactRow(icon: "mappin.and.ellipse", text: address)
                }

                if let phone = business.phone {
                    Button {
                        openPhone(phone)
                    } label: {
                        contactRow(icon: "phone", text: phone)
                    }
                    .buttonStyle(.plain)
                }

                if let website = business.websiteURL {
                    Button {
                        UIApplication.shared.open(website)
                    } label: {
                        contactRow(icon: "globe", text: website.host ?? website.absoluteString)
                    }
                    .buttonStyle(.plain)
                }

                if let email = business.email?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !email.isEmpty
                {
                    Button {
                        openEmail(email)
                    } label: {
                        contactRow(icon: "envelope", text: email)
                    }
                    .buttonStyle(.plain)
                }

                if business.hasMapCoordinates {
                    Button {
                        openInMaps(business)
                    } label: {
                        contactRow(icon: "map", text: "Open in Maps")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func aboutSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("About")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(description)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textSecondary)
                .lineLimit(isAboutExpanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)

            if description.count > 160 || description.contains("\n") {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAboutExpanded.toggle()
                    }
                } label: {
                    Text(isAboutExpanded ? "Show Less" : "Read More")
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dealsSection(_ deals: [DealSummary], logoURL: URL?) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
            Text("Current Perks")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            if deals.isEmpty {
                Text("No active perks right now.")
                    .font(WKCCTypography.body)
                    .foregroundStyle(WKCCColors.textSecondary)
            } else {
                ForEach(deals) { deal in
                    NavigationLink(value: deal) {
                        DealCard(
                            deal: deal,
                            businessLogoURL: logoURL
                        )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(for: DealSummary.self) { deal in
            DealDetailView(dealId: deal.id)
        }
    }

    @ViewBuilder
    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: WKCCSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(WKCCColors.primary)
                .frame(width: 24)

            Text(text)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }

    private func openPhone(_ phone: String) {
        if let url = URL(string: "tel:\(phone.filter(\.isNumber))") {
            UIApplication.shared.open(url)
        }
    }

    private func openEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }

    private func openInMaps(_ business: ChamberBusiness) {
        guard let latitude = business.latitude, let longitude = business.longitude else { return }
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: business.name),
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }

    private func shareItem(for business: ChamberBusiness) -> String {
        if let website = business.websiteURL {
            return website.absoluteString
        }

        var parts = [business.name]
        if let address = business.address {
            parts.append(address)
        } else if let email = business.email {
            parts.append(email)
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Hero

private struct BusinessDetailHeroImage: View {
    let business: ChamberBusiness

    private let heroHeight: CGFloat = 260
    private let cornerRadius = WKCCRadius.xl

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .overlay {
                heroImage
            }
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.42)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var heroImage: some View {
        if let imageURL = business.logoURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                case .empty:
                    Color(white: 0.9)
                case .failure:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        ZStack {
            WKCCColors.accent.opacity(0.18)

            Image("WKCCLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 160)
                .padding(32)
                .accessibilityLabel(AppConfig.chamberName)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        BusinessDetailView(businessId: "biz-001")
    }
}
