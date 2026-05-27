






import SwiftUI

struct ToolbarView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton(
                "chevron.left",
                accessibilityLabel: "Back",
                accessibilityIdentifier: "browser.toolbar.back",
                enabled: viewModel.activeTab?.canGoBack ?? false
            ) {
                viewModel.goBack()
            }

            toolbarButton(
                "chevron.right",
                accessibilityLabel: "Forward",
                accessibilityIdentifier: "browser.toolbar.forward",
                enabled: viewModel.activeTab?.canGoForward ?? false
            ) {
                viewModel.goForward()
            }

            toolbarButton(
                "square.and.arrow.up",
                accessibilityLabel: "Share",
                accessibilityIdentifier: "browser.toolbar.share",
                enabled: viewModel.activeTab?.displayURL != nil
            ) {
                shareCurrentPage()
            }


            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.showTabGrid()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color(UIColor.label), lineWidth: 1.5)
                        .frame(width: 20, height: 16)
                    Text("\(viewModel.tabManager.tabCount)")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .tint(Color(UIColor.label))
            .accessibilityLabel("Tabs")
            .accessibilityValue(Text("\(viewModel.tabManager.tabCount)"))
            .accessibilityIdentifier("browser.toolbar.tabs")

            toolbarButton(
                "line.3.horizontal",
                accessibilityLabel: "Menu",
                accessibilityIdentifier: "browser.toolbar.menu",
                enabled: true
            ) {
                viewModel.showMenu = true
            }
        }
        .accessibilityIdentifier("browser.toolbar")
    }

    @ViewBuilder
    private func toolbarButton(
        _ icon: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .tint(Color(UIColor.label))
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func shareCurrentPage() {
        guard let url = viewModel.shareURL() else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}
