import SwiftUI

struct BrowserSurfaceView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if viewModel.showFindInPage {
                    FindInPageBar(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ZStack(alignment: .bottom) {
                    activePage(safeAreaInsets: proxy.safeAreaInsets)

                    VStack(spacing: 0) {
                        if let tab = viewModel.activeTab {
                            ProgressBar(
                                progress: tab.estimatedProgress,
                                isLoading: tab.isLoading
                            )
                        }

                        BottomBrowserChromeView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func activePage(safeAreaInsets: EdgeInsets) -> some View {
        if let tab = viewModel.activeTab {
            if tab.url == nil {
                NewTabPage(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                WebViewRepresentable(
                    tab: tab,
                    contentBlocker: viewModel.contentBlocker,
                    isContentBlockerEnabled: viewModel.contentBlockerEnabled,
                    chromeMode: viewModel.chromeMode,
                    isAddressBarFocused: viewModel.isAddressBarFocused,
                    safeAreaInsets: safeAreaInsets,
                    onNavigationEvent: viewModel.handleNavigationEvent
                )
                .id("\(tab.id.uuidString)-\(viewModel.webViewConfigurationRevision)")
                .transition(.opacity)
                .ignoresSafeArea(.container, edges: [.top, .bottom])
            }
        }
    }
}
