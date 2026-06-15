import SwiftUI

struct DealsListView: View {
    var initialCategory: DealCategory? = nil
    var initialFilter: DealFilter? = nil

    @State private var viewModel = DealsListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.deals.isEmpty {
                LoadingView(message: "Loading deals...")
            } else if viewModel.filteredDeals.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "No Deals Found",
                    message: "Try adjusting your search or filters."
                )
            } else {
                dealsList
            }
        }
        .navigationTitle("Deals")
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $viewModel.searchText, prompt: "Search deals or businesses")
        .refreshable {
            await viewModel.load()
        }
        .task {
            viewModel.applyInitialCategory(initialCategory)
            if let initialFilter {
                viewModel.applyInitialFilter(initialFilter)
            }
            await viewModel.load()
        }
        .navigationDestination(for: DealSummary.self) { deal in
            DealDetailView(dealId: deal.id)
        }
    }

    private var dealsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                filterBar
                categoryBar

                ForEach(viewModel.filteredDeals) { deal in
                    NavigationLink(value: deal) {
                        DealCard(deal: deal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WKCCSpacing.xs) {
                ForEach(DealFilter.allCases) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(WKCCTypography.captionBold)
                            .padding(.horizontal, WKCCSpacing.sm)
                            .padding(.vertical, WKCCSpacing.xs)
                            .background(viewModel.selectedFilter == filter ? WKCCColors.primary : WKCCColors.cardBackground)
                            .foregroundStyle(viewModel.selectedFilter == filter ? WKCCColors.textOnPrimary : WKCCColors.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(WKCCColors.primary.opacity(viewModel.selectedFilter == filter ? 0 : 0.15), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WKCCSpacing.xs) {
                Button {
                    viewModel.selectedCategory = nil
                } label: {
                    Text("All Categories")
                        .font(WKCCTypography.captionBold)
                        .padding(.horizontal, WKCCSpacing.sm)
                        .padding(.vertical, WKCCSpacing.xs)
                        .background(viewModel.selectedCategory == nil ? WKCCColors.accent : WKCCColors.cardBackground)
                        .foregroundStyle(viewModel.selectedCategory == nil ? WKCCColors.textOnPrimary : WKCCColors.textPrimary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(WKCCColors.primary.opacity(viewModel.selectedCategory == nil ? 0 : 0.15), lineWidth: 1)
                        )
                }

                ForEach(DealCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DealsListView()
    }
}
