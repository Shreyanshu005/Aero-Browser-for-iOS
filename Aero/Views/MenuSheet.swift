


import SwiftUI
import UIKit

struct MenuSheet: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss



    var body: some View {
        NavigationStack {
            List {

                if viewModel.activeTab?.url != nil {
                    Section {
                        menuButton("magnifyingglass", "Find in Page") {
                            viewModel.showMenu = false
                            viewModel.showFindInPage = true
                        }
                        menuButton("safari", "Open in Safari") {
                            viewModel.showMenu = false
                            if let url = viewModel.activeTab?.url {
                                UIApplication.shared.open(url)
                            }
                        }
                        menuButton("doc.plaintext", "Reader Mode") {
                            viewModel.showMenu = false
                            viewModel.showReaderMode = true
                        }
                        menuButton("bookmark", "Add Bookmark") {
                            viewModel.showMenu = false
                            viewModel.showAddBookmark = true
                        }
                        menuButton("doc.on.doc", "Copy Link") {
                            viewModel.showMenu = false
                            if let url = viewModel.activeTab?.url {
                                UIPasteboard.general.string = url.absoluteString
                            }
                        }
                        menuButton(desktopToggleIcon, desktopToggleTitle) {
                            viewModel.showMenu = false
                            if let webView = viewModel.activeTab?.webView {
                                if isDesktopSiteEnabled {
                                    PrivacyService.shared.resetUserAgent(on: webView)
                                } else {
                                    PrivacyService.shared.setDesktopUserAgent(on: webView)
                                }
                                viewModel.reload()
                            }
                        }
                    }
                }


                Section {
                    menuButton("clock", "History") {
                        viewModel.showHistory = true
                    }
                    menuButton("bookmark.fill", "Bookmarks") {
                        viewModel.showBookmarks = true
                    }
                    menuButton("arrow.down.circle", "Downloads") {
                        viewModel.showDownloads = true
                    }
                }


                Section {
                    menuButton("shield.lefthalf.filled", "Privacy") {
                        viewModel.showTrackerReceipt = true
                    }
                    menuButton("gearshape", "Settings") {
                        viewModel.showSettings = true
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

    private var isDesktopSiteEnabled: Bool {
        viewModel.activeTab?.webView?.customUserAgent == PrivacyService.shared.desktopUserAgent
    }

    private var desktopToggleTitle: String {
        isDesktopSiteEnabled ? "Mobile Site" : "Desktop Site"
    }

    private var desktopToggleIcon: String {
        isDesktopSiteEnabled ? "iphone" : "desktopcomputer"
    }

    @ViewBuilder
    private func menuButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .foregroundStyle(Color(UIColor.label))
        }
    }
}
