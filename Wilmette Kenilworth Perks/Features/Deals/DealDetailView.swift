import CoreImage.CIFilterBuiltins
import SwiftUI

struct DealDetailView: View {
    let dealId: String

    @State private var viewModel = DealDetailViewModel()
    @State private var didCopyCode = false
    @State private var isShowingRedemption = false
    @State private var isShowingReportProblem = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.deal == nil {
                LoadingView(message: "Loading deal...")
            } else if let deal = viewModel.deal {
                dealContent(deal)
            } else {
                EmptyStateView(
                    icon: "tag.slash",
                    title: "Deal Not Found",
                    message: viewModel.errorMessage ?? "This deal may have expired or been removed."
                )
            }
        }
        .navigationTitle("Perk Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.load(dealId: dealId)
        }
    }

    private func dealContent(_ deal: DealDetail) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WKCCSpacing.xl) {
                DealDetailHeroImage(imageURL: viewModel.heroImageURL)
                editorialHeader(deal)
                detailSections(deal)
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.top, WKCCSpacing.lg)
            .padding(.bottom, WKCCSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .wkccPageBackground()
        .safeAreaInset(edge: .bottom) {
            redeemStickyBar(deal: deal)
        }
        .sheet(isPresented: $isShowingRedemption) {
            DealRedemptionSheet(deal: deal, didCopyCode: $didCopyCode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingReportProblem) {
            DealReportProblemSheet(deal: deal)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func editorialHeader(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {

            Text(deal.title)
                .font(.system(.title, design: .default).weight(.bold))
                .foregroundStyle(Color.black)
                .fixedSize(horizontal: false, vertical: true)
            DealDetailMetadataGrid(deal: deal)
            
            NavigationLink {
                BusinessDetailView(businessId: deal.businessId)
            } label: {
                HStack(spacing: WKCCSpacing.xs) {
                    
                    VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                        Text(deal.businessName)
                            .font(WKCCTypography.title)
                            .foregroundStyle(WKCCColors.textPrimary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WKCCColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            
        }
    }

    private func redeemStickyBar(deal: DealDetail) -> some View {
        HStack(spacing: WKCCSpacing.sm) {
            Button {
                isShowingRedemption = true
            } label: {
                Text(deal.isExpired ? "Expired" : "Redeem")
                    .font(WKCCTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WKCCSpacing.md)
                    .background(deal.isExpired ? WKCCColors.primary.opacity(0.35) : WKCCColors.primary)
                    .foregroundStyle(WKCCColors.textOnPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
            }
            .disabled(deal.isExpired)

            Button {
                isShowingReportProblem = true
            } label: {
                Image(systemName: "exclamationmark")
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
            .accessibilityLabel("Report a problem with this perk")
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.vertical, WKCCSpacing.sm)
        .background(WKCCColors.pageBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func detailSections(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xl) {
            editorialSection(title: "About this perk") {
                Text(deal.description)
                    .font(WKCCTypography.body)
                    .foregroundStyle(Color.black.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let terms = deal.terms, !terms.isEmpty {
                DealEditorialDivider()
                editorialSection(title: "Terms and exclusions") {
                    Text(terms)
                        .font(WKCCTypography.callout)
                        .foregroundStyle(Color.black.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func editorialSection<Content: View>(
        title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            if let icon {
                Label(title, systemImage: icon)
                    .font(WKCCTypography.headline)
                    .foregroundStyle(Color.black)
            } else {
                Text(title)
                    .font(WKCCTypography.headline)
                    .foregroundStyle(Color.black)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hero

private struct DealDetailHeroImage: View {
    let imageURL: URL?

    private let heroHeight: CGFloat = 320
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
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                case .failure, .empty:
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
        Image("PerkPlaceholder")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
    }
}

// MARK: - Metadata

private struct DealDetailMetadataGrid: View {
    let deal: DealDetail

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            metadataItem(
                icon: "calendar",
                value: availabilityText
            )

            metadataItem(
                icon: "qrcode",
                value: deal.redemptionDisplayStyle.label
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var availabilityText: String {
        let start = deal.startDate?.formatted(.dateTime.month(.abbreviated).day())
        let end = deal.expirationDate?.formatted(.dateTime.month(.abbreviated).day())

        switch (start, end) {
        case let (start?, end?):
            return "\(start) - \(end)"
        case let (start?, nil):
            return "From \(start)"
        case let (nil, end?):
            return "Through \(end)"
        default:
            return "Ongoing"
        }
    }

    private func metadataItem(
        icon: String,
        value: String,
        valueColor: Color = Color.black
    ) -> some View {
        HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.black)
                .frame(width: 26, alignment: .center)

            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(valueColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Redemption Sheets

struct DealRedemptionSheet: View {
    let deal: DealDetail
    @Binding var didCopyCode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                    VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                        Text("Instructions")
                            .font(WKCCTypography.headline)
                            .foregroundStyle(Color.black)

                        Text(deal.redemptionInstructions)
                            .font(WKCCTypography.body)
                            .foregroundStyle(Color.black.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    DealRedemptionPassport(
                        deal: deal,
                        didCopyCode: $didCopyCode
                    )
                }
                .padding(WKCCSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .wkccPageBackground()
            .navigationTitle("Redeem Perk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct DealReportProblemSheet: View {
    let deal: DealDetail
    @Environment(\.dismiss) private var dismiss

    @State private var reportDetails = ""
    @State private var didSubmit = false

    private var canSubmit: Bool {
        !reportDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                    faqSection
                    reportSection
                }
                .padding(WKCCSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .wkccPageBackground()
            .navigationTitle("Report a Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Report sent", isPresented: $didSubmit) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thanks — the chamber will look into this perk.")
            }
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text("Quick checks")
                .font(WKCCTypography.headline)
                .foregroundStyle(Color.black)

            faqItem(
                question: "Code won’t scan or isn’t accepted",
                answer: "Ask staff to enter the code manually, or try refreshing the Redeem screen. Make sure your screen brightness is high enough for scanners."
            )

            faqItem(
                question: "Business says the perk isn’t valid",
                answer: "Confirm the perk dates and terms above. If it should still be active, report it below so the chamber can follow up."
            )

            faqItem(
                question: "Wrong business or incorrect offer",
                answer: "Describe what’s wrong in the report field. Include what you expected to see versus what appeared."
            )
        }
    }

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            Text(question)
                .font(WKCCTypography.callout.weight(.semibold))
                .foregroundStyle(WKCCColors.textPrimary)

            Text(answer)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Describe the issue")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text("Tell us what’s wrong with this perk or redemption code.")
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)

            TextEditor(text: $reportDetails)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)
                .frame(minHeight: 120)
                .padding(WKCCSpacing.sm)
                .scrollContentBackground(.hidden)
                .background(WKCCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                )

            WKCCPrimaryButton(title: "Submit Report", isLoading: false) {
                submitReport()
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.55)
        }
    }

    private func submitReport() {
        let trimmed = reportDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let subject = "Perk problem: \(deal.title)"
        let body = """
        Perk: \(deal.title)
        Business: \(deal.businessName)
        Perk ID: \(deal.id)

        Issue:
        \(trimmed)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            UIApplication.shared.open(url)
        }

        didSubmit = true
    }
}

// MARK: - Redemption Passport

private struct DealRedemptionPassport: View {
    let deal: DealDetail
    @Binding var didCopyCode: Bool

    var body: some View {
        VStack(spacing: WKCCSpacing.lg) {
            redemptionVisual

            if let shareItem = deal.redemptionShareItem {
                HStack(spacing: WKCCSpacing.sm) {
                    Button {
                        UIPasteboard.general.string = shareItem
                        didCopyCode = true
                    } label: {
                        Label(didCopyCode ? "Copied" : "Copy", systemImage: didCopyCode ? "checkmark" : "doc.on.doc")
                            .font(WKCCTypography.callout.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WKCCSpacing.sm)
                    }
                    .buttonStyle(.bordered)
                    .tint(WKCCColors.primary)

                    ShareLink(item: shareItem) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(WKCCTypography.callout.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WKCCSpacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WKCCColors.primary)
                }
            }
        }
        .padding(WKCCSpacing.lg)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
    }

    @ViewBuilder
    private var redemptionVisual: some View {
        switch deal.redemptionDisplayStyle {
        case .showScreen:
            VStack(spacing: WKCCSpacing.md) {
                DealQRCodeView(content: "wkcc-perk:\(deal.id)")
                    .frame(width: 168, height: 168)
                    .padding(WKCCSpacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
            }
            .frame(maxWidth: .infinity)

        case .promoCode(let code):
            VStack(spacing: WKCCSpacing.sm) {
                Text("Promo code")
                    .font(WKCCTypography.captionBold)
                    .foregroundStyle(WKCCColors.textSecondary)

                Text(code)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(WKCCColors.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, WKCCSpacing.md)

                Text("Enter or mention this code at checkout.")
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

        case .barcode(let code):
            VStack(spacing: WKCCSpacing.md) {
                DealBarcodeView(content: code)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .padding(.horizontal, WKCCSpacing.md)
                    .padding(.vertical, WKCCSpacing.sm)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))

                Text(code)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(WKCCColors.primary)

                Text("Scan or enter this barcode when redeeming.")
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

        case .qrCode(let code):
            VStack(spacing: WKCCSpacing.md) {
                DealQRCodeView(content: code)
                    .frame(width: 184, height: 184)
                    .padding(WKCCSpacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))

                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(WKCCColors.primary)
                    .multilineTextAlignment(.center)

                Text("Scan this code to redeem.")
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        Text("\(deal.title)")
            .font(WKCCTypography.title)
            .foregroundStyle(WKCCColors.primary)
        Text("\(deal.businessName)")
            .font(WKCCTypography.callout)
            .foregroundStyle(WKCCColors.primary)
    }
}

// MARK: - Code Rendering

private struct DealBarcodeView: View {
    let content: String

    var body: some View {
        if let image = generateBarcode(from: content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "barcode")
                .font(.system(size: 48))
                .foregroundStyle(WKCCColors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func generateBarcode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct DealQRCodeView: View {
    let content: String

    var body: some View {
        if let image = generateQRCode(from: content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(WKCCColors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct DealEditorialDivider: View {
    var body: some View {
        Rectangle()
            .fill(WKCCColors.primary.opacity(0.08))
            .frame(height: 1)
    }
}

// MARK: - Redemption Helpers

private enum DealRedemptionDisplayStyle {
    case showScreen
    case promoCode(String)
    case barcode(String)
    case qrCode(String)

    var label: String {
        switch self {
        case .showScreen: "Show screen"
        case .promoCode: "Promo code"
        case .barcode: "Barcode"
        case .qrCode: "QR code"
        }
    }

    var iconName: String {
        switch self {
        case .showScreen: "iphone"
        case .promoCode: "textformat.abc"
        case .barcode: "barcode"
        case .qrCode: "qrcode"
        }
    }
}

private extension DealDetail {
    var redemptionDisplayStyle: DealRedemptionDisplayStyle {
        guard let code = redemptionCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return .showScreen
        }

        if code.hasPrefix("http://") || code.hasPrefix("https://") {
            return .qrCode(code)
        }

        if code.allSatisfy(\.isNumber), code.count >= 8 {
            return .barcode(code)
        }

        return .promoCode(code)
    }

    var redemptionShareItem: String? {
        switch redemptionDisplayStyle {
        case .showScreen:
            return nil
        case .promoCode(let code), .barcode(let code), .qrCode(let code):
            return code
        }
    }
}

#Preview("Featured") {
    NavigationStack {
        DealDetailView(dealId: "deal-001")
    }
}

#Preview("Ending Soon") {
    NavigationStack {
        DealDetailView(dealId: "deal-004")
    }
}

#Preview("Expired") {
    NavigationStack {
        DealDetailView(dealId: "deal-expired")
    }
}

#Preview("Promo Code") {
    NavigationStack {
        DealDetailView(dealId: "deal-007")
    }
}
