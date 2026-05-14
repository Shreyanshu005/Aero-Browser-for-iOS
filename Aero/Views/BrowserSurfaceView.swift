import SwiftUI

struct BrowserSurfaceView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showFindInPage {
                FindInPageBar(viewModel: viewModel)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack(alignment: .bottom) {
                activePage

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

    @ViewBuilder
    private var activePage: some View {
        if let tab = viewModel.activeTab {
            if tab.url == nil {
                NewTabPage(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                WebViewRepresentable(
                    tab: tab,
                    onNavigationEvent: viewModel.handleNavigationEvent
                )
                .id(tab.id)
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
    }
}
