import SwiftUI

struct DealsSearchView: View {
    @State private var viewModel = DealsSearchViewModel()
    @State private var isFilterSheetPresented = false
    @State private var hasCommittedSearch = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, WKCCSpacing.md)
                .padding(.top, WKCCSpacing.sm)
                .padding(.bottom, WKCCSpacing.md)

            content
        }
        .wkccPageBackground()
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFilterSheetPresented = true
                } label: {
                    Image(systemName: viewModel.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filters")
            }
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            ListFilterSheet(
                selectedCategory: $viewModel.selectedCategory,
                selectedFilter: $viewModel.selectedFilter
            )
        }
        .navigationDestination(for: DealSummary.self) { deal in
            DealDetailView(dealId: deal.id)
        }
        .task {
            await viewModel.load()
            isSearchFocused = true
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                hasCommittedSearch = false
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: WKCCSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WKCCColors.textSecondary)

            TextField("Search deals or businesses", text: $viewModel.searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    commitAndShowResults()
                }

            if viewModel.hasQuery {
                Button {
                    viewModel.clearSearchText()
                    hasCommittedSearch = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WKCCColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.vertical, WKCCSpacing.sm)
        .background(WKCCColors.primary.opacity(0.06))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.deals.isEmpty {
            LoadingView(message: "Loading deals...")
        } else if !viewModel.hasQuery {
            recentSearchesContent
        } else if hasCommittedSearch || viewModel.suggestions.isEmpty {
            resultsContent
        } else {
            suggestionsContent
        }
    }

    private var recentSearchesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                if viewModel.recentSearches.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Search Perks",
                        message: "Find deals by title or business name. You can also apply filters."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, WKCCSpacing.xl)
                } else {
                    HStack {
                        Text("Recent searches")
                            .font(WKCCTypography.headline)
                            .foregroundStyle(WKCCColors.textPrimary)

                        Spacer()

                        Button("Clear all") {
                            viewModel.clearRecentSearches()
                        }
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.accent)
                    }

                    recentSearchChips
                }
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.bottom, WKCCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recentSearchChips: some View {
        FlexibleChipRow(spacing: WKCCSpacing.xs) {
            ForEach(viewModel.recentSearches, id: \.self) { recent in
                Button {
                    viewModel.selectRecent(recent)
                    hasCommittedSearch = true
                } label: {
                    Text(recent)
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, WKCCSpacing.sm)
                        .padding(.vertical, WKCCSpacing.xs)
                        .background(WKCCColors.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.selectSuggestion(suggestion)
                        hasCommittedSearch = true
                    } label: {
                        suggestionLabel(suggestion)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, WKCCSpacing.md)
                            .padding(.vertical, WKCCSpacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(WKCCColors.primary.opacity(0.08))
                        .padding(.leading, WKCCSpacing.md)
                }
            }
            .background(WKCCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: WKCCRadius.lg)
                    .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, WKCCSpacing.md)
        }
    }

    private func suggestionLabel(_ suggestion: String) -> Text {
        let query = viewModel.trimmedQuery
        if let range = suggestion.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            let matched = String(suggestion[range])
            let suffix = String(suggestion[range.upperBound...])
            return Text(matched)
                .foregroundStyle(WKCCColors.textSecondary)
            + Text(suffix)
                .fontWeight(.semibold)
                .foregroundStyle(WKCCColors.textPrimary)
        }

        return Text(suggestion)
            .fontWeight(.semibold)
            .foregroundStyle(WKCCColors.textPrimary)
    }

    private var resultsContent: some View {
        Group {
            if viewModel.filteredDeals.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "Try a different search or adjust your filters."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: WKCCSpacing.md) {
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error) {
                                viewModel.dismissError()
                            }
                        }

                        ForEach(viewModel.filteredDeals) { deal in
                            DealCard(deal: deal)
                        }
                    }
                    .padding(.horizontal, WKCCSpacing.md)
                    .padding(.bottom, WKCCSpacing.md)
                }
            }
        }
    }

    private func commitAndShowResults() {
        viewModel.commitSearch()
        hasCommittedSearch = true
        isSearchFocused = false
    }
}

/// Wrapping chip row that sizes each chip to its content (no column squishing).
private struct FlexibleChipRow<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        RecentSearchFlowLayout(spacing: spacing) {
            content
        }
    }
}

private struct RecentSearchFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
        }

        let height = frames.isEmpty ? 0 : y + rowHeight
        let width = maxWidth.isFinite ? maxWidth : usedWidth
        return (CGSize(width: width, height: height), frames)
    }
}

#Preview {
    NavigationStack {
        DealsSearchView()
    }
}
