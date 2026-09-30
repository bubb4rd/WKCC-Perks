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
    /// Category chosen elsewhere (Home chips); applied once, then cleared.
    @Binding var requestedCategory: DealCategory?

    init(requestedCategory: Binding<DealCategory?> = .constant(nil)) {
        _requestedCategory = requestedCategory
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: WKCCSpacing.md, alignment: .top),
        GridItem(.flexible(), spacing: WKCCSpacing.md, alignment: .top)
    ]

    private var hasActiveFilters: Bool {
        viewModel.selectedCategory != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            categoryBar

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Scoped to the list so the horizontal chip ScrollView doesn't pick up pull-to-refresh.
            .refreshable {
                // SwiftUI cancels the refresh task if the view updates mid-pull; run the
                // load in its own task so the request finishes and the spinner still waits on it.
                await Task { await viewModel.load() }.value
            }
        }
        .wkccPageBackground()
        // Title stays set so pushed screens get a "Businesses" back button; the bar itself is hidden.
        .navigationTitle("Businesses")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isFilterSheetPresented) {
            ListFilterSheet(selectedCategory: $viewModel.selectedCategory)
        }
        .task {
            await viewModel.load()
        }
        // `initial` covers the first visit, when this tab is built after the request is set.
        .onChange(of: requestedCategory, initial: true) { _, category in
            guard let category else { return }
            viewModel.searchText = ""
            viewModel.selectedCategory = category
            requestedCategory = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .businessLogoDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .navigationDestination(for: ChamberBusiness.self) { business in
            BusinessDetailView(businessId: business.id)
        }
    }

    private var headerBar: some View {
        HStack(spacing: WKCCSpacing.xs) {
            WKCCSearchField(prompt: "Search businesses", text: $viewModel.searchText)

            Menu {
                Picker("Layout", selection: $layout) {
                    ForEach(BusinessesListLayout.allCases) { option in
                        Label(option.title, systemImage: option.iconName)
                            .tag(option)
                    }
                }
            } label: {
                headerIcon(layout.iconName)
            }
            .accessibilityLabel("Layout")
            .accessibilityValue(layout.title)

            Button {
                isFilterSheetPresented = true
            } label: {
                headerIcon("line.3.horizontal.decrease", isActive: hasActiveFilters)
            }
            .accessibilityLabel("Filters")
        }
        .padding(.horizontal, WKCCSpacing.md)
        .padding(.top, WKCCSpacing.xs)
        .padding(.bottom, WKCCSpacing.xs)
    }

    private func headerIcon(_ systemName: String, isActive: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(isActive ? WKCCColors.textOnPrimary : WKCCColors.primary)
            .frame(width: 44, height: 44)
            .background(isActive ? WKCCColors.primary : WKCCColors.cardBackground, in: Circle())
            .wkccCardShadow()
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WKCCSpacing.xs) {
                ForEach(DealCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        withAnimation(.snappy) {
                            viewModel.toggleCategory(category)
                        }
                    }
                }
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.vertical, WKCCSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(WKCCColors.pageBackground)
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
        .scrollDismissesKeyboard(.immediately)
        .wkccPageBackground()
    }
}

#Preview {
    NavigationStack {
        BusinessesListView()
    }
}
