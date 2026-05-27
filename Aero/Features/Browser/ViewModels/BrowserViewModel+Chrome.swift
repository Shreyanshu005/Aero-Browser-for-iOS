import Foundation

extension BrowserViewModel {
    func shareURL() -> URL? {
        activeTab?.displayURL
    }

    func syncAddressBarWithActiveTab() {
        if let url = activeTab?.displayURL {
            addressBarText = url.absoluteString
        } else {
            addressBarText = ""
        }
    }

    func expandChromeForInteraction(focusAddressBar: Bool = false) {
        chromeController.expand()
        if focusAddressBar {
            syncAddressBarWithActiveTab()
            isAddressBarFocused = true
        }
    }

    func dismissSearchPresentation() {
        syncAddressBarWithActiveTab()
        isAddressBarFocused = false
        clearSearchSuggestions()
        clearSuggestions()
        chromeController.expand()
    }
}
