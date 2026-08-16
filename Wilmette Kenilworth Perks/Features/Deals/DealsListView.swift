import SwiftUI

struct DealsListView: View {
    var initialCategory: DealCategory? = nil
    var initialFilter: DealFilter? = nil

    @State private var viewModel = DealsListViewModel()
    @State private var isFilterSheetPresented = false

    private var hasActiveFilters: Bool {
        viewModel.selectedFilter != .all || viewModel.selectedCategory != nil
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.deals.isEmpty {
                LoadingView(message: "Loading deals...")
            } else if viewModel.filteredDeals.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "No Deals Found",
                    message: "Try adjusting your filters."
                )
            } else {
                dealsList
            }
        }
        .navigationTitle("Deals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    DealsSearchView()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search deals")

                Button {
                    isFilterSheetPresented = true
                } label: {
                    Image(systemName: hasActiveFilters
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
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                ForEach(viewModel.filteredDeals) { deal in
                    DealCard(
                        deal: deal,
                        businessLogoURL: viewModel.logoURL(for: deal.businessId)
                    )
                }
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.vertical, WKCCSpacing.md)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .wkccPageBackground()
    }
}

#Preview {
    NavigationStack {
        DealsListView()
    }
}
