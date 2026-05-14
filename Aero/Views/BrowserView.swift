






import SwiftUI

struct BrowserView: View {
    @State var viewModel: BrowserViewModel

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                if viewModel.showFindInPage {
                    FindInPageBar(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }


                ZStack {
                    if let tab = viewModel.activeTab {
                        if tab.url == nil {
                            NewTabPage(viewModel: viewModel)
                                .transition(.opacity)
                        } else {
                            WebViewRepresentable(
                                tab: tab,
                                onNavigationEvent: { event in
                                    viewModel.handleNavigationEvent(event)
                                }
                            )
                            .id(tab.id)
                            .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)


                if let tab = viewModel.activeTab {
                    ProgressBar(
                        progress: tab.estimatedProgress,
                        isLoading: tab.isLoading
                    )
                }


                BottomBrowserChromeView(viewModel: viewModel)
            }


            if viewModel.isShowingTabGrid {
                TabGridView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(100)
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(AeroAnimation.snappy, value: viewModel.showFindInPage)
        .onChange(of: viewModel.isAddressBarFocused) { _, isFocused in
            if isFocused {
                viewModel.expandChromeForInteraction()
            }
        }
        .onChange(of: viewModel.showFindInPage) { _, isShowing in
            if isShowing {
                viewModel.expandChromeForInteraction()
            }
        }
        .onChange(of: viewModel.showMenu) { _, isShowing in
            if isShowing {
                viewModel.expandChromeForInteraction()
            }
        }
        .onChange(of: viewModel.activeTab?.id) { _, _ in
            viewModel.expandChromeForInteraction()
        }
        .onChange(of: viewModel.activeTab?.url) { _, newURL in
            if newURL == nil {
                viewModel.expandChromeForInteraction()
            }
        }

        .sheet(isPresented: $viewModel.showMenu) {
            MenuSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showHistory) {
            HistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBookmarks) {
            BookmarksView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showDownloads) {
            DownloadsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showReaderMode) {
            ReaderModeView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAddBookmark) {
            AddBookmarkSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showTrackerReceipt) {
            TrackerReceiptView(viewModel: viewModel)
        }
    }
}
