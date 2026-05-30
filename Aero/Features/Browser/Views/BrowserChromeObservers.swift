import SwiftUI

struct BrowserChromeObservers: ViewModifier {
    @Bindable var viewModel: BrowserViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.isAddressBarFocused) { _, isFocused in
                if isFocused {
                    viewModel.chromeController.expand()
                }
            }
            .onChange(of: viewModel.showFindInPage) { _, isShowing in
                if isShowing {
                    viewModel.chromeController.expand()
                }
            }
            .onChange(of: viewModel.showMenu) { _, isShowing in
                if isShowing {
                    viewModel.chromeController.expand()
                }
            }
            .onChange(of: viewModel.activeTab?.id) { _, _ in
                viewModel.chromeController.expand()
                viewModel.refreshContentBlocking()
            }
            .onChange(of: viewModel.contentBlockerEnabled) { _, _ in
                viewModel.refreshContentBlocking()
            }
            .onChange(of: viewModel.activeTab?.url) { _, newURL in
                if newURL == nil {
                    viewModel.chromeController.expand()
                }
            }
    }
}

extension View {
    func browserChromeObservers(viewModel: BrowserViewModel) -> some View {
        modifier(BrowserChromeObservers(viewModel: viewModel))
    }
}
