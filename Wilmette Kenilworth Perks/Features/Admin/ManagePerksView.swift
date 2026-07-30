import SwiftUI

enum ManagePerksSection: String, CaseIterable, Identifiable {
    case submissions = "Submissions"
    case published = "Published Perks"

    var id: String { rawValue }
}

struct ManagePerksView: View {
    @State private var selectedSection: ManagePerksSection = .submissions
    @State private var pendingSubmissionCount = 0
    @State private var refreshToken = UUID()

    private let submissionService: any PromotionSubmissionServicing = AppDependencies.shared.promotionSubmissionService

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedSection) {
                ForEach(ManagePerksSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.vertical, WKCCSpacing.sm)

            Group {
                switch selectedSection {
                case .submissions:
                    AdminSubmissionsListView(isEmbedded: true)
                case .published:
                    AdminPerksListView(isEmbedded: true, refreshToken: refreshToken)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .wkccPageBackground()
        .navigationTitle("Manage Perks")
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AdminPerkEditorView(mode: .create)
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(WKCCColors.accent)
                }
                .accessibilityLabel("Add perk")
            }
        }
        .task {
            pendingSubmissionCount = (try? await submissionService.pendingCount()) ?? 0
        }
        .onChange(of: selectedSection) { _, newValue in
            if newValue == .published {
                refreshToken = UUID()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ManagePerksView()
    }
}
