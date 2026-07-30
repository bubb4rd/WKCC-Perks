import PhotosUI
import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var pendingSubmissionCount = 0
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingLogo = false
    @State private var logoUploadError: String?
    @State private var resolvedBusinessLogoURL: URL?
    @State private var ownBusiness: ChamberBusiness?

    private let submissionService: any PromotionSubmissionServicing = AppDependencies.shared.promotionSubmissionService
    private let businessService: any BusinessServicing = AppDependencies.shared.businessService

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.lg) {
                if let member = authManager.member {
                    memberHeader(member)
                    profileBlurbs(member)
                    businessActionsBlurb(member)
                }

                settingsSection

                WKCCSecondaryButton(title: "Sign Out") {
                    Task { await authManager.signOut() }
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
        .navigationTitle("Profile")
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: authManager.isChamberAdmin) {
            guard authManager.isChamberAdmin else {
                pendingSubmissionCount = 0
                return
            }
            pendingSubmissionCount = (try? await submissionService.pendingCount()) ?? 0
        }
        .task(id: authManager.member?.companyId) {
            await refreshOwnBusiness()
        }
        .onReceive(NotificationCenter.default.publisher(for: .businessLogoDidChange)) { _ in
            Task { await refreshOwnBusiness() }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePickedPhoto(newItem) }
        }
        .alert(
            "Couldn't update photo",
            isPresented: Binding(
                get: { logoUploadError != nil },
                set: { if !$0 { logoUploadError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { logoUploadError = nil }
        } message: {
            Text(logoUploadError ?? "")
        }
    }

    private func memberHeader(_ member: MemberProfile) -> some View {
        VStack(alignment: .center, spacing: WKCCSpacing.md) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    BusinessLogoView(
                        url: displayedLogoURL(for: member),
                        size: 80,
                        shape: .circle
                    )
                    .overlay {
                        if isUploadingLogo {
                            Circle()
                                .fill(Color.black.opacity(0.35))
                            ProgressView()
                                .tint(.white)
                        }
                    }

                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, WKCCColors.primary)
                        .font(.system(size: 26))
                        .offset(x: 4, y: 4)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploadingLogo)
            .accessibilityLabel("Change business photo")

            Text("\(member.firstName) \(member.lastName)")
                .font(WKCCTypography.title)
                .foregroundStyle(WKCCColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, WKCCSpacing.sm)
    }

    private func displayedLogoURL(for member: MemberProfile) -> URL? {
        member.companyLogoURL ?? resolvedBusinessLogoURL ?? ownBusiness?.logoURL
    }

    private func refreshOwnBusiness() async {
        guard let member = authManager.member else {
            ownBusiness = nil
            resolvedBusinessLogoURL = nil
            return
        }
        guard let companyId = member.companyId else {
            ownBusiness = nil
            resolvedBusinessLogoURL = nil
            return
        }

        let business = try? await businessService.fetchBusiness(id: companyId)
        ownBusiness = business
        if member.companyLogoURL == nil {
            resolvedBusinessLogoURL = business?.logoURL
        } else {
            resolvedBusinessLogoURL = nil
        }
    }

    private func isBusinessProfileIncomplete(for member: MemberProfile) -> Bool {
        let hasLogo = displayedLogoURL(for: member) != nil
        guard let business = ownBusiness else {
            // Until loaded, treat missing logo alone as a soft signal only after fetch.
            return false
        }
        let hasCategory = business.category != .other
        let hasAbout = !business.shortDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasWebsite = business.websiteURL != nil
        let hasPhone = !(business.phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasAddress = !(business.address?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return !hasLogo || !hasCategory || !hasAbout || !hasWebsite || !hasPhone || !hasAddress
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        isUploadingLogo = true
        logoUploadError = nil
        defer {
            isUploadingLogo = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = BusinessLogoImageProcessor.jpegData(from: image)
            else {
                logoUploadError = "That photo couldn't be read. Try another image."
                return
            }

            try await authManager.uploadCompanyLogo(imageData: jpeg, contentType: "image/jpeg")
            resolvedBusinessLogoURL = nil
            await refreshOwnBusiness()
        } catch {
            logoUploadError = error.localizedDescription
        }
    }

    private func profileBlurbs(_ member: MemberProfile) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Membership")
                .font(WKCCTypography.headline)
                .foregroundStyle(Color.black)

            VStack(spacing: 0) {
                profileBlurbRow(
                    icon: "seal.fill",
                    title: "Membership tier",
                    value: member.membershipTier.displayName
                )

                Divider()
                    .overlay(Color.black.opacity(0.08))
                    .padding(.leading, 56)

                profileBlurbRow(
                    icon: "calendar",
                    title: "Member since",
                    value: member.memberSince.map {
                        $0.formatted(.dateTime.year().month(.abbreviated))
                    } ?? "—"
                )
            }
            .wkccCardStyle()
        }
    }

    private func businessActionsBlurb(_ member: MemberProfile) -> some View {
        let isIncomplete = isBusinessProfileIncomplete(for: member)

        return VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Business")
                .font(WKCCTypography.headline)
                .foregroundStyle(Color.black)

            VStack(spacing: 0) {
                if let companyId = member.companyId {
                    NavigationLink {
                        EditBusinessProfileView(companyId: companyId)
                    } label: {
                        settingsListRow(
                            icon: "building.2.fill",
                            title: businessValue(for: member),
                            subtitle: "Edit business details",
                            showsChevron: true,
                            showsIncompleteBadge: isIncomplete
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(
                        isIncomplete
                            ? "Business information is incomplete. Double tap to edit."
                            : "Edit business details"
                    )
                } else {
                    settingsListRow(
                        icon: "building.2.fill",
                        title: businessValue(for: member),
                        showsChevron: false
                    )
                }

                Divider()
                    .overlay(Color.black.opacity(0.08))
                    .padding(.leading, 56)

                NavigationLink {
                    SubmitPromotionView()
                } label: {
                    settingsListRow(
                        icon: "megaphone.fill",
                        title: "Submit a Promotion",
                        showsChevron: true,
                        isFeatured: true
                    )
                }
                .buttonStyle(.plain)
            }
            .wkccCardStyle()
        }
    }

    private func businessValue(for member: MemberProfile) -> String {
        guard let name = member.companyName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else {
            return "—"
        }
        return name
    }

    private func profileBlurbRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: WKCCRadius.sm)
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(Color.black.opacity(0.65))

                Text(value)
                    .font(WKCCTypography.callout.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.vertical, WKCCSpacing.sm)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Settings")
                .font(WKCCTypography.headline)
                .foregroundStyle(Color.black)

            VStack(spacing: 0) {
                if authManager.isChamberAdmin {
                    NavigationLink {
                        ManagePerksView()
                    } label: {
                        settingsListRow(
                            icon: "tag.fill",
                            title: "Manage Perks",
                            subtitle: pendingSubmissionCount > 0
                                ? "\(pendingSubmissionCount) pending"
                                : nil,
                            subtitleColor: WKCCColors.warning,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    settingsDivider
                }

                NavigationLink {
                    HelpSupportView()
                } label: {
                    settingsListRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)

                settingsDivider

                Button {
                    UIApplication.shared.open(AppConfig.chamberWebsiteURL)
                } label: {
                    settingsListRow(
                        icon: "globe",
                        title: "Chamber Website",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
            .wkccCardStyle()
        }
    }

    private var settingsDivider: some View {
        Divider()
            .overlay(WKCCColors.primary.opacity(0.08))
            .padding(.leading, 56)
    }

    private func settingsListRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color = WKCCColors.textSecondary,
        showsChevron: Bool,
        isDisabled: Bool = false,
        isFeatured: Bool = false,
        showsIncompleteBadge: Bool = false
    ) -> some View {
        let iconBackground = isDisabled
            ? Color.black.opacity(0.05)
            : isFeatured
                ? WKCCColors.accent.opacity(0.08)
                : Color.black.opacity(0.08)
        let iconColor = isDisabled
            ? WKCCColors.textSecondary
            : isFeatured
                ? WKCCColors.accent
                : Color.black
        let titleColor = isDisabled
            ? WKCCColors.textSecondary
            : isFeatured
                ? WKCCColors.accent
                : Color.black

        return HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: WKCCRadius.sm)
                    .fill(iconBackground)
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
            }
            .overlay(alignment: .topTrailing) {
                if showsIncompleteBadge {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WKCCColors.warning)
                        .padding(1)
                        .background(
                            Circle()
                                .fill(WKCCColors.cardBackground)
                        )
                        .offset(x: 5, y: -5)
                        .accessibilityHidden(true)
                }
            }
            // Keep badge from colliding with the title.
            .padding(.trailing, showsIncompleteBadge ? 4 : 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WKCCTypography.callout.weight(.semibold))
                    .foregroundStyle(titleColor)

                if let subtitle {
                    Text(subtitle)
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(subtitleColor)
                }
            }

            Spacer(minLength: 0)

            if showsChevron && !isDisabled {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFeatured ? WKCCColors.accent : WKCCColors.textSecondary)
            }
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.vertical, WKCCSpacing.sm)
        .contentShape(Rectangle())
        .opacity(isDisabled ? 0.7 : 1)
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
}
