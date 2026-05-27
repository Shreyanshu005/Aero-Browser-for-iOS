






import SwiftUI

struct MenuSheet: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {

                if viewModel.activeTab?.url != nil {
                    Section {
                        menuButton("magnifyingglass", "Find in Page") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.showFindInPage = true
                            }
                        }
                        menuButton("doc.plaintext", "Reader Mode") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.showReaderMode = true
                            }
                        }
                        menuButton("bookmark", "Add Bookmark") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.showAddBookmark = true
                            }
                        }
                        menuButton("doc.on.doc", "Copy Link") {
                            if let url = viewModel.activeTab?.url {
                                UIPasteboard.general.string = url.absoluteString
                            }
                            dismiss()
                        }
                        menuButton("desktopcomputer", "Desktop Site") {
                            viewModel.activeTab?.webView?.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
                            viewModel.reload()
                            dismiss()
                        }
                    }
                }


                Section {
                    menuButton("eye.slash", "New Private Tab") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            viewModel.newPrivateTab()
                        }
                    }
                    menuButton("clock", "History") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showHistory = true
                        }
                    }
                    menuButton("bookmark.fill", "Bookmarks") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showBookmarks = true
                        }
                    }
                    menuButton("arrow.down.circle", "Downloads") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showDownloads = true
                        }
                    }
                }


                Section {
                    menuButton("shield.lefthalf.filled", "Privacy") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showTrackerReceipt = true
                        }
                    }
                    menuButton("gearshape", "Settings") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showSettings = true
                        }
                    }
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func menuButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .foregroundStyle(Color(UIColor.label))
        }
    }
}
