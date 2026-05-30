import SwiftUI

struct BrowserView: View {
    @State var viewModel: BrowserViewModel

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            BrowserSurfaceView(viewModel: viewModel)

            if viewModel.isShowingTabGrid {
                TabGridView(viewModel: viewModel)
                    .transition(.chromeBlurReplace)
                    .zIndex(100)
            }
        }
        .animation(AeroAnimation.snappy, value: viewModel.showFindInPage)
        .browserChromeObservers(viewModel: viewModel)
        .browserSheets(viewModel: viewModel)
    }
}
