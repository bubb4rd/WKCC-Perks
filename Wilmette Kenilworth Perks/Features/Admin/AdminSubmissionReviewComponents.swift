import SwiftUI

// MARK: - Bento

struct ReviewFactTile: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = WKCCColors.primary

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)

                Text(value)
                    .font(WKCCTypography.callout.weight(.semibold))
                    .foregroundStyle(WKCCColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.lg)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Editorial Sections

struct EditorialHairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(WKCCColors.primary.opacity(0.1))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

struct EditorialDetailSection: View {
    let title: String
    let content: String
    var footnote: String? = nil
    var collapsedLineLimit: Int = 4

    @State private var isExpanded = false

    private var needsTruncation: Bool {
        content.count > collapsedLineLimit * 42
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text(title)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(WKCCColors.textPrimary)

            Text(content)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary.opacity(0.82))
                .lineSpacing(5)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)

            if let footnote {
                Text(footnote)
                    .font(WKCCTypography.callout.weight(.medium))
                    .foregroundStyle(WKCCColors.textPrimary)
                    .padding(.top, WKCCSpacing.xxs)
            }

            if needsTruncation {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.textPrimary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EditorialListSection: View {
    let title: String
    let items: [String]
    var collapsedVisibleCount: Int = 3

    @State private var isExpanded = false

    private var visibleItems: [String] {
        isExpanded ? items : Array(items.prefix(collapsedVisibleCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text(title)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(WKCCColors.textPrimary)

            VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                ForEach(visibleItems, id: \.self) { item in
                    Text(item)
                        .font(WKCCTypography.body)
                        .foregroundStyle(WKCCColors.textPrimary.opacity(0.82))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if items.count > collapsedVisibleCount {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.textPrimary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension PromotionSubmission {
    var termsListItems: [String] {
        terms
            .split(whereSeparator: { $0 == "." || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { sentence in
                sentence.hasSuffix(".") ? sentence : "\(sentence)."
            }
    }
}
