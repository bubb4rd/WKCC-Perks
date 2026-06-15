import SwiftUI

struct BusinessesListView: View {
    @State private var viewModel = BusinessesListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.businesses.isEmpty {
                LoadingView(message: "Loading businesses...")
            } else if viewModel.filteredBusinesses.isEmpty {
                EmptyStateView(
                    icon: "building.2",
                    title: "No Businesses Found",
                    message: "Try adjusting your search or category filter."
                )
            } else {
                businessList
            }
        }
        .navigationTitle("Businesses")
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $viewModel.searchText, prompt: "Search businesses")
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .navigationDestination(for: ChamberBusiness.self) { business in
            BusinessDetailView(businessId: business.id)
        }
    }

    private var businessList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                categoryBar

                ForEach(viewModel.filteredBusinesses) { business in
                    NavigationLink(value: business) {
                        BusinessCard(business: business)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WKCCSpacing.xs) {
                Button {
                    viewModel.selectedCategory = nil
                } label: {
                    Text("All")
                        .font(WKCCTypography.captionBold)
                        .padding(.horizontal, WKCCSpacing.sm)
                        .padding(.vertical, WKCCSpacing.xs)
                        .background(viewModel.selectedCategory == nil ? WKCCColors.primary : WKCCColors.cardBackground)
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
        BusinessesListView()
    }
}
