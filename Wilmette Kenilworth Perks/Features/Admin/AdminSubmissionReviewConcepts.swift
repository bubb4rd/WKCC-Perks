import SwiftUI

// MARK: - Design Concepts Gallery

/// Two alternate layouts for the admin Review Submission screen.
/// Open `AdminSubmissionReviewConceptsGallery` in Xcode Previews to compare.
struct AdminSubmissionReviewConceptsGallery: View {
    private let record = MockData.seedPromotionSubmissions[0]

    var body: some View {
        TabView {
            NavigationStack {
                AdminSubmissionReviewConceptA(record: record)
            }
            .tabItem {
                Label("Preview First", systemImage: "eye.fill")
            }

            NavigationStack {
                AdminSubmissionReviewConceptB(record: record)
            }
            .tabItem {
                Label("Review Brief", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}

// MARK: - Concept A: Perk Preview First

/// Hero summary, live deal card preview, disclosure details, sticky action bar.
struct AdminSubmissionReviewConceptA: View {
    let record: PromotionSubmissionRecord

    @State private var expandedSections: Set<ReviewDetailSection> = [.promotion, .redemption]
    @State private var adminNotes = ""
    @State private var showApproveConfirm = false
    @State private var showRejectConfirm = false

    private var submission: PromotionSubmission { record.submission }
    private var dealPreview: DealSummary {
        submission.makeDealSummary(
            id: "preview",
            businessId: record.companyId ?? "preview-biz",
            businessName: record.companyName
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                heroBand
                submitterCard
                memberPreviewSection
                detailDisclosures
                adminNotesBlock
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.top, WKCCSpacing.md)
            .padding(.bottom, WKCCSpacing.xxl + 72)
        }
        .wkccPageBackground()
        .navigationTitle("Review Submission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if record.status == .pending {
                stickyActionBar
            }
        }
        .confirmationDialog("Approve this promotion?", isPresented: $showApproveConfirm, titleVisibility: .visible) {
            Button("Approve") {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Approved perks will appear in the Deals tab.")
        }
        .confirmationDialog("Reject this promotion?", isPresented: $showRejectConfirm, titleVisibility: .visible) {
            Button("Reject", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            adminNotes = record.adminNotes ?? ""
        }
    }

    private var heroBand: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            HStack {
                SubmissionStatusBadge(status: record.status)
                Spacer()
                Text(record.submittedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textOnPrimary.opacity(0.75))
            }

            Text(submission.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(WKCCColors.textOnPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: WKCCSpacing.sm) {
                Label(record.companyName, systemImage: "building.2.fill")
                Spacer(minLength: 0)
                PromotionDateRangeChip(
                    start: submission.startDate,
                    end: submission.endDate
                )
            }
            .font(WKCCTypography.captionBold)
            .foregroundStyle(WKCCColors.textOnPrimary.opacity(0.9))
        }
        .padding(WKCCSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [WKCCColors.primary, WKCCColors.primary.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .wkccCardShadow()
    }

    private var submitterCard: some View {
        HStack(spacing: WKCCSpacing.md) {
            MemberInitialsAvatar(name: record.submitterName, size: 52)

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text("Submitted by")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)

                Text(record.submitterName)
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)

                Text(record.companyName)
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: WKCCSpacing.xxs) {
                if !submission.contactPhone.isEmpty {
                    contactLink(icon: "phone.fill", urlString: "tel:\(submission.contactPhone.filter { $0.isNumber })")
                }

                if !submission.contactEmail.isEmpty {
                    contactLink(icon: "envelope.fill", urlString: "mailto:\(submission.contactEmail)")
                }
            }
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }

    private func contactLink(icon: String, urlString: String) -> some View {
        Link(destination: URL(string: urlString)!) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(WKCCColors.primary)
                .frame(width: 36, height: 36)
                .background(WKCCColors.primary.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private var memberPreviewSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack {
                Text("Member Preview")
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)

                Spacer()

                Text("Deals tab")
                    .font(WKCCTypography.captionBold)
                    .foregroundStyle(WKCCColors.accent)
            }

            DealCard(deal: dealPreview)
        }
    }

    private var detailDisclosures: some View {
        VStack(spacing: WKCCSpacing.sm) {
            ForEach(ReviewDetailSection.allCases) { section in
                ReviewDisclosureRow(
                    section: section,
                    isExpanded: expandedSections.contains(section),
                    submission: submission
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        if expandedSections.contains(section) {
                            expandedSections.remove(section)
                        } else {
                            expandedSections.insert(section)
                        }
                    }
                }
            }
        }
    }

    private var adminNotesBlock: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Admin Notes")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            TextField("Internal notes for the review team", text: $adminNotes, axis: .vertical)
                .font(WKCCTypography.body)
                .lineLimit(3...6)
                .padding(WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.lg)
                        .stroke(WKCCColors.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private var stickyActionBar: some View {
        HStack(spacing: WKCCSpacing.sm) {
            Button {
                showRejectConfirm = true
            } label: {
                Text("Deny")
                    .font(WKCCTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WKCCSpacing.md)
                    .background(WKCCColors.cardBackground)
                    .foregroundStyle(WKCCColors.error)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: WKCCRadius.md)
                            .stroke(WKCCColors.error.opacity(0.25), lineWidth: 1)
                    )
            }

            Button {
                showApproveConfirm = true
            } label: {
                Text("Approve")
                    .font(WKCCTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WKCCSpacing.md)
                    .background(WKCCColors.accent)
                    .foregroundStyle(WKCCColors.textOnPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
            }

            Button {} label: {
                Image(systemName: "pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(WKCCColors.primary)
                    .frame(width: 52, height: 52)
                    .background(WKCCColors.cardBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(WKCCColors.primary.opacity(0.15), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.vertical, WKCCSpacing.sm)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Concept B: Review Brief

/// Status timeline, bento fact tiles, prose blocks, segmented bottom actions.
struct AdminSubmissionReviewConceptB: View {
    let record: PromotionSubmissionRecord

    @State private var adminNotes = ""
    @State private var selectedAction: ReviewAction = .none

    private var submission: PromotionSubmission { record.submission }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.xl) {
                statusTimeline
                promotionHeadline
                factBentoGrid
                editorialDetailStack
                submitterStrip

                EditorialHairlineDivider()
                    .padding(.top, WKCCSpacing.sm)

                adminNotesEditor
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.top, WKCCSpacing.md)
            .padding(.bottom, WKCCSpacing.xxl + 80)
        }
        .wkccPageBackground()
        .navigationTitle("Review Submission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if record.status == .pending {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {}
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.accent)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if record.status == .pending {
                segmentedActionBar
            }
        }
        .onAppear {
            adminNotes = record.adminNotes ?? ""
        }
    }

    private var statusTimeline: some View {
        HStack(spacing: 0) {
            ForEach(Array(ReviewTimelineStep.allCases.enumerated()), id: \.element.id) { index, step in
                ReviewTimelineNode(
                    step: step,
                    state: step.state(for: record)
                )

                if index < ReviewTimelineStep.allCases.count - 1 {
                    ReviewTimelineConnector(
                        isSegmentComplete: step.state(for: record) == .complete
                    )
                }
            }
        }
        .padding(.vertical, WKCCSpacing.md)
    }

    private var promotionHeadline: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack {
                SubmissionStatusBadge(status: record.status)
                Spacer()
                
            }
            
            Text(submission.title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(WKCCColors.textPrimary)
            
            HStack {
                Text(record.companyName)
                    .font(WKCCTypography.callout.weight(.semibold))
                    .foregroundStyle(WKCCColors.primary)
                Label(submission.category.rawValue, systemImage: submission.category.iconName)
                    .font(WKCCTypography.captionBold)
                    .foregroundStyle(WKCCColors.textSecondary)
            }
        }
    }

    private var factBentoGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: WKCCSpacing.sm),
                GridItem(.flexible(), spacing: WKCCSpacing.sm)
            ],
            spacing: WKCCSpacing.sm
        ) {
            ReviewFactTile(
                icon: "calendar",
                label: "Starts",
                value: submission.startDate.formatted(date: .abbreviated, time: .omitted),
                tint: WKCCColors.primary
            )
            ReviewFactTile(
                icon: "calendar.badge.clock",
                label: "Ends",
                value: submission.endDate.formatted(date: .abbreviated, time: .omitted),
                tint: WKCCColors.primary
            )
            ReviewFactTile(
                icon: "person.fill",
                label: "Member",
                value: record.submitterName,
                tint: WKCCColors.primary
            )
            ReviewFactTile(
                icon: "ticket.fill",
                label: "Code",
                value: submission.redemptionCodeType == .none
                    ? "None"
                    : (submission.redemptionCode.isEmpty ? submission.redemptionCodeType.rawValue : submission.redemptionCode),
                tint: WKCCColors.primary
            )
        }
    }

    private var editorialDetailStack: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xl) {
            EditorialDetailSection(
                title: "About this perk",
                content: submission.shortDescription,
                collapsedLineLimit: 3
            )

            EditorialHairlineDivider()

            EditorialDetailSection(
                title: "Full description",
                content: submission.fullDescription,
                collapsedLineLimit: 5
            )

            if !submission.terms.isEmpty {
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
                content: submission.redemptionInstructions,
                footnote: submission.redemptionCodeType.requiresCodeValue && !submission.redemptionCode.isEmpty
                    ? "Code: \(submission.redemptionCode)"
                    : nil,
                collapsedLineLimit: 4
            )
        }
    }

    private var submitterStrip: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            EditorialHairlineDivider()

            Text("Submitted by")
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(WKCCColors.textPrimary)

            HStack(spacing: WKCCSpacing.md) {
                MemberInitialsAvatar(name: record.submitterName, size: 48)

                VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                    Text(record.submitterName)
                        .font(WKCCTypography.body.weight(.medium))
                        .foregroundStyle(WKCCColors.textPrimary)

                    Text(record.companyName)
                        .font(WKCCTypography.callout)
                        .foregroundStyle(WKCCColors.textSecondary)

                    Text(record.submittedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(WKCCTypography.caption)
                        .foregroundStyle(WKCCColors.textSecondary.opacity(0.8))
                }

                Spacer(minLength: 0)
            }

            if !submission.contactPhone.isEmpty || !submission.contactEmail.isEmpty {
                VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                    if !submission.contactPhone.isEmpty {
                        Text(submission.contactPhone)
                    }
                    if !submission.contactEmail.isEmpty {
                        Text(submission.contactEmail)
                    }
                }
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
            }
        }
    }

    private var adminNotesEditor: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text("Admin notes")
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(WKCCColors.textPrimary)

            TextEditor(text: $adminNotes)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary.opacity(0.82))
                .lineSpacing(4)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var segmentedActionBar: some View {
        VStack(spacing: WKCCSpacing.sm) {
            Picker("Review action", selection: $selectedAction) {
                Text("Review").tag(ReviewAction.none)
                Text("Deny").tag(ReviewAction.deny)
                Text("Approve").tag(ReviewAction.approve)
            }
            .pickerStyle(.segmented)
            .tint(WKCCColors.accent)

            if selectedAction != .none {
                Button {
                    selectedAction = .none
                } label: {
                    Text(selectedAction == .approve ? "Confirm Approval" : "Confirm Denial")
                        .font(WKCCTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, WKCCSpacing.md)
                        .background(selectedAction == .approve ? WKCCColors.accent : WKCCColors.error)
                        .foregroundStyle(WKCCColors.textOnPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.vertical, WKCCSpacing.sm)
        .background(.ultraThinMaterial)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedAction)
    }
}

// MARK: - Shared Components

private enum ReviewDetailSection: String, CaseIterable, Identifiable {
    case promotion = "Promotion"
    case redemption = "Redemption"
    case contact = "Contact"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .promotion: "tag.fill"
        case .redemption: "qrcode"
        case .contact: "person.crop.circle"
        }
    }
}

