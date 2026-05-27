






import SwiftUI

struct TabGridView: View {
    @Bindable var viewModel: BrowserViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.hideTabGrid()
                }

            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.tabManager.tabs) { tab in
                            TabCardView(
                                tab: tab,
                                isActive: tab.id == viewModel.activeTab?.id,
                                onSelect: { viewModel.selectTab(tab) },
                                onClose: { viewModel.closeTab(tab) }
                            )
                            .transition(.chromeBlurReplace)
                        }
                    }
                    .padding(.horizontal, AeroSpacing.md)
                    .padding(.top, AeroSpacing.md)
                    .padding(.bottom, 48)
                }
                .accessibilityIdentifier("browser.tabGrid.scrollView")
                .navigationTitle("\(viewModel.tabManager.tabCount) Tabs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            viewModel.hideTabGrid()
                        }
                        .accessibilityIdentifier("browser.tabGrid.done")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            viewModel.newTab()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New Tab")
                        .accessibilityIdentifier("browser.tabGrid.newTab")
                    }
                }
                .background(Color(UIColor.systemBackground).opacity(0.86))
            }
            .accessibilityIdentifier("browser.tabGrid.navigation")
            .clipShape(RoundedRectangle(cornerRadius: AeroRadius.lg))
            .padding(.horizontal, AeroSpacing.sm)
            .padding(.top, AeroSpacing.xl)
            .padding(.bottom, AeroSpacing.sm)
            .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        }
        .accessibilityIdentifier("browser.tabGrid")
    }
}
