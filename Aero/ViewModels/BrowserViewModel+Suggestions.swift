import Foundation

extension BrowserViewModel {
    func updateSuggestions(for query: String) {
        guard !query.isEmpty, isAddressBarFocused else {
            suggestions = []
            return
        }

        suggestions = suggestionProvider.suggestions(
            for: query,
            tabs: tabManager.tabs(in: activeBrowsingMode),
            favorites: favoritesStore.favorites,
            history: activeTab?.isPrivate == true ? [] : historyStore.items,
            activeTabID: activeTab?.id
        )
    }

    func clearSuggestions() {
        suggestions = []
    }

    func selectSuggestion(_ suggestion: BrowserSuggestion) {
        if let tabID = suggestion.tabID {
            tabManager.switchToTab(id: tabID)
        } else if let url = suggestion.url {
            addressBarText = url.absoluteString
            tabManager.loadInActiveTab(url: url)
        }

        isAddressBarFocused = false
        clearSuggestions()
        chromeController.expand()
    }
}