private enum ReviewTimelineStepState {
    case complete
    case active
    case upcoming
}

private enum ReviewTimelineStep: CaseIterable, Identifiable {
    case submitted
    case pending
    case decision

    var id: Self { self }

    var title: String {
        switch self {
        case .submitted: "Submitted"
        case .pending: "In Review"
        case .decision: "Decision"
        }
    }

    func state(for record: PromotionSubmissionRecord) -> ReviewTimelineStepState {
        switch self {
        case .submitted:
            return .complete
        case .pending:
            if record.status == .pending { return .active }
            return .complete
        case .decision:
            if record.reviewedAt != nil { return .complete }
            return .upcoming
        }
    }
}

private enum ReviewAction {
    case none
    case deny
    case approve
}

private struct MemberInitialsAvatar: View {
    let name: String
    var size: CGFloat = 48

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(WKCCColors.primary)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [WKCCColors.accent.opacity(0.28), WKCCColors.accent.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
    }
}

private struct PromotionDateRangeChip: View {
    let start: Date
    let end: Date

    var body: some View {
        HStack(spacing: WKCCSpacing.xxs) {
            Image(systemName: "calendar")
            Text("\(start.formatted(.dateTime.month(.abbreviated).day())) - \(end.formatted(.dateTime.month(.abbreviated).day()))")
        }
        .padding(.horizontal, WKCCSpacing.sm)
        .padding(.vertical, WKCCSpacing.xxs)
        .background(WKCCColors.textOnPrimary.opacity(0.16))
        .clipShape(Capsule())
    }
}

