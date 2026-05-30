import SwiftUI

@main
struct AeroApp: App {
    @State private var viewModel = BrowserViewModel()

    var body: some Scene {
        WindowGroup {
            BrowserView(viewModel: viewModel)
                .tint(Color(UIColor.label))
                .modelContainer(StorageProvider.shared.container)
        }
    }
}
