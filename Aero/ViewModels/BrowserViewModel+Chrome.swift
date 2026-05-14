extension BrowserViewModel {
    func shareURL() -> URL? {
        activeTab?.url
    }

    func syncAddressBarWithActiveTab() {
        if let url = activeTab?.url {
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
}