private struct ReviewDisclosureRow: View {
    let section: ReviewDetailSection
    let isExpanded: Bool
    let submission: PromotionSubmission
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: WKCCSpacing.sm) {
                    Image(systemName: section.icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.primary)
                        .frame(width: 28)

                    Text(section.rawValue)
                        .font(WKCCTypography.headline)
                        .foregroundStyle(WKCCColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WKCCColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(WKCCSpacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                    Divider()
                        .padding(.horizontal, WKCCSpacing.md)

                    Group {
                        switch section {
                        case .promotion:
                            detailLine("Category", submission.category.rawValue)
                            detailLine("Summary", submission.shortDescription)
                            detailLine("Description", submission.fullDescription)
                            if !submission.terms.isEmpty {
                                detailLine("Terms", submission.terms)
                            }
                        case .redemption:
                            detailLine("Instructions", submission.redemptionInstructions)
                            detailLine("Code Type", submission.redemptionCodeType.rawValue)
                            if submission.redemptionCodeType.requiresCodeValue {
                                detailLine(
                                    submission.redemptionCodeType.codeFieldLabel,
                                    submission.redemptionCode
                                )
                            }
                        case .contact:
                            detailLine("Email", submission.contactEmail)
                            detailLine("Phone", submission.contactPhone)
                        }
                    }
                    .padding(.horizontal, WKCCSpacing.md)
                    .padding(.bottom, WKCCSpacing.md)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.lg)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
            Text(label)
                .font(WKCCTypography.captionBold)
                .foregroundStyle(WKCCColors.textSecondary)
            Text(value.isEmpty ? "Not provided" : value)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReviewTimelineNode: View {
    let step: ReviewTimelineStep
    let state: ReviewTimelineStepState

    private let nodeSize: CGFloat = 28
    private let progressColor = WKCCColors.accent

    var body: some View {
        VStack(spacing: WKCCSpacing.xs) {
            ZStack {
                switch state {
                case .complete:
                    Circle()
                        .fill(progressColor)
                        .frame(width: nodeSize, height: nodeSize)

                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WKCCColors.textOnPrimary)

                case .active:
                    Circle()
                        .fill(WKCCColors.cardBackground)
                        .frame(width: nodeSize, height: nodeSize)

                    Circle()
                        .stroke(progressColor, lineWidth: 2)
                        .frame(width: nodeSize, height: nodeSize)

                    Circle()
                        .fill(progressColor)
                        .frame(width: 10, height: 10)

                case .upcoming:
                    Circle()
                        .fill(progressColor.opacity(0.1))
                        .frame(width: nodeSize, height: nodeSize)

                    Circle()
                        .stroke(progressColor.opacity(0.18), lineWidth: 1.5)
                        .frame(width: nodeSize, height: nodeSize)
                }
            }

            Text(step.title)
                .font(WKCCTypography.caption.weight(state == .active ? .semibold : .regular))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var labelColor: Color {
        switch state {
        case .complete: WKCCColors.textSecondary
        case .active: WKCCColors.accent
        case .upcoming: WKCCColors.textSecondary.opacity(0.45)
        }
    }
}

private struct ReviewTimelineConnector: View {
    let isSegmentComplete: Bool

    var body: some View {
        Rectangle()
            .fill(
                isSegmentComplete
                    ? WKCCColors.accent
                    : WKCCColors.accent.opacity(0.12)
            )
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)
    }
}

// MARK: - Previews

#Preview("Concept Gallery") {
    AdminSubmissionReviewConceptsGallery()
}

#Preview("Concept A - Pending") {
    NavigationStack {
        AdminSubmissionReviewConceptA(record: MockData.seedPromotionSubmissions[0])
    }
}

#Preview("Concept A - Approved") {
    NavigationStack {
        AdminSubmissionReviewConceptA(record: MockData.seedPromotionSubmissions[2])
    }
}

#Preview("Concept B - Pending") {
    NavigationStack {
        AdminSubmissionReviewConceptB(record: MockData.seedPromotionSubmissions[1])
    }
}

#Preview("Concept B - Approved") {
    NavigationStack {
        AdminSubmissionReviewConceptB(record: MockData.seedPromotionSubmissions[2])
    }
}
