






import SwiftUI

struct ToolbarView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton("chevron.left", enabled: viewModel.activeTab?.canGoBack ?? false) {
                viewModel.goBack()
            }

            toolbarButton("chevron.right", enabled: viewModel.activeTab?.canGoForward ?? false) {
                viewModel.goForward()
            }

            toolbarButton("square.and.arrow.up", enabled: viewModel.activeTab?.displayURL != nil) {
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

            toolbarButton("line.3.horizontal", enabled: true) {
                viewModel.showMenu = true
            }
        }
    }

    @ViewBuilder
    private func toolbarButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
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
