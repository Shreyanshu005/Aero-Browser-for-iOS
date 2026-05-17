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
                    Color(uiColor: viewModel.activeTab?.pageBackgroundColor ?? UIColor.systemBackground)
                        .frame(height: proxy.safeAreaInsets.top)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .ignoresSafeArea(.container, edges: [.top])

                    activePage(safeAreaInsets: proxy.safeAreaInsets, width: proxy.size.width)

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
    private func activePage(safeAreaInsets: EdgeInsets, width: CGFloat) -> some View {
        if let tab = viewModel.activeTab {
            if tab.url == nil {
                NewTabPage(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                ZStack {
                    if viewModel.isTabSwipeActive,
                       let targetID = viewModel.tabSwipeTargetTabID,
                       let targetTab = viewModel.tabManager.tabs.first(where: { $0.id == targetID }) {
                        let dx = viewModel.tabSwipeTranslationX
                        let dir = viewModel.tabSwipeDirection
                        let incomingStartX = dir > 0 ? -width : width

                        WebViewRepresentable(
                            tab: targetTab,
                            chromeMode: viewModel.chromeMode,
                            isAddressBarFocused: viewModel.isAddressBarFocused,
                            safeAreaInsets: safeAreaInsets,
                            onNavigationEvent: viewModel.handleNavigationEvent
                        )
                        .id(targetTab.id)
                        .offset(x: incomingStartX + dx)

                        WebViewRepresentable(
                            tab: tab,
                            chromeMode: viewModel.chromeMode,
                            isAddressBarFocused: viewModel.isAddressBarFocused,
                            safeAreaInsets: safeAreaInsets,
                            onNavigationEvent: viewModel.handleNavigationEvent
                        )
                        .id(tab.id)
                        .offset(x: dx)
                    } else {
                        WebViewRepresentable(
                            tab: tab,
                            chromeMode: viewModel.chromeMode,
                            isAddressBarFocused: viewModel.isAddressBarFocused,
                            safeAreaInsets: safeAreaInsets,
                            onNavigationEvent: viewModel.handleNavigationEvent
                        )
                        .id(tab.id)
                        .transition(.opacity)
                    }
                }
                .ignoresSafeArea(.container, edges: [.bottom])
            }
        }
    }
}
