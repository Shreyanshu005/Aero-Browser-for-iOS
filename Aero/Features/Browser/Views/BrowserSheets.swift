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
            .sheet(item: $viewModel.pendingDownload) { pendingDownload in
                DownloadConfirmationSheet(
                    pendingDownload: pendingDownload,
                    viewModel: viewModel
                )
                .browserSheetPresentation()
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
}

extension View {
    func browserSheets(viewModel: BrowserViewModel) -> some View {
        modifier(BrowserSheets(viewModel: viewModel))
    }
}
