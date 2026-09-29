import SwiftUI

enum BusinessesListLayout: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        }
    }

    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

struct BusinessesListView: View {
    @State private var viewModel = BusinessesListViewModel()
    @State private var isFilterSheetPresented = false
    @AppStorage("businessesListLayout") private var layout: BusinessesListLayout = .list

    private let gridColumns = [
        GridItem(.flexible(), spacing: WKCCSpacing.md, alignment: .top),
        GridItem(.flexible(), spacing: WKCCSpacing.md, alignment: .top)
    ]

    private var hasActiveFilters: Bool {
        viewModel.selectedCategory != nil
    }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Layout", selection: $layout) {
                        ForEach(BusinessesListLayout.allCases) { option in
                            Label(option.title, systemImage: option.iconName)
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: layout.iconName)
                }
                .accessibilityLabel("Layout")
                .accessibilityValue(layout.title)
            }
            ToolbarItem(placement: .topBarTrailing) {
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
            ListFilterSheet(selectedCategory: $viewModel.selectedCategory)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search businesses")
        .refreshable {
            await viewModel.load()
        }
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .businessLogoDidChange)) { _ in
            Task { await viewModel.load() }
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

                switch layout {
                case .list:
                    LazyVStack(alignment: .leading, spacing: WKCCSpacing.md) {
                        ForEach(viewModel.filteredBusinesses) { business in
                            NavigationLink(value: business) {
                                BusinessCard(business: business)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .grid:
                    LazyVGrid(columns: gridColumns, spacing: WKCCSpacing.md) {
                        ForEach(viewModel.filteredBusinesses) { business in
                            NavigationLink(value: business) {
                                BusinessGridCard(business: business)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
    }
}

#Preview {
    NavigationStack {
        BusinessesListView()
    }
}
