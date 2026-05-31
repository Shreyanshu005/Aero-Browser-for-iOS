import SwiftUI

struct BrowserSurfaceView: View {
    @Bindable var viewModel: BrowserViewModel
    @StateObject private var keyboard = KeyboardObserver()
    @State private var edgeSwipeIndicator: EdgeSwipeIndicator? = nil

    private enum EdgeSwipeIndicator {
        case back
        case forward
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if viewModel.showFindInPage {
                    FindInPageBar(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ZStack(alignment: .bottom) {
                    activePage(safeAreaInsets: proxy.safeAreaInsets, width: proxy.size.width)
                        .simultaneousGesture(backForwardEdgeSwipeGesture(viewWidth: proxy.size.width))

                    safeAreaGlassFill
                        .frame(height: proxy.safeAreaInsets.top)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(.container, edges: [.top])
                        .allowsHitTesting(false)

                    if let indicator = edgeSwipeIndicator {
                        edgeSwipeIndicatorView(indicator)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }

                    if let toast = viewModel.downloadManager.activeToast {
                        VStack {
                            Spacer()
                            DownloadToastView(filename: toast.filename) {
                                viewModel.showDownloads = true
                            }
                            .padding(.bottom, 10)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.2), value: toast)
                    }

                    if viewModel.isAddressBarFocused && keyboard.isVisible {
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
                safeAreaGlassFill
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

    @ViewBuilder
    private var safeAreaGlassFill: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.interactive(false), in: Rectangle())
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
#else
        Rectangle().fill(.ultraThinMaterial)
#endif
    }

    private func backForwardEdgeSwipeGesture(viewWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onChanged { v in
                guard viewModel.isAddressBarFocused == false,
                      viewModel.showFindInPage == false,
                      viewModel.isShowingTabGrid == false,
                      viewModel.isTabSwipeActive == false else { return }

                let edgeWidth: CGFloat = 22
                guard v.startLocation.x <= edgeWidth || v.startLocation.x >= (viewWidth - edgeWidth) else { return }

                let dx = v.translation.width
                let dy = v.translation.height
                guard abs(dx) > 12, abs(dx) > abs(dy) * 2.0 else { return }

                withAnimation(.easeOut(duration: 0.12)) {
                    edgeSwipeIndicator = dx > 0 ? .back : .forward
                }
            }
            .onEnded { v in
                defer {
                    withAnimation(.easeOut(duration: 0.12)) { edgeSwipeIndicator = nil }
                }

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
    private func edgeSwipeIndicatorView(_ indicator: EdgeSwipeIndicator) -> some View {
        HStack {
            if indicator == .back {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(14)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(.leading, 18)
                Spacer()
            } else {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(14)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(.trailing, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func activePage(safeAreaInsets: EdgeInsets, width: CGFloat) -> some View {
        if let tab = viewModel.activeTab {
            if let navigationError = tab.navigationError {
                ErrorPageView(
                    error: navigationError,
                    retryAction: viewModel.retryFailedNavigation,
                    newTabAction: { viewModel.newTab() }
                )
                .transition(.opacity)
            } else if tab.url == nil {
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
                            contentBlocker: viewModel.contentBlocker,
                            isContentBlockerEnabled: viewModel.contentBlockerEnabled,
                            chromeMode: viewModel.chromeMode,
                            isAddressBarFocused: viewModel.isAddressBarFocused,
                            safeAreaInsets: safeAreaInsets,
                            onNavigationEvent: viewModel.handleNavigationEvent,
                            downloadManager: viewModel.downloadManager
                        )
                        .id("\(targetTab.id.uuidString)-\(viewModel.webViewConfigurationRevision)")
                        .offset(x: incomingStartX + dx)

                        WebViewRepresentable(
                            tab: tab,
                            contentBlocker: viewModel.contentBlocker,
                            isContentBlockerEnabled: viewModel.contentBlockerEnabled,
                            chromeMode: viewModel.chromeMode,
                            isAddressBarFocused: viewModel.isAddressBarFocused,
                            safeAreaInsets: safeAreaInsets,
                            onNavigationEvent: viewModel.handleNavigationEvent,
                            downloadManager: viewModel.downloadManager
                        )
                        .id("\(tab.id.uuidString)-\(viewModel.webViewConfigurationRevision)")
                        .offset(x: dx)
                    } else {
                        WebViewRepresentable(
                            tab: tab,
                            contentBlocker: viewModel.contentBlocker,
                            isContentBlockerEnabled: viewModel.contentBlockerEnabled,
                            chromeMode: viewModel.chromeMode,
                            isAddressBarFocused: viewModel.isAddressBarFocused,
                            safeAreaInsets: safeAreaInsets,
                            onNavigationEvent: viewModel.handleNavigationEvent,
                            downloadManager: viewModel.downloadManager
                        )
                        .id("\(tab.id.uuidString)-\(viewModel.webViewConfigurationRevision)")
                        .transition(.opacity)
                    }
                }
            }
        }
    }
}
