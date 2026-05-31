


import SwiftUI
import UIKit

struct MenuSheet: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    private static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    menuButton("sparkles", "Agent") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showAgentPanel = true
                        }
                    }
                    .accessibilityIdentifier("browser.menu.agent")
                }

                Section {
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
                    if viewModel.activeTab?.url != nil {
                        menuButton("bookmark", "Add Bookmark") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.showAddBookmark = true
                            }
                        }
                    }
                }

                Section {
                    if viewModel.activeTab?.url != nil {
                        menuButton(desktopToggleIcon, desktopToggleTitle) {
                            if isDesktopSiteEnabled {
                                viewModel.activeTab?.webView?.customUserAgent = nil
                            } else {
                                viewModel.activeTab?.webView?.customUserAgent = Self.desktopUserAgent
                            }
                            viewModel.reload()
                            dismiss()
                        }
                    }
                    menuButton("gearshape", "Settings") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showSettings = true
                        }
                    }
                    .accessibilityIdentifier("browser.menu.settings")
                }
                
                Section {
                    NavigationLink {
                        MoreOptionsMenu(viewModel: viewModel)
                    } label: {
                        Label {
                            Text("More Options")
                                .font(.body.weight(.medium))
                                .foregroundStyle(AeroColor.textPrimary)
                        } icon: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 17, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(AeroColor.textPrimary)
                                .frame(width: 30, height: 30)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.sm, style: .continuous))
                        }
                        .labelStyle(.titleAndIcon)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(menuRowBackground)
                }
            }
            .accessibilityIdentifier("browser.menu.list")
            .listStyle(.insetGrouped)
            .browserSheetListBackground()
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("browser.menu.done")
                }
            }
        }
        .accessibilityIdentifier("browser.menu.sheet")
        .presentationDetents([.height(520), .large])
        .presentationDragIndicator(.visible)
    }

    private var isDesktopSiteEnabled: Bool {
        viewModel.activeTab?.webView?.customUserAgent == Self.desktopUserAgent
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
            Label {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AeroColor.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AeroColor.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.sm, style: .continuous))
            }
            .labelStyle(.titleAndIcon)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowBackground(menuRowBackground)
    }

    private var menuRowBackground: some View {
        Color.clear
    }
}

struct MoreOptionsMenu: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if viewModel.activeTab?.url != nil {
                Section("Page Options") {
                    menuButton("magnifyingglass", "Find in Page") {
                        dismissMenu()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showFindInPage = true
                        }
                    }
                    menuButton("doc.plaintext", "Reader Mode") {
                        dismissMenu()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showReaderMode = true
                        }
                    }
                    menuButton("doc.on.doc", "Copy Link") {
                        if let url = viewModel.activeTab?.url {
                            UIPasteboard.general.string = url.absoluteString
                        }
                        dismissMenu()
                    }
                    menuButton("square.and.arrow.down", "Save for Offline") {
                        if let url = viewModel.activeTab?.url, let title = viewModel.activeTab?.title {
                            viewModel.offlineService.addItem(title: title, url: url, excerpt: "Saved for offline reading")
                        }
                        dismissMenu()
                    }
                    menuButton("safari", "Open in Safari") {
                        if let url = viewModel.activeTab?.url {
                            UIApplication.shared.open(url)
                        }
                        dismissMenu()
                    }
                }
            }

            Section("Browsing") {
                if viewModel.canReopenLastClosedTab {
                    menuButton("arrow.uturn.backward", "Reopen Closed Tab") {
                        viewModel.reopenLastClosedTab()
                        dismissMenu()
                    }
                }
                menuButton("eye.slash", "New Private Tab") {
                    dismissMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.newPrivateTab()
                    }
                }
                menuButton("arrow.down.circle", "Downloads") {
                    dismissMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.showDownloads = true
                    }
                }
            }

            Section("Advanced") {
                menuButton("shield.lefthalf.filled", "Privacy Report") {
                    dismissMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.showTrackerReceipt = true
                    }
                }
                if viewModel.activeTab?.url != nil {
                    menuButton("speedometer", "Profile Page") {
                        if let webView = viewModel.activeTab?.webView {
                            Task { await viewModel.pageProfiler.profile(webView: webView) }
                        }
                        dismissMenu()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .browserSheetListBackground()
        .navigationTitle("More Options")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dismissMenu() {
        viewModel.showMenu = false
    }

    @ViewBuilder
    private func menuButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AeroColor.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AeroColor.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AeroRadius.sm, style: .continuous))
            }
            .labelStyle(.titleAndIcon)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowBackground(Color.clear)
    }
}
