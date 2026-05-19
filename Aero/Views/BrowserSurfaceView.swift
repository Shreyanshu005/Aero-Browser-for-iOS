import SwiftUI

struct BrowserSurfaceView: View {
    @Bindable var viewModel: BrowserViewModel
    @StateObject private var keyboard = KeyboardObserver()

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
                        .simultaneousGesture(backForwardEdgeSwipeGesture(viewWidth: proxy.size.width))

                    if viewModel.isAddressBarFocused {
                        SearchSuggestionsOverlayView(viewModel: viewModel)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if shouldShowBottomChrome {
                    bottomChromeInset
                        .frame(maxWidth: .infinity)
                        .ignoresSafeArea(.container, edges: [.bottom])
                }
            }
            .ignoresSafeArea(.container, edges: [.bottom])
        }
        .background {
            if viewModel.isAddressBarFocused {
                Color(UIColor.systemGray6)
                    .ignoresSafeArea(.keyboard)
            }
        }
        .animation(AeroAnimation.smooth, value: viewModel.isAddressBarFocused)
    }

    private var shouldShowBottomChrome: Bool {
        !(keyboard.isVisible && !viewModel.isAddressBarFocused)
    }

    @ViewBuilder
    private var bottomChromeInset: some View {
        if viewModel.chromeMode == .compact {
            ZStack {
                Color(UIColor.systemGray6)
                    .overlay(alignment: .top) {
                        Divider().opacity(0.5)
                    }

                CompactAddressPillView(viewModel: viewModel)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 10)
            }
            .frame(height: 62)
            .ignoresSafeArea(.container, edges: [.bottom])
        } else {
            BottomBrowserChromeView(viewModel: viewModel)
                .ignoresSafeArea(.container, edges: [.bottom])
        }
    }

    private func backForwardEdgeSwipeGesture(viewWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { v in
                guard viewModel.isAddressBarFocused == false,
                      viewModel.showFindInPage == false,
                      viewModel.isShowingTabGrid == false,
                      viewModel.isTabSwipeActive == false else { return }

                let edgeWidth: CGFloat = 22
                guard v.startLocation.x <= edgeWidth || v.startLocation.x >= (viewWidth - edgeWidth) else { return }

                let dx = v.translation.width
                let dy = v.translation.height
                guard abs(dx) > 80, abs(dx) > abs(dy) * 2.0 else { return }

                if dx > 0 {
                    guard viewModel.activeTab?.canGoBack == true else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.goBack()
                } else {
                    guard viewModel.activeTab?.canGoForward == true else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.goForward()
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
            }
        }
    }
}
