






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
                    VStack(spacing: AeroSpacing.md) {
                        Picker("Browsing Mode", selection: browsingModeSelection) {
                            ForEach(BrowsingMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.systemImage)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(viewModel.tabManager.tabs(in: viewModel.activeBrowsingMode)) { tab in
                                TabCardView(
                                    tab: tab,
                                    isActive: tab.id == viewModel.activeTab?.id,
                                    onSelect: { viewModel.selectTab(tab) },
                                    onClose: { viewModel.closeTab(tab) }
                                )
                                .transition(.chromeBlurReplace)
                            }
                        }
                    }
                    .padding(.horizontal, AeroSpacing.md)
                    .padding(.top, AeroSpacing.md)
                    .padding(.bottom, 48)
                }
                .navigationTitle(viewModel.activeBrowsingMode.tabGridTitle(count: viewModel.tabManager.tabCount))
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
                .background(Color(UIColor.systemBackground).opacity(0.86))
            }
            .clipShape(RoundedRectangle(cornerRadius: AeroRadius.lg))
            .padding(.horizontal, AeroSpacing.sm)
            .padding(.top, AeroSpacing.xl)
            .padding(.bottom, AeroSpacing.sm)
            .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
        }
    }

    private var browsingModeSelection: Binding<BrowsingMode> {
        Binding {
            viewModel.activeBrowsingMode
        } set: { mode in
            viewModel.switchBrowsingMode(mode)
        }
    }
}
