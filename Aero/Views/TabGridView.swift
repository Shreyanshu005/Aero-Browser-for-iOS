






import SwiftUI

struct TabGridView: View {
    @Bindable var viewModel: BrowserViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.tabManager.tabs) { tab in
                        TabCardView(
                            tab: tab,
                            isActive: tab.id == viewModel.activeTab?.id,
                            onSelect: { viewModel.selectTab(tab) },
                            onClose: { viewModel.closeTab(tab) }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("\(viewModel.tabManager.tabCount) Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.hideTabGrid()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.newTab()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
        }
    }
}
