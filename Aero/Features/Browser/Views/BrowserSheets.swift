import SwiftUI

struct BrowserSheets: ViewModifier {
    @Bindable var viewModel: BrowserViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showMenu) {
                MenuSheet(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showHistory) {
                HistoryView(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showBookmarks) {
                BookmarksView(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showDownloads) {
                DownloadsView(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showReaderMode) {
                ReaderModeView(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showAddBookmark) {
                AddBookmarkSheet(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showTrackerReceipt) {
                TrackerReceiptView(viewModel: viewModel)
                    .browserSheetPresentation()
            }
            .sheet(isPresented: $viewModel.showAgentPanel) {
                AgentChatPanelView(
                    viewModel: viewModel,
                    engine: viewModel.agentRunEngine,
                    pageTitle: activePageTitle,
                    pageSubtitle: activePageSubtitle
                )
                .browserSheetPresentation()
            }
            .sheet(item: $viewModel.pendingDownload) { pendingDownload in
                DownloadConfirmationSheet(
                    pendingDownload: pendingDownload,
                    viewModel: viewModel
                )
                .browserSheetPresentation()
            }
            .sheet(
                item: $viewModel.pendingLinkActionRequest,
                onDismiss: {
                    viewModel.linkActionsDidDismiss()
                }
            ) { request in
                LinkActionsSheet(
                    request: request,
                    viewModel: viewModel
                )
            }
            .sheet(
                item: $viewModel.pendingJavaScriptDialog,
                onDismiss: {
                    viewModel.javaScriptDialogDidDismiss()
                }
            ) { request in
                JavaScriptDialogSheet(
                    request: request,
                    viewModel: viewModel
                )
                .browserSheetPresentation()
            }
    }

    private var activePageTitle: String {
        viewModel.activeTab?.displayTitle ?? "New Tab"
    }

    private var activePageSubtitle: String {
        viewModel.activeTab?.displayURL?.displayHost ?? "Ready for browsing tasks"
    }
}

extension View {
    func browserSheets(viewModel: BrowserViewModel) -> some View {
        modifier(BrowserSheets(viewModel: viewModel))
    }
}
