import SwiftUI

struct BrowserChromeObservers: ViewModifier {
    @Bindable var viewModel: BrowserViewModel

    func body(content: Content) -> some View {
        content
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
    }
}

extension View {
    func browserChromeObservers(viewModel: BrowserViewModel) -> some View {
        modifier(BrowserChromeObservers(viewModel: viewModel))
    }
}
